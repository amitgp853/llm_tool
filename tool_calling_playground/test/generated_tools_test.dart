// Runs code produced by the real generator through build_runner.
// After changing lib/tools.dart, run `dart run build_runner build` first.
import 'dart:convert';

import 'package:llm_tool_calling/llm_tool_calling.dart';
import 'package:test/test.dart';
import 'package:tool_calling_playground/tools.dart';

void main() {
  group('getWeather', () {
    test('uses the default when an optional argument is missing', () async {
      expect(await getWeatherTool({'city': 'Kanpur'}), 'Sunny, 31°C in Kanpur');
    });

    test('rejects bad arguments before running', () {
      expect(
        () => getWeatherTool({'city': 42}),
        throwsA(isA<ToolArgumentException>()),
      );
    });
  });

  group('convertTemperature (enums)', () {
    test('schema lists the enum values', () {
      final properties =
          convertTemperatureTool.parametersSchema['properties'] as Map;
      expect((properties['from'] as Map)['enum'], [
        'celsius',
        'fahrenheit',
        'kelvin',
      ]);
    });

    test('converts names to enum values', () async {
      expect(
        await convertTemperatureTool({
          'value': 212,
          'from': 'fahrenheit',
          'to': 'kelvin',
        }),
        closeTo(373.15, 1e-9),
      );
    });

    test('a missing enum argument uses its default', () async {
      expect(
        await convertTemperatureTool({'value': 32, 'from': 'fahrenheit'}),
        0,
      );
    });

    test('an unknown enum value is rejected with the allowed values', () async {
      await expectLater(
        () => convertTemperatureTool({'value': 1, 'from': 'rankine'}),
        throwsA(
          isA<ToolArgumentException>().having(
            (e) => e.toString(),
            'message',
            'Invalid arguments for "convertTemperature": from must be one of '
                '"celsius", "fahrenheit", "kelvin", got "rankine"',
          ),
        ),
      );
    });
  });

  group('averageTemperature (lists)', () {
    Future<Object?> callWithJson(String json) =>
        averageTemperatureTool(jsonDecode(json) as Map<String, Object?>);

    test('converts JSON numbers, including ints, to List<double>', () async {
      expect(
        await callWithJson('{"readings": [20, 21.5, 22]}'),
        21.166666666666668,
      );
    });

    test('converts a list of enum names', () async {
      expect(
        await callWithJson(
          '{"readings": [32, 0], "units": ["fahrenheit", "celsius"]}',
        ),
        0,
      );
    });

    test('reports bad items with their index', () async {
      await expectLater(
        () =>
            callWithJson('{"readings": [1, "two"], "units": ["celsius", "x"]}'),
        throwsA(
          isA<ToolArgumentException>().having((e) => e.errors, 'errors', [
            'readings[1] must be a number, got string',
            'units[1] must be one of "celsius", "fahrenheit", "kelvin", got "x"',
          ]),
        ),
      );
    });
  });
}
