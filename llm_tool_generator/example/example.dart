// 1. Add dependencies:
//      dart pub add llm_tool
//      dart pub add dev:llm_tool_generator dev:build_runner
// 2. Annotate functions with @LlmTool() and add the `part` directive.
// 3. Run: dart run build_runner build
//    This writes example.g.dart with a ToolDefinition per function,
//    `exampleTools` (all of them, named after this file), and an `llmTools`
//    getter for the @LlmToolset class.
import 'package:llm_tool/llm_tool.dart';

part 'example.g.dart';

/// Gets the current weather for a city.
@LlmTool()
String getWeather(
  @Param('City name, e.g. Kanpur') String city, {
  @Param('Use Celsius instead of Fahrenheit') bool celsius = true,
}) => 'Sunny, ${celsius ? '31°C' : '88°F'} in $city';

/// Converts an amount between two currencies.
@LlmTool(name: 'convert_currency')
Future<double> convertCurrency(
  // Limits go into the schema and are checked before the function runs.
  @Param('Amount to convert', min: 0) double amount,
  @Param('ISO code to convert from, e.g. USD', pattern: r'^[A-Z]{3}$')
  String from,
  @Param('ISO code to convert to, e.g. INR', pattern: r'^[A-Z]{3}$') String to,
) async => amount * 83.2; // A real tool would call an exchange-rate API.

/// Tools that need something from your app, here a list of notes.
@LlmToolset()
class NoteTools {
  NoteTools(this.notes);

  final List<String> notes;

  /// Saves a note for the user.
  @LlmTool(name: 'add_note')
  String addNote(@Param('The note', minLength: 1, maxLength: 200) String text) {
    notes.add(text);
    return 'Saved. ${notes.length} notes.';
  }

  /// Deletes all of the user's notes.
  @LlmTool(name: 'clear_notes', requiresConfirmation: true)
  void clearNotes() => notes.clear();
}

Future<void> main() async {
  final tools = [...exampleTools, ...NoteTools([]).llmTools];

  // Send the tools to your LLM: toOpenAIJson(), toAnthropicJson(),
  // toGeminiJson() or toMcpJson() give the JSON each provider expects.
  final forOpenAI = tools.toOpenAIJson();
  print('${forOpenAI.length} tools: ${tools.map((t) => t.name).join(', ')}');
  // 4 tools: getWeather, convert_currency, add_note, clear_notes

  // The LLM calls a tool: run it with invoke, and send the result back.
  final result = await tools.invoke(
    'convert_currency',
    '{"amount": 10, "from": "USD", "to": "INR"}', // OpenAI sends a string
  );
  print(result.toText()); // 832.0

  // Wrong arguments never reach your function. The error is written for
  // the model, so it can fix its call.
  final wrong = await tools.invoke('convert_currency', {
    'amount': -5,
    'from': 'dollars',
    'to': 'INR',
  });
  print(wrong.toText());
  // Invalid arguments for "convert_currency": amount must be at least 0,
  // got -5; from must match the pattern ^[A-Z]{3}$, got "dollars"

  // Tools marked requiresConfirmation only run when `confirm` says yes.
  final cleared = await tools.invoke(
    'clear_notes',
    null,
    confirm: (tool, args) => true, // e.g. show a dialog
  );
  print(cleared.isError); // false
}
