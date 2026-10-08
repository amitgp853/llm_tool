import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:llm_tool/llm_tool.dart';
import 'package:source_gen/source_gen.dart';

final _paramChecker = TypeChecker.typeNamed(Param, inPackage: 'llm_tool');

final _toolChecker = TypeChecker.typeNamed(LlmTool, inPackage: 'llm_tool');

final _toolsetChecker = TypeChecker.typeNamed(
  LlmToolset,
  inPackage: 'llm_tool',
);

/// Generates a [ToolDefinition] for every `@LlmTool()` function and method.
class ToolGenerator extends GeneratorForAnnotation<LlmTool> {
  ToolGenerator() : super(inPackage: 'llm_tool');

  /// Generates every tool, a list of all tools in the file, then an
  /// `llmTools` extension for each @LlmToolset class.
  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    _checkNoToolMethods(library.element);
    final output = StringBuffer();

    final tools = await super.generate(library, buildStep);
    if (tools.isNotEmpty) {
      final names = [
        for (final annotated in library.annotatedWith(typeChecker))
          '${annotated.element.displayName}Tool',
      ];
      final listName = toolListName(buildStep.inputId.pathSegments.last);
      output.write('''
$tools

/// Every tool in this file, e.g. to send to an LLM or look up by name.
/// Typed by the tools' common return type, so calling one needs no cast.
final $listName = [${names.join(', ')}];
''');
    }

    for (final annotated in library.annotatedWith(_toolsetChecker)) {
      output.write('\n${_toolset(annotated.element)}');
    }
    return output.toString();
  }

  /// GeneratorForAnnotation only looks at top-level declarations, so @LlmTool
  /// on a method outside an @LlmToolset class would be silently ignored. Fail
  /// loudly instead.
  void _checkNoToolMethods(LibraryElement lib) {
    final containers = <InstanceElement>[
      ...lib.classes,
      ...lib.mixins,
      ...lib.enums,
      ...lib.extensions,
      ...lib.extensionTypes,
    ];
    for (final container in containers) {
      if (container is ClassElement &&
          _toolsetChecker.hasAnnotationOf(container)) {
        continue;
      }
      for (final method in container.methods) {
        if (_toolChecker.hasAnnotationOf(method)) {
          throw InvalidGenerationSource(
            '"${container.displayName}.${method.displayName}" is a method, '
            'and @LlmTool methods need their class marked as a toolset. '
            '${container is ClassElement ? 'Add @LlmToolset() to class "${container.displayName}"' : 'Move it to an @LlmToolset class'}, '
            'or make it a top-level function.',
            element: method,
          );
        }
      }
    }
  }

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // @LlmTool only makes sense on top-level functions and toolset methods.
    if (element is! TopLevelFunctionElement) {
      throw InvalidGenerationSource(
        '@LlmTool can only be used on top-level functions and on methods of '
        'an @LlmToolset class.',
        element: element,
      );
    }
    final definition = _toolDefinition(
      element,
      annotation,
      call: element.displayName,
    );
    return 'final ${element.displayName}Tool = $definition;\n';
  }

  /// The `llmTools` extension for an @LlmToolset class.
  String _toolset(Element element) {
    if (element is! ClassElement) {
      throw InvalidGenerationSource(
        '@LlmToolset can only be used on classes.',
        element: element,
      );
    }
    if (element.typeParameters.isNotEmpty) {
      throw InvalidGenerationSource(
        '@LlmToolset classes can\'t be generic. Remove the type parameters '
        'from "${element.displayName}".',
        element: element,
      );
    }
    final className = element.displayName;
    final library = element.library;
    final definitions = <String>[];
    final resultTypes = <DartType>[];
    for (final method in element.methods) {
      final annotation = _toolChecker.firstAnnotationOf(method);
      if (annotation == null) continue;
      definitions.add(
        _toolDefinition(
          method,
          ConstantReader(annotation),
          // Inside the extension, `this` is the instance. Only the closure's
          // `args` parameter can hide a method of the same name.
          call: method.isStatic
              ? '$className.${method.displayName}'
              : method.displayName == 'args'
              ? 'this.args'
              : method.displayName,
        ),
      );
      resultTypes.add(_resultType(method.returnType, library));
    }
    if (definitions.isEmpty) {
      throw InvalidGenerationSource(
        '@LlmToolset class "$className" has no @LlmTool methods. Mark at '
        'least one method with @LlmTool().',
        element: element,
      );
    }

    // A getter's return type isn't inferred, so write the type a list
    // literal would infer: the tools' common return type.
    final common = resultTypes.reduce(library.typeSystem.leastUpperBound);
    final listType =
        'List<${_toolDefinitionName(library)}<${_typeCode(common, library)}>>';
    return '''
/// The @LlmTool methods of [$className] as tools.
extension ${className}LlmTools on $className {
  /// Every tool of this [$className], bound to this instance, e.g. to send
  /// to an LLM or look up by name.
  $listType get llmTools => [${definitions.map((d) => '\n    $d,').join()}
  ];
}
''';
  }

  /// A `ToolDefinition(...)` expression for a tool function or method,
  /// whose code calls it as [call].
  String _toolDefinition(
    ExecutableElement element,
    ConstantReader annotation, {
    required String call,
  }) {
    if (element.typeParameters.isNotEmpty) {
      throw InvalidGenerationSource(
        '@LlmTool functions can\'t be generic. Remove the type parameters from '
        '"${element.displayName}".',
        element: element,
      );
    }

    // 1. Read the tool's name, description and settings.
    final functionName = element.displayName;
    final toolName = annotation.peek('name')?.stringValue ?? functionName;
    // OpenAI, Anthropic and Gemini all reject names outside this pattern.
    if (!_validToolName.hasMatch(toolName)) {
      throw InvalidGenerationSource(
        'Tool name "$toolName" is invalid. To work with every LLM provider it '
        'must start with a letter or "_", then use only letters, digits, "_" '
        'or "-", up to 63 characters. Use @LlmTool(name: ...) to set a valid '
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
        'or use @LlmTool(description: ...).',
        element: element,
      );
    }
    final requiresConfirmation = annotation
        .read('requiresConfirmation')
        .boolValue;

    // 2. Build the schema and the call arguments from the parameters.
    final params = _TypeMapper(
      element.library,
    ).parameters(element.formalParameters, map: 'args', path: '');

    // 3. Write the generated code.
    final schema = {
      'type': 'object',
      'properties': params.properties,
      'required': params.required,
      // Tells the LLM what call() enforces: no extra arguments.
      'additionalProperties': false,
    };
    final callCode = '$call(${params.arguments})';
    final execute = element.returnType is VoidType
        ? '(args) { $callCode; return null; }'
        : '(args) => $callCode';

    return '''
${_toolDefinitionName(element.library)}(
  name: ${_literal(toolName)},
  description: ${_literal(description)},
  parametersSchema: ${_literal(schema)},
  requiresConfirmation: $requiresConfirmation,
  execute: $execute,
)''';
  }
}

/// The `T` of the `ToolDefinition<T>` for a function returning [type]:
/// `Future<T>` and `FutureOr<T>` give `T`, `void` gives `Null`.
DartType _resultType(DartType type, LibraryElement library) {
  if (type is VoidType) return library.typeProvider.nullType;
  if (type is InterfaceType &&
      (type.isDartAsyncFuture || type.isDartAsyncFutureOr)) {
    return type.typeArguments.single;
  }
  return type;
}

/// Dart code for [type] that works inside [library], respecting import
/// prefixes. Types it can't write safely become `Object?`.
String _typeCode(DartType type, LibraryElement library) {
  if (type is VoidType) return 'void';
  if (type is DynamicType) return 'dynamic';
  if (type is InterfaceType) {
    if (type.isDartCoreNull) return 'Null';
    final args = type.typeArguments.isEmpty
        ? ''
        : '<${type.typeArguments.map((t) => _typeCode(t, library)).join(', ')}>';
    final question = type.nullabilitySuffix == NullabilitySuffix.question
        ? '?'
        : '';
    return '${_referenceTo(type.element, library)}$args$question';
  }
  return 'Object?';
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
      // The name the LLM sees: @Param(name: ...) if set, else the Dart name.
      final customName = _paramName(param);
      final name = customName ?? param.displayName;
      final paramPath = path.isEmpty ? name : '$path.$name';
      final kind = path.isEmpty ? 'Parameter' : 'Field';
      if (!_validParameterName.hasMatch(name)) {
        throw InvalidGenerationSource(
          '$kind "$paramPath" has a name some LLM providers reject (Gemini '
          'allows only letters, digits and "_", starting with a letter or '
          '"_", up to 64 characters). '
          '${customName == null ? 'Rename it, or set a valid name with @Param(name: ...).' : 'Change it in @Param(name: ...).'}',
          element: param,
        );
      }
      if (properties.containsKey(name)) {
        throw InvalidGenerationSource(
          'Two parameters are named "$paramPath" for the LLM. Give one a '
          'different @Param(name: ...).',
          element: param,
        );
      }
      final description = _paramDescription(param) ?? _fieldDescription(param);
      properties[name] = {
        ..._withLimits(
          schemaFor(param.type, paramPath, param),
          param,
          paramPath,
        ),
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
        // Dart's own name here: the call is Dart code.
        named.add('${param.displayName}: $code');
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

  /// [schema] with the limits from [param]'s `@Param(min: ..., ...)`.
  ///
  /// Value limits (min, max, minLength, maxLength, pattern) on a list apply
  /// to its items. Limits that can't apply to the type are build errors.
  Map<String, Object?> _withLimits(
    Map<String, Object?> schema,
    FormalParameterElement param,
    String path,
  ) {
    final annotation = _paramChecker.firstAnnotationOf(param);
    if (annotation == null) return schema;
    final reader = ConstantReader(annotation);
    Object? read(String field) => reader.peek(field)?.literalValue;
    final min = read('min') as num?;
    final max = read('max') as num?;
    final minLength = read('minLength') as int?;
    final maxLength = read('maxLength') as int?;
    final pattern = read('pattern') as String?;
    final minItems = read('minItems') as int?;
    final maxItems = read('maxItems') as int?;

    Never fail(String problem) => throw InvalidGenerationSource(
      '${path.contains('.') ? 'Field' : 'Parameter'} "$path": $problem',
      element: param,
    );
    void checkRange(String low, num? lowValue, String high, num? highValue) {
      if (lowValue != null && highValue != null && lowValue > highValue) {
        fail('$low ($lowValue) is greater than $high ($highValue).');
      }
    }

    void checkCount(String name, int? value) {
      if (value != null && value < 0) fail("$name can't be negative.");
    }

    final isList = schema['type'] == 'array';
    // Value limits go on the list's items for a list.
    var target = isList ? (schema['items']! as Map<String, Object?>) : schema;
    final type = target['type'];
    String isNot(String noun) =>
        isList ? 'its items are not ${noun}s' : 'it is not a $noun';

    if (min != null || max != null) {
      if (type != 'integer' && type != 'number' || target.containsKey('enum')) {
        fail(
          'min and max only apply to numbers and lists of numbers, but '
          '${isNot('number')}.',
        );
      }
      for (final (name, value) in [('min', min), ('max', max)]) {
        if (type == 'integer' && value is double && value != value.truncate()) {
          fail('$name must be a whole number for an int, got $value.');
        }
      }
      checkRange('min', min, 'max', max);
    }
    if (minLength != null || maxLength != null || pattern != null) {
      if (type != 'string' || target.containsKey('enum')) {
        fail(
          'minLength, maxLength and pattern only apply to Strings and lists '
          'of Strings, but ${isNot('String')}.',
        );
      }
      checkCount('minLength', minLength);
      checkCount('maxLength', maxLength);
      checkRange('minLength', minLength, 'maxLength', maxLength);
      if (pattern != null) {
        try {
          // How JSON Schema reads patterns: ECMAScript with the u flag.
          RegExp(pattern, unicode: true);
        } on FormatException catch (error) {
          fail(
            'pattern "$pattern" is not a valid regular expression: '
            '${error.message}.',
          );
        }
      }
    }
    if (minItems != null || maxItems != null) {
      if (!isList) fail('minItems and maxItems only apply to Lists.');
      checkCount('minItems', minItems);
      checkCount('maxItems', maxItems);
      checkRange('minItems', minItems, 'maxItems', maxItems);
    }

    target = {
      ...target,
      'minimum': ?min,
      'maximum': ?max,
      'minLength': ?minLength,
      'maxLength': ?maxLength,
      'pattern': ?pattern,
    };
    return isList
        ? {
            ...schema,
            'items': target,
            'minItems': ?minItems,
            'maxItems': ?maxItems,
          }
        : target;
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

/// How the generated code names llm_tool's `ToolDefinition`:
/// `ToolDefinition`, or `ltc.ToolDefinition` when the package is imported
/// `as ltc` (e.g. to avoid a clash with another package's `ToolDefinition`).
String _toolDefinitionName(LibraryElement library) {
  for (final import in library.firstFragment.libraryImports) {
    final element = import.importedLibrary?.exportNamespace.get2(
      'ToolDefinition',
    );
    if (element != null &&
        element.library?.uri.toString().startsWith('package:llm_tool/') ==
            true) {
      return _referenceTo(element, library);
    }
  }
  // Not imported: the user's code doesn't compile anyway, and the analyzer
  // points at the missing import.
  return 'ToolDefinition';
}

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

/// Reads the name from @Param(name: '...') on a parameter, if set.
String? _paramName(Element param) {
  final annotation = _paramChecker.firstAnnotationOf(param);
  if (annotation == null) return null;
  return ConstantReader(annotation).peek('name')?.stringValue;
}

/// Reads the text from @Param('...') on a parameter, if present.
String? _paramDescription(Element param) {
  final annotation = _paramChecker.firstAnnotationOf(param);
  if (annotation == null) return null;
  return ConstantReader(annotation).read('description').stringValue;
}

/// The name of the generated list of all tools in [fileName]:
/// `weather.dart` and `weather_tools.dart` give `weatherTools`,
/// `tools.dart` gives `allTools`.
String toolListName(String fileName) {
  final words = fileName
      .replaceFirst(RegExp(r'\.dart$'), '')
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  // Avoid `weatherToolsTools`.
  if (words.isNotEmpty && words.last.toLowerCase() == 'tools') {
    words.removeLast();
  }
  if (words.isEmpty || words.first.startsWith(RegExp('[0-9]'))) {
    return 'allTools';
  }
  final camelCase = [
    words.first.toLowerCase(),
    for (final word in words.skip(1))
      word[0].toUpperCase() + word.substring(1).toLowerCase(),
  ].join();
  return '${camelCase}Tools';
}

/// Accepted by OpenAI, Anthropic and Gemini. The strictest rules win: Gemini
/// requires a letter or `_` first, and firebase_ai allows 63 characters.
final _validToolName = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_-]{0,62}$');

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
