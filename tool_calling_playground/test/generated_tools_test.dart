// Runs code produced by the real generator through build_runner.
// After changing lib/tools.dart, run `dart run build_runner build` first.
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
}
