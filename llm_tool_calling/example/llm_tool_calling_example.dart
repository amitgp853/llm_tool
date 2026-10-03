import 'package:llm_tool_calling/llm_tool_calling.dart';

/// Gets the current weather for a city.
@Tool()
String getWeather(
  @Param('City name, e.g. Kanpur') String city, {
  @Param('Use Celsius instead of Fahrenheit') bool celsius = true,
}) {
  return 'Sunny, ${celsius ? '31°C' : '88°F'} in $city';
}

// What the generator will write for you later:
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
  },
  execute: (args) => getWeather(
    args['city'] as String,
    celsius: args['celsius'] as bool? ?? true,
  ),
);

void main() async {
  // Pretend the AI sent this:
  final aiArgs = {'city': 'Kanpur', 'colour': 'red'};
   try {
    print(await getWeatherTool(aiArgs));
  } on ToolArgumentException catch (e) {
    print(e);
  }
}