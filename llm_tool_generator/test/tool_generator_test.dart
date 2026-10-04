import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:glob/glob.dart';
import 'package:llm_tool_generator/llm_tool_generator.dart';
import 'package:llm_tool_generator/src/tool_generator.dart' show toolListName;
import 'package:test/test.dart';

void main() {
  setUpAll(_loadRuntimeSources);

  test('example/example.g.dart matches the generator output', () async {
    // If this fails, regenerate the example's .g.dart (see the comment at
    // the top of example/example.dart) and commit it.
    final source = File('example/example.dart').readAsStringSync();
    final result = await _build(source, path: 'lib/example.dart');
    final part = result.readerWriter.testing.readString(
      AssetId('a', 'lib/example.llm_tool.g.part'),
    );
    expect(
      File('example/example.g.dart').readAsStringSync(),
      "// GENERATED CODE - DO NOT MODIFY BY HAND\n\n"
      "part of 'example.dart';\n\n"
      '$part',
    );
  });

  test('the deprecated @Tool() still works until 1.0', () async {
    final output = await _generate('''
/// Doc.
// ignore: deprecated_member_use
@Tool()
void f(String a) {}
''');
    expect(output, contains('final fTool = ToolDefinition('));
  });

  group('schema', () {
    test('matches the full expected output for a typical tool', () async {
      final output = await _generate('''
/// Gets the current weather for a city.
@LlmTool()
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
@LlmTool()
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
@LlmTool()
void f(String s) {}
''');
      expect(output, contains('"s": {"type": "string"}'));
    });

    test('a tool without parameters has an empty schema', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
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
@LlmTool()
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
@LlmTool()
void f([String? a]) {}
''');
      expect(output, contains('"required": []'));
      expect(output, contains('f(args["a"] as String?)'));
    });

    test('nullable named parameter is optional', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f({String? a}) {}
''');
      expect(output, contains('"required": []'));
      expect(output, contains('f(a: args["a"] as String?)'));
    });

    test('`required` but nullable named parameter is optional', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f({required String? a}) {}
''');
      expect(output, contains('"required": []'));
      expect(output, contains('f(a: args["a"] as String?)'));
    });

    test('positional arguments come before named ones', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
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
@LlmTool()
void f({int count = 3}) {}
''');
      expect(output, contains('"required": []'));
      expect(output, contains('count: (args["count"] as num?)?.toInt() ?? 3'));
    });

    test('optional positional default', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f([bool flag = false]) {}
''');
      expect(output, contains('f(args["flag"] as bool? ?? false)'));
    });

    test('string default keeps its quotes', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f({String unit = 'metric'}) {}
''');
      expect(output, contains("unit: args[\"unit\"] as String? ?? 'metric'"));
    });

    test('default that refers to a constant', () async {
      final output = await _generate('''
const defaultCount = 2;

/// Doc.
@LlmTool()
void f({int count = defaultCount}) {}
''');
      expect(output, contains('?? defaultCount'));
    });
  });

  group('double and int conversion', () {
    test('required double is read as num and converted', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f(double x) {}
''');
      expect(output, contains('f((args["x"] as num).toDouble())'));
    });

    test('double with an int-literal default compiles', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f({double x = 1}) {}
''');
      expect(output, contains('x: (args["x"] as num?)?.toDouble() ?? 1'));
    });

    test('nullable int is read as num and converted', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f({int? x}) {}
''');
      expect(output, contains('x: (args["x"] as num?)?.toInt()'));
    });

    test('num is cast directly', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f(num x) {}
''');
      expect(output, contains('f(args["x"] as num)'));
    });
  });

  group('enums', () {
    const unitEnum = 'enum Unit { celsius, fahrenheit }\n\n';

    test('become a string schema listing the value names', () async {
      final output = await _generate('''
$unitEnum/// Doc.
@LlmTool()
void f(Unit unit) {}
''');
      expect(
        output,
        contains(
          '"unit": {\n        "type": "string",\n'
          '        "enum": ["celsius", "fahrenheit"],\n      }',
        ),
      );
      expect(output, contains('"required": ["unit"]'));
      expect(output, contains('f(Unit.values.byName(args["unit"] as String))'));
    });

    test('description comes after the enum values', () async {
      final output = await _generate('''
$unitEnum/// Doc.
@LlmTool()
void f(@Param('Temperature unit') Unit unit) {}
''');
      expect(output, contains('"description": "Temperature unit"'));
    });

    test('nullable enum is optional and stays null when missing', () async {
      final output = await _generate('''
$unitEnum/// Doc.
@LlmTool()
void f({Unit? unit}) {}
''');
      expect(output, contains('"required": []'));
      expect(
        _withoutSpaces(output),
        contains(
          'unit:(args["unit"]==null?null:Unit.values.byName(args["unit"]asString))',
        ),
      );
    });

    test('enum with a default value uses the default when missing', () async {
      final output = await _generate('''
$unitEnum/// Doc.
@LlmTool()
void f({Unit unit = Unit.celsius}) {}
''');
      expect(output, contains('"required": []'));
      // The default must apply to the whole conditional, not just its else.
      expect(_withoutSpaces(output), contains('asString))??Unit.celsius'));
    });

    test('enhanced enum uses value names only', () async {
      final output = await _generate('''
enum Size {
  small(1),
  large(10);

  const Size(this.weight);
  final int weight;
}

/// Doc.
@LlmTool()
void f(Size size) {}
''');
      expect(output, contains('"enum": ["small", "large"]'));
    });

    group('imported from another file', () {
      const units = {'a|lib/units.dart': 'enum Unit { celsius, fahrenheit }'};
      const tool = '/// Doc.\n@LlmTool()\nvoid f(u.Unit unit) {}\n';

      test('without a prefix', () async {
        final output = await _generate(
          '/// Doc.\n@LlmTool()\nvoid f(Unit unit) {}\n',
          extraSources: units,
          header:
              "import 'package:llm_tool/llm_tool.dart';\n"
              "import 'units.dart';\n\n"
              "part 'tools.g.dart';\n\n",
        );
        expect(output, contains('Unit.values.byName('));
        expect(output, isNot(contains('u.Unit')));
      });

      test('with a prefix, the generated code uses the prefix', () async {
        final output = await _generate(
          tool,
          extraSources: units,
          header:
              "import 'package:llm_tool/llm_tool.dart';\n"
              "import 'units.dart' as u;\n\n"
              "part 'tools.g.dart';\n\n",
        );
        expect(output, contains('u.Unit.values.byName('));
      });

      test('imported both ways, the unprefixed name wins', () async {
        final output = await _generate(
          tool,
          extraSources: units,
          header:
              "import 'package:llm_tool/llm_tool.dart';\n"
              "import 'units.dart' as u;\n"
              "import 'units.dart';\n\n"
              "part 'tools.g.dart';\n\n",
        );
        expect(output, contains('f(Unit.values.byName('));
      });
    });

    test('private enum works', () async {
      final output = await _generate('''
enum _Mode { fast, safe }

/// Doc.
@LlmTool()
void f(_Mode mode) {}
''');
      expect(output, contains('_Mode.values.byName('));
    });
  });

  group('lists', () {
    test('List<String> becomes an array of strings', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f(@Param('Tags to add') List<String> tags) {}
''');
      expect(
        _withoutSpaces(output),
        contains(
          '"tags":{"type":"array","items":{"type":"string"},'
          '"description":"Tagstoadd"}',
        ),
      );
      expect(output, contains('"required": ["tags"]'));
      expect(
        _withoutSpaces(output),
        contains('f((args["tags"]asList).map((e)=>easString).toList())'),
      );
    });

    test('items of every simple type are converted', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f(List<int> i, List<double> d, List<num> n, List<bool> b) {}
''');
      final code = _withoutSpaces(output);
      expect(code, contains('"i":{"type":"array","items":{"type":"integer"}}'));
      expect(code, contains('"d":{"type":"array","items":{"type":"number"}}'));
      expect(code, contains('(e)=>(easnum).toInt()'));
      expect(code, contains('(e)=>(easnum).toDouble()'));
      expect(code, contains('(e)=>easnum)'));
      expect(code, contains('(e)=>easbool)'));
    });

    test('list of enums', () async {
      final output = await _generate('''
enum Color { red, green }

/// Doc.
@LlmTool()
void f(List<Color> colors) {}
''');
      final code = _withoutSpaces(output);
      expect(
        code,
        contains('"items":{"type":"string","enum":["red","green"]}'),
      );
      expect(code, contains('(e)=>Color.values.byName(easString)'));
    });

    test('nested lists', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f(List<List<int>> grid) {}
''');
      final code = _withoutSpaces(output);
      expect(
        code,
        contains('"items":{"type":"array","items":{"type":"integer"}}'),
      );
      expect(
        code,
        contains(
          '(args["grid"]asList).map((e)=>(easList).map((e)=>(easnum).toInt()).toList()).toList()',
        ),
      );
    });

    test('nullable list is optional and stays null when missing', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f({List<String>? tags}) {}
''');
      expect(output, contains('"required": []'));
      expect(
        _withoutSpaces(output),
        contains(
          'tags:(args["tags"]==null?null:(args["tags"]asList).map((e)=>easString).toList())',
        ),
      );
    });

    test('list with a default uses it when missing', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f({List<String> tags = const ['a']}) {}
''');
      expect(output, contains('"required": []'));
      expect(_withoutSpaces(output), contains(".toList())??const['a']"));
    });

    test('list of an enum from a prefixed import', () async {
      final output = await _generate(
        '/// Doc.\n@LlmTool()\nvoid f(List<u.Unit> units) {}\n',
        extraSources: {'a|lib/units.dart': 'enum Unit { c, f }'},
        header:
            "import 'package:llm_tool/llm_tool.dart';\n"
            "import 'units.dart' as u;\n\n"
            "part 'tools.g.dart';\n\n",
      );
      expect(output, contains('u.Unit.values.byName('));
    });
  });

  group('classes', () {
    const passenger = '''
/// A person on the flight.
class Passenger {
  Passenger({required this.name, required this.age, this.nickname});

  /// Full name as on the passport.
  final String name;
  final int age;
  final String? nickname;
}

''';

    test('become a nested object schema', () async {
      final output = await _generate('''
$passenger/// Doc.
@LlmTool()
void book(Passenger passenger) {}
''');
      expect(
        _withoutSpaces(output),
        contains(
          '"passenger":{"type":"object",'
          '"description":"Apersonontheflight.",'
          '"properties":{'
          '"name":{"type":"string","description":"Fullnameasonthepassport."},'
          '"age":{"type":"integer"},'
          '"nickname":{"type":"string"}},'
          '"required":["name","age"],'
          '"additionalProperties":false}',
        ),
      );
      expect(
        _withoutSpaces(output),
        contains(
          'book(((Mapjson)=>Passenger('
          'name:json["name"]asString,'
          'age:(json["age"]asnum).toInt(),'
          'nickname:json["nickname"]asString?))'
          '(args["passenger"]asMap))',
        ),
      );
    });

    test('@Param on the tool parameter replaces the class doc', () async {
      final output = await _generate('''
$passenger/// Doc.
@LlmTool()
void book(@Param('Who is flying') Passenger passenger) {}
''');
      expect(output, contains('"description": "Who is flying"'));
      expect(output, isNot(contains('A person on the flight.')));
    });

    test('@Param on a constructor parameter describes the field', () async {
      final output = await _generate('''
class Seat {
  Seat(@Param('Row number') this.row);
  final int row;
}

/// Doc.
@LlmTool()
void f(Seat seat) {}
''');
      expect(output, contains('"description": "Row number"'));
      expect(
        _withoutSpaces(output),
        contains(
          '((Mapjson)=>Seat((json["row"]asnum).toInt()))(args["seat"]asMap)',
        ),
      );
    });

    test('nullable class parameter stays null when missing', () async {
      final output = await _generate('''
$passenger/// Doc.
@LlmTool()
void book({Passenger? passenger}) {}
''');
      expect(output, contains('"required": []'));
      expect(
        _withoutSpaces(output),
        contains(
          'passenger:(args["passenger"]==null?null:((Mapjson)=>Passenger(',
        ),
      );
    });

    test('field defaults from the same file are used', () async {
      final output = await _generate('''
enum Cabin { economy, business }

class Booking {
  Booking({this.cabin = Cabin.economy, this.bags = 1});
  final Cabin cabin;
  final int bags;
}

/// Doc.
@LlmTool()
void f(Booking booking) {}
''');
      final code = _withoutSpaces(output);
      expect(code, contains('"required":[]'));
      expect(code, contains('??Cabin.economy'));
      expect(code, contains('.toInt()??1'));
    });

    test('list of classes', () async {
      final output = await _generate('''
$passenger/// Doc.
@LlmTool()
void book(List<Passenger> group) {}
''');
      final code = _withoutSpaces(output);
      expect(
        code,
        contains('"group":{"type":"array","items":{"type":"object"'),
      );
      expect(
        code,
        contains(
          '(args["group"]asList).map((e)=>((Mapjson)=>Passenger(name:json["name"]asString',
        ),
      );
    });

    test('classes inside classes, with enums and lists', () async {
      final output = await _generate('''
enum Meal { veg, nonVeg }

class Address {
  Address({required this.city});
  final String city;
}

class Traveller {
  Traveller({required this.address, required this.meals});
  final Address address;
  final List<Meal> meals;
}

/// Doc.
@LlmTool()
void f(Traveller traveller) {}
''');
      final code = _withoutSpaces(output);
      expect(
        code,
        contains(
          '"address":{"type":"object","properties":{"city":{"type":"string"}}',
        ),
      );
      expect(
        code,
        contains(
          'Traveller(address:((Mapjson)=>Address(city:json["city"]asString))(json["address"]asMap)',
        ),
      );
      expect(code, contains('Meal.values.byName(easString)'));
    });

    test('freezed-style class with a factory constructor', () async {
      final output = await _generate('''
abstract class Point {
  const factory Point({required int x, required int y}) = _Point;
}

class _Point implements Point {
  const _Point({required this.x, required this.y});
  final int x;
  final int y;
}

/// Doc.
@LlmTool()
void f(Point point) {}
''');
      expect(_withoutSpaces(output), contains('f(((Mapjson)=>Point(x:'));
    });

    group('from another file', () {
      const models = {
        'a|lib/models.dart': '''
enum Seat { aisle, window }

const _defaultBags = 2;

class Booking {
  Booking({
    this.seat = Seat.window,
    this.bags = _defaultBags,
    this.note = 'none',
    this.tags = const ['vip'],
    this.ratio = 0.5,
  });
  final Seat seat;
  final int bags;
  final String note;
  final List<String> tags;
  final double ratio;
}
''',
      };

      test('defaults are rebuilt, with the import prefix', () async {
        final output = await _generate(
          '/// Doc.\n@LlmTool()\nvoid f(m.Booking booking) {}\n',
          extraSources: models,
          header:
              "import 'package:llm_tool/llm_tool.dart';\n"
              "import 'models.dart' as m;\n\n"
              "part 'tools.g.dart';\n\n",
        );
        final code = _withoutSpaces(output);
        expect(code, contains('f(((Mapjson)=>m.Booking('));
        expect(code, contains('??m.Seat.window'));
        // The private constant's value, not its name:
        expect(code, contains('.toInt()??2'));
        expect(code, isNot(contains('_defaultBags')));
        expect(code, contains('??"none"'));
        expect(code, contains('??const["vip"]'));
        expect(code, contains('??0.5'));
      });

      test('a default that is not a literal is a clear error', () async {
        final result = await _build(
          "import 'package:llm_tool/llm_tool.dart';\n"
          "import 'trip.dart';\n\n"
          "part 'tools.g.dart';\n\n"
          '/// Doc.\n@LlmTool()\nvoid f(Trip trip) {}\n',
          extraSources: {
            'a|lib/trip.dart': '''
class Stop {
  const Stop({required this.city});
  final String city;
}

class Trip {
  Trip({this.start = const Stop(city: 'Kanpur')});
  final Stop start;
}
''',
          },
        );
        expect(result.succeeded, isFalse);
        expect(
          result.errors.join('\n'),
          contains(
            'Field "trip.start" has a default value that can\'t be copied',
          ),
        );
      });
    });

    group('errors', () {
      test('unsupported field type names the field path', () async {
        expect(
          await _buildErrors('''
class Person {
  Person({required this.birthday});
  final DateTime birthday;
}

/// Doc.
@LlmTool()
void f(Person person) {}
'''),
          contains(
            'Field "person.birthday" has type DateTime, which is not '
            'supported yet.',
          ),
        );
      });

      test('generic class', () async {
        expect(
          await _buildErrors('''
class Box<T> {
  Box(this.value);
  final T value;
}

/// Doc.
@LlmTool()
void f(Box<int> box) {}
'''),
          contains('which is generic.'),
        );
      });

      test('class without an unnamed constructor', () async {
        expect(
          await _buildErrors('''
class Point {
  Point.origin();
}

/// Doc.
@LlmTool()
void f(Point point) {}
'''),
          contains('which has no unnamed constructor'),
        );
      });

      test('abstract class without a factory constructor', () async {
        expect(
          await _buildErrors('''
abstract class Shape {
  Shape();
}

/// Doc.
@LlmTool()
void f(Shape shape) {}
'''),
          contains('which is abstract.'),
        );
      });

      test('class that contains itself', () async {
        expect(
          await _buildErrors('''
class Node {
  Node({this.next});
  final Node? next;
}

/// Doc.
@LlmTool()
void f(Node node) {}
'''),
          contains('Field "node.next" has type Node?, which contains itself.'),
        );
      });

      test('classes that contain each other', () async {
        expect(
          await _buildErrors('''
class A {
  A({this.b});
  final B? b;
}

class B {
  B({this.a});
  final A? a;
}

/// Doc.
@LlmTool()
void f(A a) {}
'''),
          contains('Field "a.b.a" has type A?, which contains itself.'),
        );
      });

      test('the same class twice is fine (not recursion)', () async {
        final output = await _generate('''
class Point {
  Point({required this.x});
  final int x;
}

class Line {
  Line({required this.from, required this.to});
  final Point from;
  final Point to;
}

/// Doc.
@LlmTool()
void f(Line line, Point extra) {}
''');
        expect(output, contains('Line('));
      });
    });
  });

  group('list of all tools', () {
    test('lists every tool in source order, named after the file', () async {
      final output = await _generate('''
/// One.
@LlmTool()
void one() {}

/// Two.
@LlmTool(name: 'second')
void two() {}
''');
      expect(
        _withoutSpaces(output),
        contains('finalallTools=[oneTool,twoTool]'),
      );
      expect(output, contains('/// Every tool in this file'));
    });

    test('the list is typed by the common return type (no casts)', () async {
      // The source uses the generated list; the compile check fails unless
      // allTools is List<ToolDefinition<Command?>> and tools are typed.
      await _generate('''
sealed class Command {
  const Command();
}

final class Analyze extends Command {
  const Analyze();
}

final class Stats extends Command {
  const Stats();
}

/// Analyze.
@LlmTool()
Analyze analyze() => const Analyze();

/// Stats.
@LlmTool()
Future<Stats> stats() async => const Stats();

/// Delete.
@LlmTool()
void delete() {}

Future<Command?> firstCommand() => allTools.first({});
Future<Analyze> analyzeTyped() => analyzeTool({});
Future<Stats> statsTyped() => statsTool({});
''');
    });

    test('a single tool still gets a list', () async {
      final output = await _generate('/// Doc.\n@LlmTool()\nvoid only() {}\n');
      expect(_withoutSpaces(output), contains('allTools=[onlyTool]'));
    });

    test('other file names give other list names', () async {
      final result = await _build(
        "import 'package:llm_tool/llm_tool.dart';\n\n"
        "part 'flight_booking.g.dart';\n\n"
        '/// Doc.\n@LlmTool()\nvoid book() {}\n',
        path: 'lib/flight_booking.dart',
      );
      final output = result.readerWriter.testing.readString(
        AssetId('a', 'lib/flight_booking.llm_tool.g.part'),
      );
      expect(_withoutSpaces(output), contains('flightBookingTools=[bookTool]'));
    });

    group('toolListName', () {
      for (final (file, name) in [
        ('tools.dart', 'allTools'),
        ('weather.dart', 'weatherTools'),
        ('weather_tools.dart', 'weatherTools'),
        ('flight_booking.dart', 'flightBookingTools'),
        ('my_AI_tools.dart', 'myAiTools'),
        ('_private.dart', 'privateTools'),
        ('2fa.dart', 'allTools'),
        ('tools_tools.dart', 'toolsTools'),
      ]) {
        test('$file -> $name', () => expect(toolListName(file), name));
      }
    });
  });

  group('import prefixes', () {
    const prefixedHeader =
        "import 'package:llm_tool/llm_tool.dart' as ltc;\n\n"
        "part 'tools.g.dart';\n\n";

    test('llm_tool imported with a prefix', () async {
      final output = await _generate(
        "/// Doc.\n@ltc.LlmTool()\nvoid f(@ltc.Param('City') String city) {}\n",
        header: prefixedHeader,
      );
      expect(output, contains('final fTool = ltc.ToolDefinition('));
      expect(output, contains('final allTools = ['));
      expect(output, contains('"description": "City"'));
    });

    test('another ToolDefinition in scope (e.g. flutter_ai_core)', () async {
      final output = await _generate(
        // The other SDK's ToolDefinition is used by the app, unprefixed.
        'const otherDefinition = ToolDefinition();\n\n'
        '/// Doc.\n@ltc.LlmTool()\nvoid f() {}\n',
        extraSources: {
          'a|lib/other_sdk.dart':
              'class ToolDefinition { const ToolDefinition(); }',
        },
        header:
            "import 'package:llm_tool/llm_tool.dart' as ltc;\n"
            "import 'other_sdk.dart';\n\n"
            "part 'tools.g.dart';\n\n",
      );
      expect(output, contains('ltc.ToolDefinition('));
    });
  });

  group('JSON names with @Param(name:)', () {
    test('the LLM sees the JSON name; Dart keeps its own name', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f(
  @Param('A game id', name: 'game_id') int gameId, {
  @Param('Move number', name: 'move_number') int moveNumber = 1,
  @Param('Nickname', name: 'nick_name') String? nickName,
}) {}
''');
      final code = _withoutSpaces(output);
      expect(
        code,
        contains('"game_id":{"type":"integer","description":"Agameid"}'),
      );
      expect(code, contains('"move_number":{"type":"integer"'));
      expect(code, contains('"nick_name":{"type":"string"'));
      expect(code, contains('"required":["game_id"]'));
      expect(code, isNot(contains('"gameId"')));
      expect(
        code,
        contains(
          'f((args["game_id"]asnum).toInt(),'
          'moveNumber:(args["move_number"]asnum?)?.toInt()??1,'
          'nickName:args["nick_name"]asString?)',
        ),
      );
    });

    test('works for class fields', () async {
      final output = await _generate('''
class Seat {
  Seat(@Param('Row number', name: 'row_number') this.row);
  final int row;
}

/// Doc.
@LlmTool()
void f(Seat seat) {}
''');
      final code = _withoutSpaces(output);
      expect(code, contains('"row_number":{"type":"integer"'));
      expect(code, contains('Seat((json["row_number"]asnum).toInt())'));
    });

    test('an invalid name is a clear error', () async {
      expect(
        await _buildErrors('''
/// Doc.
@LlmTool()
void f(@Param('Id', name: 'game id') int gameId) {}
'''),
        allOf(
          contains('Parameter "game id" has a name some LLM providers reject'),
          contains('Change it in @Param(name: ...).'),
        ),
      );
    });

    test('two parameters with the same JSON name are an error', () async {
      expect(
        await _buildErrors('''
/// Doc.
@LlmTool()
void f(@Param('First', name: 'b') int a, int b) {}
'''),
        contains('Two parameters are named "b" for the LLM.'),
      );
    });
  });

  group('return types', () {
    test('void function returns null', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
void f() {}
''');
      expect(output, contains('execute: (args) {'));
      expect(output, contains('f();'));
      expect(output, contains('return null;'));
    });

    test('async function returns its Future', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
Future<String> f(String a) async => a;
''');
      expect(output, contains('execute: (args) => f(args["a"] as String)'));
    });

    test('Future<void> function compiles', () async {
      final output = await _generate('''
/// Doc.
@LlmTool()
Future<void> f() async {}
''');
      expect(output, contains('execute: (args) => f()'));
    });
  });

  group('@Tool options', () {
    test('custom name is used, variable keeps the function name', () async {
      final output = await _generate('''
/// Doc.
@LlmTool(name: 'get_weather')
void getWeather() {}
''');
      expect(output, contains('final getWeatherTool = ToolDefinition('));
      expect(output, contains('name: "get_weather"'));
    });

    test('description argument wins over the doc comment', () async {
      final output = await _generate('''
/// From the doc comment.
@LlmTool(description: 'From the annotation.')
void f() {}
''');
      expect(output, contains('description: "From the annotation."'));
      expect(output, isNot(contains('From the doc comment.')));
    });

    test('description argument works without a doc comment', () async {
      final output = await _generate('''
@LlmTool(description: 'From the annotation.')
void f() {}
''');
      expect(output, contains('description: "From the annotation."'));
    });

    test('requiresConfirmation is passed through', () async {
      final output = await _generate('''
/// Deletes a file.
@LlmTool(requiresConfirmation: true)
void deleteFile(String path) {}
''');
      expect(output, contains('requiresConfirmation: true'));
    });

    test('generates every tool in a file', () async {
      final output = await _generate('''
/// One.
@LlmTool()
void one() {}

/// Two.
@LlmTool()
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
@LlmTool()
void f() {}
''');
      expect(output, contains('description: "Gets the weather for a city."'));
    });

    test('paragraph breaks are kept', () async {
      final output = await _generate('''
/// First paragraph.
///
/// Second paragraph.
@LlmTool()
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
@LlmTool()
void f() {}
''');
      expect(output, contains('description: "Block comment description."'));
    });

    test('single-line /** */ comment is cleaned', () async {
      final output = await _generate('''
/** Short block. */
@LlmTool()
void f() {}
''');
      expect(output, contains('description: "Short block."'));
    });
  });

  group('escaping', () {
    test(r'quotes and $ in descriptions are escaped', () async {
      final output = await _generate(r'''
/// Costs $5 and says "hi" with a \ backslash.
@LlmTool()
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
@LlmTool(description: 'Uses \${secret} literally.')
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
@LlmTool()
class NotAFunction {}
'''),
        contains('@LlmTool can only be used on top-level functions.'),
      );
    });

    test('@Tool on a top-level variable', () async {
      expect(
        await _buildErrors('''
/// Doc.
@LlmTool()
final notAFunction = 1;
'''),
        contains('@LlmTool can only be used on top-level functions.'),
      );
    });

    // source_gen skips files without any top-level annotation before our
    // generator runs, so these files also contain a top-level tool.
    for (final (kind, container) in [
      (
        'instance method',
        'class C {\n  /// Doc.\n  @LlmTool()\n  void m() {}\n}',
      ),
      (
        'static method',
        'class C {\n  /// Doc.\n  @LlmTool()\n  static void m() {}\n}',
      ),
      ('mixin method', 'mixin C {\n  /// Doc.\n  @LlmTool()\n  void m() {}\n}'),
      (
        'extension method',
        'extension C on int {\n  /// Doc.\n  @LlmTool()\n  void m() {}\n}',
      ),
    ]) {
      test('@Tool on a $kind is an error, not silently ignored', () async {
        expect(
          await _buildErrors('/// Doc.\n@LlmTool()\nvoid f() {}\n\n$container'),
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
          'class C {\n  /// Doc.\n  @LlmTool()\n  void m() {}\n}',
        );
        expect(result.succeeded, isTrue);
        expect(result.outputs, isEmpty);
      },
    );

    test('generic function', () async {
      expect(
        await _buildErrors('''
/// Doc.
@LlmTool()
T f<T>(T a) => a;
'''),
        contains("@LlmTool functions can't be generic."),
      );
    });

    test('missing description', () async {
      expect(
        await _buildErrors('''
@LlmTool()
void f() {}
'''),
        contains('Tool "f" needs a description.'),
      );
    });

    test('empty description argument', () async {
      expect(
        await _buildErrors('''
@LlmTool(description: '')
void f() {}
'''),
        contains('Tool "f" needs a description.'),
      );
    });

    test('empty doc comment', () async {
      expect(
        await _buildErrors('''
///
@LlmTool()
void f() {}
'''),
        contains('Tool "f" needs a description.'),
      );
    });

    for (final name in [
      'get weather',
      'get.weather',
      '',
      'a' * 64,
      '1_lookup',
      '-lookup',
    ]) {
      test('invalid custom name "$name"', () async {
        expect(
          await _buildErrors('''
/// Doc.
@LlmTool(name: '$name')
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
@LlmTool()
void get$weather() {}
'''),
        contains(r'Tool name "get$weather" is invalid.'),
      );
    });

    test(r'parameter name with \$ is rejected', () async {
      expect(
        await _buildErrors(r'''
/// Doc.
@LlmTool()
void f(String a$b) {}
'''),
        contains(r'Parameter "a$b" has a name some LLM providers reject'),
      );
    });

    test(r'class field name with \$ is rejected with its path', () async {
      expect(
        await _buildErrors(r'''
class P {
  P(this.$id);
  final int $id;
}

/// Doc.
@LlmTool()
void f(P p) {}
'''),
        contains(r'Field "p.$id" has a name some LLM providers reject'),
      );
    });

    test('names starting with _ are fine', () async {
      final output = await _generate('''
/// Doc.
@LlmTool(name: '_internal-lookup')
void f(String _key) {}
''');
      expect(output, contains('name: "_internal-lookup"'));
    });

    test('nullable list items explain how to fix it', () async {
      expect(
        await _buildErrors('''
/// Doc.
@LlmTool()
void f(List<String?> x) {}
'''),
        contains(
          'Parameter "x" has type List<String?>, but list items can\'t be '
          'nullable.',
        ),
      );
    });

    for (final type in [
      'List<dynamic>',
      'List<DateTime>',
      'List<List<Object>>',
      'Set<String>',
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
@LlmTool()
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

/// Source of the real llm_tool package, so `@Tool` resolves.
late Map<String, String> _runtimeSources;

Future<void> _loadRuntimeSources() async {
  final reader = await PackageAssetReader.currentIsolate();
  _runtimeSources = {};
  await for (final id in reader.findAssets(
    Glob('lib/**.dart'),
    package: 'llm_tool',
  )) {
    _runtimeSources['$id'] = await reader.readAsString(id);
  }
}

const _header = '''
import 'package:llm_tool/llm_tool.dart';

part 'tools.g.dart';

''';

Future<TestBuilderResult> _build(
  String source, {
  String path = 'lib/tools.dart',
  Map<String, String> extraSources = const {},
}) => testBuilder(
  toolBuilder(BuilderOptions.empty),
  {..._runtimeSources, ...extraSources, 'a|$path': source},
  rootPackage: 'a',
  generateFor: {'a|$path'},
  flattenOutput: true,
);

/// Runs the real builder on [tools] and returns the generated code.
///
/// Also checks that the generated code compiles, because text checks alone
/// can't catch a wrong cast or a type error.
///
/// [extraSources] are more files, e.g. `{'a|lib/units.dart': '...'}`, and
/// [header] replaces the default imports and `part` directive.
Future<String> _generate(
  String tools, {
  Map<String, String> extraSources = const {},
  String header = _header,
}) async {
  final source = '$header$tools';
  final result = await _build(source, extraSources: extraSources);
  expect(result.errors, isEmpty);
  expect(result.succeeded, isTrue);

  final output = result.readerWriter.testing.readString(
    AssetId('a', 'lib/tools.llm_tool.g.part'),
  );
  expect(
    await _compileErrors(source, output, extraSources),
    isEmpty,
    reason: output,
  );
  return output;
}

/// Runs the builder on [tools], expecting it to fail, and returns the errors.
Future<String> _buildErrors(String tools) async {
  final result = await _build('$_header$tools');
  expect(result.succeeded, isFalse);
  return result.errors.join('\n');
}

/// Analyzer errors and warnings for [source] combined with its [generated]
/// part. Generated code must not cause warnings in users' projects.
Future<List<String>> _compileErrors(
  String source,
  String generated,
  Map<String, String> extraSources,
) => resolveSources(
  {
    ..._runtimeSources,
    ...extraSources,
    'a|lib/tools.dart': source,
    'a|lib/tools.g.dart': "part of 'tools.dart';\n$generated",
  },
  (resolver) async {
    final library = await resolver.libraryFor(AssetId('a', 'lib/tools.dart'));
    final resolved =
        await library.session.getResolvedLibraryByElement(library)
            as ResolvedLibraryResult;
    return [
      for (final unit in resolved.units)
        for (final diagnostic in unit.diagnostics)
          if (diagnostic.severity != Severity.info) diagnostic.message,
    ];
  },
  rootPackage: 'a',
  resolverFor: 'a|lib/tools.dart',
);

/// [code] without whitespace and trailing commas, so checks don't depend on
/// how the formatter wrapped it.
String _withoutSpaces(String code) =>
    code.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r',(?=[}\])])'), '');
