// Using llm_tool_calling without the generator: a hand-written
// ToolDefinition. With llm_tool_calling_generator, you write only the
// annotated function and this definition is generated for you.
import 'dart:convert';

import 'package:llm_tool_calling/llm_tool_calling.dart';

String getWeather(String city, {bool celsius = true}) =>
    'Sunny, ${celsius ? '31°C' : '88°F'} in $city';

final getWeatherTool = ToolDefinition(
  name: 'getWeather',
  description: 'Gets the current weather for a city.',
  parametersSchema: {
    'type': 'object',
    'properties': {
      'city': {'type': 'string', 'description': 'City name, e.g. Kanpur'},
      'celsius': {
        'type': 'boolean',
        'description': 'Use Celsius instead of Fahrenheit',
      },
    },
    'required': ['city'],
    'additionalProperties': false,
  },
  execute: (args) => getWeather(
    args['city'] as String,
    celsius: args['celsius'] as bool? ?? true,
  ),
);

Future<void> main() async {
  // 1. Send the tool to your LLM provider (shape varies by provider).
  print(
    jsonEncode({
      'name': getWeatherTool.name,
      'description': getWeatherTool.description,
      'parameters': getWeatherTool.parametersSchema,
    }),
  );

  // 2. The LLM replies with a tool call; its arguments arrive as JSON.
  for (final argumentsJson in [
    '{"city": "Kanpur"}',
    '{"city": 42, "colour": "red"}',
  ]) {
    final args = jsonDecode(argumentsJson) as Map<String, Object?>;

    // 3. Run it. On bad arguments, send the error back as the tool result
    //    so the model can fix its call.
    try {
      print(await getWeatherTool(args));
    } on ToolArgumentException catch (e) {
      print(e);
      // Invalid arguments for "getWeather": city must be a string, got
      // integer; colour is not a known argument
    }
  }
}
