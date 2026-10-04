import 'package:llm_tool_calling/llm_tool_calling.dart';

part 'tools.g.dart';

/// Every call that actually reached a tool function, in order. The checks
/// use it to prove the function ran, not just that Gemini answered.
final toolCalls = <({String tool, Map<String, Object?> args})>[];

enum Cabin { economy, business }

/// A person on the flight.
class Passenger {
  Passenger({required this.name, required this.age, this.bags = 1});

  /// Full name as on the passport.
  final String name;

  /// Age in years.
  final int age;

  /// Number of checked bags.
  final int bags;
}

/// Gets the current weather for a city.
@Tool()
String getWeather(@Param('City name, e.g. Kanpur') String city) {
  toolCalls.add((tool: 'getWeather', args: {'city': city}));
  return 'Sunny, 31°C in $city';
}

/// Books a flight for one or more passengers.
@Tool(requiresConfirmation: true)
String bookFlight(
  @Param('Departure airport code, e.g. DEL') String from,
  @Param('Arrival airport code, e.g. BOM') String to,
  @Param('Everyone flying') List<Passenger> passengers, {
  @Param('Cabin class') Cabin cabin = Cabin.economy,
}) {
  toolCalls.add((
    tool: 'bookFlight',
    args: {
      'from': from,
      'to': to,
      'cabin': cabin,
      'passengers': [
        for (final p in passengers) (name: p.name, age: p.age, bags: p.bags),
      ],
    },
  ));
  return 'Booked $from to $to in ${cabin.name} for '
      '${passengers.map((p) => p.name).join(' and ')}. Code LTC42.';
}

/// Deletes a file from the user's device.
@Tool(requiresConfirmation: true)
String deleteFile(@Param('Path of the file to delete') String path) {
  toolCalls.add((tool: 'deleteFile', args: {'path': path}));
  return 'Deleted $path';
}
