import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
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
        'Tool name "$toolName" is invalid. To work with every LLM provider it '
        'must start with a letter or "_", then use only letters, digits, "_" '
        'or "-", up to 64 characters. Use @Tool(name: ...) to set a valid '
        'one.',
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

    // 3. Build the schema and the call arguments from the parameters.
    final params = _TypeMapper(
      element.library,
    ).parameters(element.formalParameters, map: 'args', path: '');

    // 4. Write the generated code.
    final schema = {
      'type': 'object',
      'properties': params.properties,
      'required': params.required,
      // Tells the LLM what call() enforces: no extra arguments.
      'additionalProperties': false,
    };
    final call = '$functionName(${params.arguments})';
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

/// The schema properties, required names and call arguments for a list of
/// parameters.
typedef _Parameters = ({
  Map<String, Object?> properties,
  List<String> required,
  String arguments,
});

/// Maps Dart types to JSON schemas, and JSON values back to Dart code.
///
/// Used for the tool's own parameters and, recursively, for the constructor
/// parameters of class-typed parameters.
class _TypeMapper {
  _TypeMapper(this.library);

  /// The library the generated code is a part of.
  final LibraryElement library;

  /// Classes being mapped right now, to catch classes that contain themselves.
  final _inProgress = <ClassElement>{};

  /// The schema and call arguments for [params], whose JSON values are read
  /// from the map expression [map]. [path] prefixes names in error messages.
  _Parameters parameters(
    List<FormalParameterElement> params, {
    required String map,
    required String path,
  }) {
    final properties = <String, Object?>{};
    final required = <String>[];
    final positional = <String>[];
    final named = <String>[];

    for (final param in params) {
      final name = param.displayName;
      final paramPath = path.isEmpty ? name : '$path.$name';
      if (!_validParameterName.hasMatch(name)) {
        throw InvalidGenerationSource(
          '${path.isEmpty ? 'Parameter' : 'Field'} "$paramPath" has a name '
          'some LLM providers reject (Gemini allows only letters, digits and '
          '"_", up to 64 characters). Rename it.',
          element: param,
        );
      }
      final description = _paramDescription(param) ?? _fieldDescription(param);
      properties[name] = {
        ...schemaFor(param.type, paramPath, param),
        'description': ?description,
      };

      // Required in the schema = no default value and can't be null.
      final isNullable =
          param.type.nullabilitySuffix == NullabilitySuffix.question;
      final isRequired = !param.hasDefaultValue && !isNullable;
      if (isRequired) required.add(name);

      final value = '$map[${_literal(name)}]';
      var code = isRequired
          ? convert(value, param.type)
          : _convertNullable(value, param.type);
      if (param.hasDefaultValue) {
        code = '$code ?? ${_defaultValue(param, paramPath)}';
      }
      if (param.isNamed) {
        named.add('$name: $code');
      } else {
        positional.add(code);
      }
    }
    return (
      properties: properties,
      required: required,
      arguments: [...positional, ...named].join(', '),
    );
  }

  /// The JSON Schema for [type], without a description.
  ///
  /// [path] and [at] point error messages at the right parameter or field.
  /// [shown] is the type to name in errors (the whole list, for list items).
  Map<String, Object?> schemaFor(
    DartType type,
    String path,
    Element at, {
    DartType? shown,
  }) {
    Never fail(String problem) => throw InvalidGenerationSource(
      '${path.contains('.') ? 'Field' : 'Parameter'} "$path" has type '
      '${(shown ?? type).getDisplayString()}, $problem',
      element: at,
    );

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
      if (itemType.nullabilitySuffix == NullabilitySuffix.question) {
        fail(
          'but list items can\'t be nullable. Remove the "?" from the '
          'item type.',
        );
      }
      return {
        'type': 'array',
        'items': schemaFor(itemType, path, at, shown: shown ?? type),
      };
    }
    if (_classOf(type) case final classElement?) {
      final constructor = classElement.unnamedConstructor;
      if (classElement.typeParameters.isNotEmpty) {
        fail('which is generic. Generic classes are not supported yet.');
      }
      if (constructor == null) {
        fail(
          'which has no unnamed constructor, e.g. '
          '${classElement.displayName}({...}). Add one so it can be built '
          'from the LLM\'s JSON.',
        );
      }
      if (classElement.isAbstract && !constructor.isFactory) {
        fail(
          'which is abstract. Use a concrete class, or give it an '
          'unnamed factory constructor.',
        );
      }
      if (!_inProgress.add(classElement)) {
        fail('which contains itself. Recursive classes are not supported.');
      }
      try {
        final fields = parameters(
          constructor.formalParameters,
          map: 'json',
          path: path,
        );
        final description = _cleanDocComment(classElement.documentationComment);
        return {
          'type': 'object',
          if (description != null && description.isNotEmpty)
            'description': description,
          'properties': fields.properties,
          'required': fields.required,
          'additionalProperties': false,
        };
      } finally {
        _inProgress.remove(classElement);
      }
    }
    fail(
      'which is not supported yet. Use String, int, double, num, bool, an '
      'enum, a class, or a List of these.',
    );
  }

  /// Code that converts [value], a non-null JSON value, to [type].
  ///
  /// Only called for types that [schemaFor] accepted.
  String convert(String value, DartType type) {
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
      return '($value as List).map((e) => ${convert('e', itemType)})'
          '.toList()';
    }
    if (_classOf(type) case final classElement?) {
      // Cast once and bind it: repeating `(e as Map)` per field would make
      // later casts "unnecessary" warnings in the user's project.
      final fields = parameters(
        classElement.unnamedConstructor!.formalParameters,
        map: 'json',
        path: '',
      );
      return '((Map json) => '
          '${_referenceTo(classElement, library)}(${fields.arguments}))'
          '($value as Map)';
    }
    throw StateError('Unsupported type: ${type.getDisplayString()}');
  }

  /// Like [convert], but [value] may be null.
  String _convertNullable(String value, DartType type) {
    // Short forms for simple types keep the generated code readable.
    if (type.isDartCoreDouble) return '($value as num?)?.toDouble()';
    if (type.isDartCoreInt) return '($value as num?)?.toInt()';
    if (type.isDartCoreString) return '$value as String?';
    if (type.isDartCoreBool) return '$value as bool?';
    if (type.isDartCoreNum) return '$value as num?';
    // Parenthesized so a following `?? default` applies to the whole thing.
    return '($value == null ? null : ${convert(value, type)})';
  }

  /// Code for [param]'s default value that works inside [library].
  String _defaultValue(FormalParameterElement param, String path) {
    // Written in the same library, the source code works as-is.
    if (param.library == library) return param.defaultValueCode!;

    // From another library, the source may use names that aren't visible
    // here (private constants, prefixed imports), so rebuild the value.
    final code = _constantCode(param.computeConstantValue());
    if (code != null) return code;
    throw InvalidGenerationSource(
      'Field "$path" has a default value that can\'t be copied into the '
      'generated code. Use a literal, an enum value or a const list of '
      'those, or make the field nullable or required.',
      element: param,
    );
  }

  /// Dart code for a constant, or null if it can't be written as a literal.
  String? _constantCode(DartObject? value) {
    if (value == null) return null;
    if (value.isNull) return 'null';
    if (value.toBoolValue() case final bool b) return '$b';
    if (value.toIntValue() case final int i) return '$i';
    if (value.toDoubleValue() case final double d) {
      return d.isFinite ? '$d' : null;
    }
    if (value.toStringValue() case final String s) return _literal(s);
    if (value.type case final type? when _enumOf(type) != null) {
      final name = value.variable?.displayName;
      return name == null
          ? null
          : '${_referenceTo(type.element!, library)}.$name';
    }
    if (value.toListValue() case final items?) {
      final codes = [for (final item in items) _constantCode(item)];
      if (codes.contains(null)) return null;
      return 'const [${codes.join(', ')}]';
    }
    return null;
  }
}

EnumElement? _enumOf(DartType type) => switch (type) {
  InterfaceType(element: final EnumElement element) => element,
  _ => null,
};

/// The class for a class type we can build from JSON, otherwise null.
///
/// SDK classes like DateTime are excluded: their constructors don't take
/// JSON-shaped values.
ClassElement? _classOf(DartType type) => switch (type) {
  InterfaceType(element: final ClassElement element)
      when !element.library.isInSdk =>
    element,
  _ => null,
};

/// The doc comment of the field behind a `this.name` parameter, if any.
String? _fieldDescription(FormalParameterElement param) {
  if (param is! FieldFormalParameterElement) return null;
  final description = _cleanDocComment(param.field?.documentationComment);
  return description == null || description.isEmpty ? null : description;
}

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

/// Reads the text from @Param('...') on a parameter, if present.
String? _paramDescription(Element param) {
  final annotation = _paramChecker.firstAnnotationOf(param);
  if (annotation == null) return null;
  return ConstantReader(annotation).read('description').stringValue;
}

/// Accepted by OpenAI, Anthropic and Gemini (the strictest: it requires a
/// letter or `_` first).
final _validToolName = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_-]{0,63}$');

/// Gemini only accepts letters, digits and `_` in parameter names.
final _validParameterName = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]{0,63}$');

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
