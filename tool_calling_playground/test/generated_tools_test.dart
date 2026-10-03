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

  group('bookFlight (classes)', () {
    Future<Object?> callWithJson(String json) =>
        bookFlightTool(jsonDecode(json) as Map<String, Object?>);

    test('builds nested objects and fills in defaults', () async {
      expect(
        await callWithJson('''
          {"booking": {
            "from": "DEL", "to": "BOM",
            "passengers": [
              {"name": "Asha", "age": 30},
              {"name": "Ravi", "age": 8, "bags": 0}
            ]
          }}'''),
        'DEL->BOM, economy: Asha (1 bags), Ravi (0 bags)',
      );
    });

    test('reports nested problems with full paths', () async {
      await expectLater(
        () => callWithJson('''
          {"booking": {
            "from": "DEL",
            "cabin": "first",
            "passengers": [{"name": "Asha", "age": "30", "seat": "4A"}]
          }}'''),
        throwsA(
          isA<ToolArgumentException>().having((e) => e.errors, 'errors', [
            // Required fields first, then the sent fields in JSON order.
            'booking.to is required',
            'booking.cabin must be one of "economy", "business", got "first"',
            'booking.passengers[0].age must be an integer, got string',
            'booking.passengers[0].seat is not a known field',
          ]),
        ),
      );
    });

    test('schema documents the fields for the LLM', () {
      final booking =
          (bookFlightTool.parametersSchema['properties'] as Map)['booking']
              as Map;
      expect(booking['description'], 'One flight booking request.');
      expect(booking['required'], ['from', 'to', 'passengers']);
      expect(bookFlightTool.requiresConfirmation, isTrue);
    });
  });

  group('allTools', () {
    test('lists every tool in the file, in source order', () {
      expect(allTools.map((tool) => tool.name), [
        'getWeather',
        'convertTemperature',
        'averageTemperature',
        'bookFlight',
      ]);
    });

    test('dispatch by the name the LLM sends', () async {
      final byName = {for (final tool in allTools) tool.name: tool};
      expect(
        await byName['getWeather']!({'city': 'Pune'}),
        'Sunny, 31°C in Pune',
      );
    });
  });
}
