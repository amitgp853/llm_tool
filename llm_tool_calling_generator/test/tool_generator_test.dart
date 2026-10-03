import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:glob/glob.dart';
import 'package:llm_tool_calling_generator/llm_tool_calling_generator.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(_loadRuntimeSources);

  test('example/example.g.dart matches the generator output', () async {
    // If this fails, regenerate the example's .g.dart (see the comment at
    // the top of example/example.dart) and commit it.
    final source = File('example/example.dart').readAsStringSync();
    final result = await _build(source, path: 'lib/example.dart');
    final part = result.readerWriter.testing.readString(
      AssetId('a', 'lib/example.llm_tool_calling.g.part'),
    );
    expect(
      File('example/example.g.dart').readAsStringSync(),
      "// GENERATED CODE - DO NOT MODIFY BY HAND\n\n"
      "part of 'example.dart';\n\n"
      '$part',
    );
  });

  group('schema', () {
    test('matches the full expected output for a typical tool', () async {
      final output = await _generate('''
/// Gets the current weather for a city.
@Tool()
String getWeather(
  @Param('City name') String city, {
  @Param('Use Celsius') bool celsius = true,
}) => '';
''');
      expect(
        output,
        contains('''
final getWeatherTool = ToolDefinition(
  name: "getWeather",
  description: "Gets the current weather for a city.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "city": {"type": "string", "description": "City name"},
      "celsius": {"type": "boolean", "description": "Use Celsius"},
    },
    "required": ["city"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => getWeather(
    args["city"] as String,
    celsius: args["celsius"] as bool? ?? true,
  ),
);
'''),
      );
    });

    test('maps every supported Dart type to a JSON type', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f(String s, int i, double d, num n, bool b) {}
''');
      expect(output, contains('"s": {"type": "string"}'));
      expect(output, contains('"i": {"type": "integer"}'));
      expect(output, contains('"d": {"type": "number"}'));
      expect(output, contains('"n": {"type": "number"}'));
      expect(output, contains('"b": {"type": "boolean"}'));
    });

    test('omits the description key when there is no @Param', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f(String s) {}
''');
      expect(output, contains('"s": {"type": "string"}'));
    });

    test('a tool without parameters has an empty schema', () async {
      final output = await _generate('''
/// Doc.
@Tool()
String now() => '';
''');
      expect(output, contains('"properties": {}'));
      expect(output, contains('"required": []'));
      expect(output, contains('execute: (args) => now()'));
    });
  });

  group('required and optional parameters', () {
    test('required positional and required named are required', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f(String a, {required int b}) {}
''');
      expect(output, contains('"required": ["a", "b"]'));
      expect(
        output,
        contains('f(args["a"] as String, b: (args["b"] as num).toInt())'),
      );
    });

    test('optional positional nullable parameter is optional', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f([String? a]) {}
''');
      expect(output, contains('"required": []'));
      expect(output, contains('f(args["a"] as String?)'));
    });

    test('nullable named parameter is optional', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f({String? a}) {}
''');
      expect(output, contains('"required": []'));
      expect(output, contains('f(a: args["a"] as String?)'));
    });

    test('`required` but nullable named parameter is optional', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f({required String? a}) {}
''');
      expect(output, contains('"required": []'));
      expect(output, contains('f(a: args["a"] as String?)'));
    });

    test('positional arguments come before named ones', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f(String a, {String? b}) {}
''');
      expect(
        output,
        contains('f(args["a"] as String, b: args["b"] as String?)'),
      );
    });
  });

  group('default values', () {
    test('a parameter with a default is optional and uses ??', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f({int count = 3}) {}
''');
      expect(output, contains('"required": []'));
      expect(output, contains('count: (args["count"] as num?)?.toInt() ?? 3'));
    });

    test('optional positional default', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f([bool flag = false]) {}
''');
      expect(output, contains('f(args["flag"] as bool? ?? false)'));
    });

    test('string default keeps its quotes', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f({String unit = 'metric'}) {}
''');
      expect(output, contains("unit: args[\"unit\"] as String? ?? 'metric'"));
    });

    test('default that refers to a constant', () async {
      final output = await _generate('''
const defaultCount = 2;

/// Doc.
@Tool()
void f({int count = defaultCount}) {}
''');
      expect(output, contains('?? defaultCount'));
    });
  });

  group('double and int conversion', () {
    test('required double is read as num and converted', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f(double x) {}
''');
      expect(output, contains('f((args["x"] as num).toDouble())'));
    });

    test('double with an int-literal default compiles', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f({double x = 1}) {}
''');
      expect(output, contains('x: (args["x"] as num?)?.toDouble() ?? 1'));
    });

    test('nullable int is read as num and converted', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f({int? x}) {}
''');
      expect(output, contains('x: (args["x"] as num?)?.toInt()'));
    });

    test('num is cast directly', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f(num x) {}
''');
      expect(output, contains('f(args["x"] as num)'));
    });
  });

  group('return types', () {
    test('void function returns null', () async {
      final output = await _generate('''
/// Doc.
@Tool()
void f() {}
''');
      expect(output, contains('execute: (args) {'));
      expect(output, contains('f();'));
      expect(output, contains('return null;'));
    });

    test('async function returns its Future', () async {
      final output = await _generate('''
/// Doc.
@Tool()
Future<String> f(String a) async => a;
''');
      expect(output, contains('execute: (args) => f(args["a"] as String)'));
    });

    test('Future<void> function compiles', () async {
      final output = await _generate('''
/// Doc.
@Tool()
Future<void> f() async {}
''');
      expect(output, contains('execute: (args) => f()'));
    });
  });

  group('@Tool options', () {
    test('custom name is used, variable keeps the function name', () async {
      final output = await _generate('''
/// Doc.
@Tool(name: 'get_weather')
void getWeather() {}
''');
      expect(output, contains('final getWeatherTool = ToolDefinition('));
      expect(output, contains('name: "get_weather"'));
    });

    test('description argument wins over the doc comment', () async {
      final output = await _generate('''
/// From the doc comment.
@Tool(description: 'From the annotation.')
void f() {}
''');
      expect(output, contains('description: "From the annotation."'));
      expect(output, isNot(contains('From the doc comment.')));
    });

    test('description argument works without a doc comment', () async {
      final output = await _generate('''
@Tool(description: 'From the annotation.')
void f() {}
''');
      expect(output, contains('description: "From the annotation."'));
    });

    test('requiresConfirmation is passed through', () async {
      final output = await _generate('''
/// Deletes a file.
@Tool(requiresConfirmation: true)
void deleteFile(String path) {}
''');
      expect(output, contains('requiresConfirmation: true'));
    });

    test('generates every tool in a file', () async {
      final output = await _generate('''
/// One.
@Tool()
void one() {}

/// Two.
@Tool()
void two() {}
''');
      expect(output, contains('final oneTool = '));
      expect(output, contains('final twoTool = '));
    });
  });

  group('doc comments', () {
    test('multi-line /// comment is joined into one line', () async {
      final output = await _generate('''
/// Gets the weather
/// for a city.
@Tool()
void f() {}
''');
      expect(output, contains('description: "Gets the weather for a city."'));
    });

    test('paragraph breaks are kept', () async {
      final output = await _generate('''
/// First paragraph.
///
/// Second paragraph.
@Tool()
void f() {}
''');
      expect(output, contains(r'"First paragraph.\n\nSecond paragraph."'));
    });

    test('/** */ block comment is cleaned', () async {
      final output = await _generate('''
/**
 * Block comment
 * description.
 */
@Tool()
void f() {}
''');
      expect(output, contains('description: "Block comment description."'));
    });

    test('single-line /** */ comment is cleaned', () async {
      final output = await _generate('''
/** Short block. */
@Tool()
void f() {}
''');
      expect(output, contains('description: "Short block."'));
    });
  });

  group('escaping', () {
    test(r'quotes and $ in descriptions are escaped', () async {
      final output = await _generate(r'''
/// Costs $5 and says "hi" with a \ backslash.
@Tool()
void f(@Param('Price in \$, e.g. "10"') num price) {}
''');
      expect(
        output,
        contains(
          r'description: "Costs \$5 and says \"hi\" with a \\ backslash."',
        ),
      );
      expect(output, contains(r'"description": "Price in \$, e.g. \"10\""'));
    });

    test(r'${...} in a description is not interpolated', () async {
      final output = await _generate(r'''
@Tool(description: 'Uses \${secret} literally.')
void f() {}
''');
      expect(output, contains(r'description: "Uses \${secret} literally."'));
    });
  });

  group('errors', () {
    test('@Tool on a class', () async {
      expect(
        await _buildErrors('''
/// Doc.
@Tool()
class NotAFunction {}
'''),
        contains('@Tool can only be used on top-level functions.'),
      );
    });

    test('@Tool on a top-level variable', () async {
      expect(
        await _buildErrors('''
/// Doc.
@Tool()
final notAFunction = 1;
'''),
        contains('@Tool can only be used on top-level functions.'),
      );
    });

    // source_gen skips files without any top-level annotation before our
    // generator runs, so these files also contain a top-level tool.
    for (final (kind, container) in [
      ('instance method', 'class C {\n  /// Doc.\n  @Tool()\n  void m() {}\n}'),
      (
        'static method',
        'class C {\n  /// Doc.\n  @Tool()\n  static void m() {}\n}',
      ),
      ('mixin method', 'mixin C {\n  /// Doc.\n  @Tool()\n  void m() {}\n}'),
      (
        'extension method',
        'extension C on int {\n  /// Doc.\n  @Tool()\n  void m() {}\n}',
      ),
    ]) {
      test('@Tool on a $kind is an error, not silently ignored', () async {
        expect(
          await _buildErrors('/// Doc.\n@Tool()\nvoid f() {}\n\n$container'),
          contains('"C.m" is a method.'),
        );
      });
    }

    test(
      'known limitation: a file with only @Tool methods is skipped',
      () async {
        // Catching this would mean resolving every file in the user's package
        // on every build. Documented in the README instead.
        final result = await _build(
          '$_header'
          'class C {\n  /// Doc.\n  @Tool()\n  void m() {}\n}',
        );
        expect(result.succeeded, isTrue);
        expect(result.outputs, isEmpty);
      },
    );

    test('generic function', () async {
      expect(
        await _buildErrors('''
/// Doc.
@Tool()
T f<T>(T a) => a;
'''),
        contains("@Tool functions can't be generic."),
      );
    });

    test('missing description', () async {
      expect(
        await _buildErrors('''
@Tool()
void f() {}
'''),
        contains('Tool "f" needs a description.'),
      );
    });

    test('empty description argument', () async {
      expect(
        await _buildErrors('''
@Tool(description: '')
void f() {}
'''),
        contains('Tool "f" needs a description.'),
      );
    });

    test('empty doc comment', () async {
      expect(
        await _buildErrors('''
///
@Tool()
void f() {}
'''),
        contains('Tool "f" needs a description.'),
      );
    });

    for (final name in ['get weather', 'get.weather', '', 'a' * 65]) {
      test('invalid custom name "$name"', () async {
        expect(
          await _buildErrors('''
/// Doc.
@Tool(name: '$name')
void f() {}
'''),
          contains('Tool name "$name" is invalid.'),
        );
      });
    }

    test(r'function name with $ needs a custom name', () async {
      expect(
        await _buildErrors(r'''
/// Doc.
@Tool()
void get$weather() {}
'''),
        contains(r'Tool name "get$weather" is invalid.'),
      );
    });

    for (final type in [
      'List<String>',
      'Map<String, Object?>',
      'dynamic',
      'Object',
      'DateTime',
      'void Function()',
    ]) {
      test('unsupported parameter type $type', () async {
        expect(
          await _buildErrors('''
/// Doc.
@Tool()
void f($type x) {}
'''),
          allOf(
            contains('Parameter "x" has type $type'),
            contains('not supported yet'),
          ),
        );
      });
    }
  });
}

/// Source of the real llm_tool_calling package, so `@Tool` resolves.
late Map<String, String> _runtimeSources;

Future<void> _loadRuntimeSources() async {
  final reader = await PackageAssetReader.currentIsolate();
  _runtimeSources = {};
  await for (final id in reader.findAssets(
    Glob('lib/**.dart'),
    package: 'llm_tool_calling',
  )) {
    _runtimeSources['$id'] = await reader.readAsString(id);
  }
}

const _header = '''
import 'package:llm_tool_calling/llm_tool_calling.dart';

part 'tools.g.dart';

''';

Future<TestBuilderResult> _build(
  String source, {
  String path = 'lib/tools.dart',
}) => testBuilder(
  toolBuilder(BuilderOptions.empty),
  {..._runtimeSources, 'a|$path': source},
  rootPackage: 'a',
  generateFor: {'a|$path'},
  flattenOutput: true,
);

/// Runs the real builder on [tools] and returns the generated code.
///
/// Also checks that the generated code compiles, because text checks alone
/// can't catch a wrong cast or a type error.
Future<String> _generate(String tools) async {
  final source = '$_header$tools';
  final result = await _build(source);
  expect(result.errors, isEmpty);
  expect(result.succeeded, isTrue);

  final output = result.readerWriter.testing.readString(
    AssetId('a', 'lib/tools.llm_tool_calling.g.part'),
  );
  expect(await _compileErrors(source, output), isEmpty, reason: output);
  return output;
}

/// Runs the builder on [tools], expecting it to fail, and returns the errors.
Future<String> _buildErrors(String tools) async {
  final result = await _build('$_header$tools');
  expect(result.succeeded, isFalse);
  return result.errors.join('\n');
}

/// Analyzer errors for [source] combined with its [generated] part.
Future<List<String>> _compileErrors(String source, String generated) =>
    resolveSources(
      {
        ..._runtimeSources,
        'a|lib/tools.dart': source,
        'a|lib/tools.g.dart': "part of 'tools.dart';\n$generated",
      },
      (resolver) async {
        final library = await resolver.libraryFor(
          AssetId('a', 'lib/tools.dart'),
        );
        final resolved =
            await library.session.getResolvedLibraryByElement(library)
                as ResolvedLibraryResult;
        return [
          for (final unit in resolved.units)
            for (final diagnostic in unit.diagnostics)
              if (diagnostic.severity == Severity.error) diagnostic.message,
        ];
      },
      rootPackage: 'a',
      resolverFor: 'a|lib/tools.dart',
    );
