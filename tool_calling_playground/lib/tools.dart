import 'package:llm_tool_calling/llm_tool_calling.dart';

part 'tools.g.dart';

/// Gets the current weather for a city.
@Tool()
String getWeather(
  @Param('City name, e.g. Kanpur') String city, {
  @Param('Use Celsius instead of Fahrenheit')
  bool celsius = true,
}) =>
    'Sunny, ${celsius ? '31°C' : '88°F'} in $city';