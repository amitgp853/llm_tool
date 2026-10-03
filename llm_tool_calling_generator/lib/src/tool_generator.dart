import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:llm_tool_calling/llm_tool_calling.dart';
import 'package:source_gen/source_gen.dart';

final _paramChecker = TypeChecker.typeNamed(
  Param,
  inPackage: 'llm_tool_calling',
);

final _toolChecker = TypeChecker.typeNamed(Tool, inPackage: 'llm_tool_calling');

class ToolGenerator extends GeneratorForAnnotation<Tool> {
  ToolGenerator() : super(inPackage: 'llm_tool_calling');

  /// GeneratorForAnnotation only looks at top-level declarations, so @Tool on
  /// a method would be silently ignored. Fail loudly instead.
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    final lib = library.element;
    final containers = <InstanceElement>[
      ...lib.classes,
      ...lib.mixins,
      ...lib.enums,
      ...lib.extensions,
      ...lib.extensionTypes,
    ];
    for (final container in containers) {
      for (final method in container.methods) {
        if (_toolChecker.hasAnnotationOf(method)) {
          throw InvalidGenerationSource(
            '@Tool can only be used on top-level functions, but '
            '"${container.displayName}.${method.displayName}" is a method. '
            'Move it to a top-level function.',
            element: method,
          );
        }
      }
    }
    return super.generate(library, buildStep);
  }

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // 1. @Tool only makes sense on top-level functions.
    if (element is! TopLevelFunctionElement) {
      throw InvalidGenerationSource(
        '@Tool can only be used on top-level functions.',
        element: element,
      );
    }
    if (element.typeParameters.isNotEmpty) {
      throw InvalidGenerationSource(
        '@Tool functions can\'t be generic. Remove the type parameters from '
        '"${element.displayName}".',
        element: element,
      );
    }

    // 2. Read the tool's name, description and settings.
    final functionName = element.displayName;
    final toolName = annotation.peek('name')?.stringValue ?? functionName;
    // OpenAI, Anthropic and Gemini all reject names outside this pattern.
    if (!_validToolName.hasMatch(toolName)) {
      throw InvalidGenerationSource(
        'Tool name "$toolName" is invalid. LLM providers only accept 1-64 '
        'letters, digits, "_" or "-". Use @Tool(name: ...) to set a valid one.',
        element: element,
      );
    }
    final description =
        annotation.peek('description')?.stringValue ??
        _cleanDocComment(element.documentationComment);
    if (description == null || description.isEmpty) {
      throw InvalidGenerationSource(
        'Tool "$functionName" needs a description. Add a /// doc comment '
        'or use @Tool(description: ...).',
        element: element,
      );
    }
    final requiresConfirmation = annotation
        .read('requiresConfirmation')
        .boolValue;

    // 3. Build the schema and the argument list, one parameter at a time.
    final properties = <String, Object?>{};
    final required = <String>[];
    final positionalArgs = <String>[];
    final namedArgs = <String>[];

    for (final param in element.formalParameters) {
      final name = param.displayName;
      final typeSchema = _typeSchema(param.type);
      if (typeSchema == null) {
        throw InvalidGenerationSource(
          'Parameter "$name" has type ${param.type.getDisplayString()}, '
          'which is not supported yet. Use String, int, double, num, bool, '
          'an enum, or a List of these.',
          element: param,
        );
      }

      final paramDescription = _paramDescription(param);
      properties[name] = {...typeSchema, 'description': ?paramDescription};

      // Required in the schema = no default value and can't be null.
      final isNullable =
          param.type.nullabilitySuffix == NullabilitySuffix.question;
      final isRequired = !param.hasDefaultValue && !isNullable;
      if (isRequired) required.add(name);

      var value = _readArg(
        name,
        param.type,
        nullable: !isRequired,
        library: element.library,
      );
      if (param.hasDefaultValue) {
        value = '$value ?? ${param.defaultValueCode}';
      }

      if (param.isNamed) {
        namedArgs.add('$name: $value');
      } else {
        positionalArgs.add(value);
      }
    }

    // 4. Write the generated code.
    final schema = {
      'type': 'object',
      'properties': properties,
      'required': required,
      // Tells the LLM what call() enforces: no extra arguments.
      'additionalProperties': false,
    };
    final call =
        '$functionName(${[...positionalArgs, ...namedArgs].join(', ')})';
    final execute = element.returnType is VoidType
        ? '(args) { $call; return null; }'
        : '(args) => $call';

    return '''
final ${functionName}Tool = ToolDefinition(
  name: ${_literal(toolName)},
  description: ${_literal(description)},
  parametersSchema: ${_literal(schema)},
  requiresConfirmation: $requiresConfirmation,
  execute: $execute,
);
''';
  }
}

/// The JSON Schema for a Dart type (without description), or null if the
/// type is unsupported.
Map<String, Object?>? _typeSchema(DartType type) {
  if (type.isDartCoreString) return {'type': 'string'};
  if (type.isDartCoreInt) return {'type': 'integer'};
  if (type.isDartCoreDouble || type.isDartCoreNum) return {'type': 'number'};
  if (type.isDartCoreBool) return {'type': 'boolean'};
  if (_enumOf(type) case final enumElement?) {
    // Enums travel as their value names, e.g. "celsius".
    return {
      'type': 'string',
      'enum': [for (final value in enumElement.constants) value.displayName],
    };
  }
  if (_listItemType(type) case final itemType?) {
    // Items can't be null: LLMs rarely need it, and it keeps schemas simple.
    if (itemType.nullabilitySuffix == NullabilitySuffix.question) return null;
    final itemSchema = _typeSchema(itemType);
    if (itemSchema == null) return null;
    return {'type': 'array', 'items': itemSchema};
  }
  return null;
}

EnumElement? _enumOf(DartType type) => switch (type) {
  InterfaceType(element: final EnumElement element) => element,
  _ => null,
};

/// `T` for a `List<T>`, otherwise null.
DartType? _listItemType(DartType type) =>
    type is InterfaceType && type.isDartCoreList
    ? type.typeArguments.single
    : null;

/// How code in [library] (and so in its generated part) refers to [element]:
/// `Unit`, or `u.Unit` when it is only imported with `as u`.
String _referenceTo(Element element, LibraryElement library) {
  final name = element.displayName;
  if (element.library == library) return name;

  String? prefixed;
  for (final import in library.firstFragment.libraryImports) {
    if (import.importedLibrary?.exportNamespace.get2(name) != element) continue;
    final prefix = import.prefix?.element.displayName;
    if (prefix == null) return name; // an unprefixed import wins
    prefixed ??= '$prefix.$name';
  }
  return prefixed ?? name;
}

/// Code that reads one argument from the AI's map and casts it.
String _readArg(
  String name,
  DartType type, {
  required bool nullable,
  required LibraryElement library,
}) {
  final value = 'args[${_literal(name)}]';
  if (!nullable) return _convert(value, type, library);

  // Short forms for simple types keep the generated code readable.
  if (type.isDartCoreDouble) return '($value as num?)?.toDouble()';
  if (type.isDartCoreInt) return '($value as num?)?.toInt()';
  if (type.isDartCoreString) return '$value as String?';
  if (type.isDartCoreBool) return '$value as bool?';
  if (type.isDartCoreNum) return '$value as num?';
  // Parenthesized so a following `?? default` applies to the whole thing.
  return '($value == null ? null : ${_convert(value, type, library)})';
}

/// Code that converts [value], a non-null JSON value, to [type].
///
/// Only called for types that [_typeSchema] accepted.
String _convert(String value, DartType type, LibraryElement library) {
  // JSON has no int/double difference: 5 can arrive as int and 5.0 as
  // double, so read as num and convert.
  if (type.isDartCoreDouble) return '($value as num).toDouble()';
  if (type.isDartCoreInt) return '($value as num).toInt()';
  if (type.isDartCoreString) return '$value as String';
  if (type.isDartCoreBool) return '$value as bool';
  if (type.isDartCoreNum) return '$value as num';
  if (_enumOf(type) case final enumElement?) {
    return '${_referenceTo(enumElement, library)}.values.byName('
        '$value as String)';
  }
  if (_listItemType(type) case final itemType?) {
    // `e` may shadow an outer `e` in nested lists, which Dart allows.
    return '($value as List).map((e) => ${_convert('e', itemType, library)})'
        '.toList()';
  }
  throw StateError('Unsupported type: ${type.getDisplayString()}');
}

/// Reads the text from @Param('...') on a parameter, if present.
String? _paramDescription(Element param) {
  final annotation = _paramChecker.firstAnnotationOf(param);
  if (annotation == null) return null;
  return ConstantReader(annotation).read('description').stringValue;
}

final _validToolName = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');

/// Turns "/// Gets the weather." (or a /** */ block) into "Gets the weather."
///
/// Lines of one paragraph are joined with spaces; blank lines become "\n\n"
/// so the LLM still sees the paragraph structure.
String? _cleanDocComment(String? doc) {
  if (doc == null) return null;
  final lines = doc
      .split('\n')
      .map(
        (line) => line
            .trim()
            .replaceFirst(RegExp(r'^(///|/\*\*|\*/|\*)\s?'), '')
            .replaceFirst(RegExp(r'\s*\*/$'), '')
            .trimRight(),
      );

  final paragraphs = <String>[];
  var current = <String>[];
  for (final line in lines) {
    if (line.isNotEmpty) {
      current.add(line);
    } else if (current.isNotEmpty) {
      paragraphs.add(current.join(' '));
      current = [];
    }
  }
  if (current.isNotEmpty) paragraphs.add(current.join(' '));
  return paragraphs.join('\n\n');
}

/// Safe Dart literal for strings and maps (escapes quotes and $).
String _literal(Object value) => jsonEncode(value).replaceAll(r'$', r'\$');
