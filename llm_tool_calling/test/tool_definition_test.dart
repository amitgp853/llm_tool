import 'package:llm_tool_calling/llm_tool_calling.dart';
import 'package:test/test.dart';

void main() {
  final weatherTool = ToolDefinition(
    name: 'getWeather',
    description: 'Gets the weather for a city.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string'},
        'celsius': {'type': 'boolean'},
      },
      'required': ['city'],
    },
    execute: (args) {
      final celsius = args['celsius'] as bool? ?? true;
      return 'Sunny, ${celsius ? '31°C' : '88°F'} in ${args['city']}';
    },
  );

    group('validateArguments', () {
    final schema = weatherTool.parametersSchema;

    test('valid arguments return no errors', () {
      expect(validateArguments(schema, {'city': 'Kanpur'}), isEmpty);
    });

    test('valid optional argument returns no errors', () {
      expect(
        validateArguments(schema, {'city': 'Kanpur', 'celsius': false}),
        isEmpty,
      );
    });

    test('missing required argument is reported', () {
      expect(validateArguments(schema, {}), ['city is required']);
    });

    test('null required argument is reported', () {
      expect(validateArguments(schema, {'city': null}), ['city is required']);
    });

    test('wrong type is reported', () {
      expect(
        validateArguments(schema, {'city': 123}),
        ['city must be a string, got integer'],
      );
    });

    test('unknown argument is reported', () {
      expect(
        validateArguments(schema, {'city': 'Kanpur', 'colour': 'red'}),
        ['colour is not a known argument'],
      );
    });

    test('all errors are reported together', () {
      expect(
        validateArguments(schema, {'celsius': 'yes', 'colour': 'red'}),
        [
          'city is required',
          'celsius must be a boolean, got string',
          'colour is not a known argument',
        ],
      );
    });
  });

  group('ToolDefinition.call', () {
    test('runs the tool when arguments are valid', () async {
      expect(await weatherTool({'city': 'Kanpur'}), 'Sunny, 31°C in Kanpur');
    });

    test('uses the optional argument when given', () async {
      expect(
        await weatherTool({'city': 'Kanpur', 'celsius': false}),
        'Sunny, 88°F in Kanpur',
      );
    });

    test('throws ToolArgumentException for invalid arguments', () {
      expect(
        () => weatherTool({'city': 123}),
        throwsA(isA<ToolArgumentException>()),
      );
    });

    test('exception contains the tool name and errors', () async {
      try {
        await weatherTool({});
        fail('Expected ToolArgumentException');
      } on ToolArgumentException catch (e) {
        expect(e.toolName, 'getWeather');
        expect(e.errors, ['city is required']);
      }
    });

    test('does not run execute when arguments are invalid', () async {
      var ran = false;
      final tracked = ToolDefinition(
        name: 'tracked',
        description: 'Records whether it ran.',
        parametersSchema: weatherTool.parametersSchema,
        execute: (args) => ran = true,
      );

      await expectLater(() => tracked({}), throwsA(isA<ToolArgumentException>()));
      expect(ran, isFalse);
    });
  });
}