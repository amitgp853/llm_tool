import 'package:llm_tool/llm_tool.dart';

import 'models.dart' as models;

part 'tools.g.dart';

/// Gets the current weather for a city.
@LlmTool()
String getWeather(
  @Param('City name, e.g. Kanpur') String city, {
  @Param('Use Celsius instead of Fahrenheit') bool celsius = true,
}) => 'Sunny, ${celsius ? '31°C' : '88°F'} in $city';

enum TemperatureUnit { celsius, fahrenheit, kelvin }

/// Converts a temperature between units.
@LlmTool()
double convertTemperature(
  @Param('The temperature to convert') double value,
  @Param('Unit to convert from') TemperatureUnit from, {
  @Param('Unit to convert to') TemperatureUnit to = TemperatureUnit.celsius,
}) {
  final celsius = switch (from) {
    TemperatureUnit.celsius => value,
    TemperatureUnit.fahrenheit => (value - 32) * 5 / 9,
    TemperatureUnit.kelvin => value - 273.15,
  };
  return switch (to) {
    TemperatureUnit.celsius => celsius,
    TemperatureUnit.fahrenheit => celsius * 9 / 5 + 32,
    TemperatureUnit.kelvin => celsius + 273.15,
  };
}

/// Averages a list of temperatures, converting each to one unit first.
@LlmTool()
double averageTemperature(
  @Param('Readings to average') List<double> readings, {
  @Param('Unit of each reading, same order as readings')
  List<TemperatureUnit>? units,
}) {
  final celsius = [
    for (final (i, value) in readings.indexed)
      convertTemperature(value, units?[i] ?? TemperatureUnit.celsius),
  ];
  return celsius.reduce((a, b) => a + b) / celsius.length;
}

/// Books a flight and returns a confirmation summary.
@LlmTool(requiresConfirmation: true)
String bookFlight(models.Booking booking) {
  final names = booking.passengers.map((p) => '${p.name} (${p.bags} bags)');
  return '${booking.from}->${booking.to}, ${booking.cabin.name}: '
      '${names.join(', ')}';
}

/// Gets one move of a game by its number.
@LlmTool(name: 'get_move')
String getMove(
  @Param('A game id', name: 'game_id') int gameId,
  @Param('Move number', name: 'move_number') int moveNumber, {
  @Param('Include the evaluation', name: 'with_eval') bool withEval = false,
}) => 'game $gameId, move $moveNumber${withEval ? ' (+0.3)' : ''}';
