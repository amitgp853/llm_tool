// 1. Add dependencies:
//      dart pub add llm_tool_calling
//      dart pub add dev:llm_tool_calling_generator dev:build_runner
// 2. Annotate functions with @Tool() and add the `part` directive.
// 3. Run: dart run build_runner build
//    This writes example.g.dart with a ToolDefinition per function, plus
//    `exampleTools`, a list of all of them (named after this file).
import 'dart:convert';

import 'package:llm_tool_calling/llm_tool_calling.dart';

part 'example.g.dart';

/// Gets the current weather for a city.
@Tool()
String getWeather(
  @Param('City name, e.g. Kanpur') String city, {
  @Param('Use Celsius instead of Fahrenheit') bool celsius = true,
}) => 'Sunny, ${celsius ? '31°C' : '88°F'} in $city';

/// Converts an amount between two currencies.
@Tool(name: 'convert_currency')
Future<double> convertCurrency(
  @Param('Amount to convert') double amount,
  @Param('ISO code to convert from, e.g. USD') String from,
  @Param('ISO code to convert to, e.g. INR') String to,
) async => amount * 83.2; // A real tool would call an exchange-rate API.

/// Deletes a file from the user's device.
@Tool(requiresConfirmation: true)
void deleteFile(@Param('Path of the file to delete') String path) {}

Future<void> main() async {
  // Send the schemas to your LLM provider.
  for (final tool in exampleTools) {
    print('${tool.name}: ${jsonEncode(tool.parametersSchema)}');
  }

  // The LLM asks to call a tool. Find it by name and run it.
  final toolsByName = {for (final tool in exampleTools) tool.name: tool};
  final tool = toolsByName['convert_currency']!;
  final args = jsonDecode('{"amount": 10, "from": "USD", "to": "INR"}');

  if (tool.requiresConfirmation) {
    print('Ask the user before running ${tool.name}.');
  }
  try {
    print(await tool(args as Map<String, Object?>)); // 832.0
  } on ToolArgumentException catch (e) {
    print(e); // Send this back to the LLM so it can fix the call.
  }
}
