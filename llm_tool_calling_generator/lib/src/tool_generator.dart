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
      final jsonType = _jsonType(param.type);
      if (jsonType == null) {
        throw InvalidGenerationSource(
          'Parameter "$name" has type ${param.type.getDisplayString()}, '
          'which is not supported yet. Use String, int, double, num or bool.',
          element: param,
        );
      }

      final paramDescription = _paramDescription(param);
      properties[name] = {'type': jsonType, 'description': ?paramDescription};

      // Required in the schema = no default value and can't be null.
      final isNullable =
          param.type.nullabilitySuffix == NullabilitySuffix.question;
      final isRequired = !param.hasDefaultValue && !isNullable;
      if (isRequired) required.add(name);

      var value = _readArg(name, param.type, nullable: !isRequired);
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

/// Maps a Dart type to its JSON Schema type, or null if unsupported.
String? _jsonType(DartType type) {
  if (type.isDartCoreString) return 'string';
  if (type.isDartCoreInt) return 'integer';
  if (type.isDartCoreDouble || type.isDartCoreNum) return 'number';
  if (type.isDartCoreBool) return 'boolean';
  return null;
}

/// Code that reads one argument from the AI's map and casts it.
String _readArg(String name, DartType type, {required bool nullable}) {
  final q = nullable ? '?' : '';
  final value = 'args[${_literal(name)}]';
  // JSON has no int/double difference: 5 can arrive as int and 5.0 as
  // double, so read as num and convert.
  if (type.isDartCoreDouble) return '($value as num$q)$q.toDouble()';
  if (type.isDartCoreInt) return '($value as num$q)$q.toInt()';
  final typeName = type.getDisplayString().replaceAll('?', '');
  return '$value as $typeName$q';
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
