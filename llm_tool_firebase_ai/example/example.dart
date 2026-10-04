// Using llm_tool_calling tools with Firebase AI Logic.
//
// In a real app, write the tools as @Tool() functions and let
// llm_tool_calling_generator create `allTools` for you (see the
// llm_tool_calling README). A hand-written tool is used here so the example
// runs without code generation.
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:llm_tool_calling_firebase_ai/llm_tool_calling_firebase_ai.dart';

final allTools = [
  ToolDefinition(
    name: 'getWeather',
    description: 'Gets the current weather for a city.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string', 'description': 'City name, e.g. Kanpur'},
      },
      'required': ['city'],
      'additionalProperties': false,
    },
    execute: (args) => 'Sunny, 31°C in ${args['city']}',
  ),
  ToolDefinition(
    name: 'deleteFile',
    description: 'Deletes a file from the device.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'path': {'type': 'string'},
      },
      'required': ['path'],
      'additionalProperties': false,
    },
    requiresConfirmation: true,
    execute: (args) => 'Deleted ${args['path']}',
  ),
];

/// Ask the user before running tools marked requiresConfirmation. In a
/// Flutter app, show a dialog here.
Future<bool> askUser(ToolDefinition tool, Map<String, Object?> args) async =>
    false;

Future<void> main() async {
  await Firebase.initializeApp(); // with your firebase_options.dart

  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.8-flash',
    tools: [Tool.functionDeclarations(allTools.toFunctionDeclarations())],
  );
  final chat = model.startChat();

  // Runs every tool Gemini asks for, then returns Gemini's answer.
  final reply = await chat.sendMessageWithTools(
    Content.text('What is the weather in Kanpur?'),
    allTools,
    confirm: askUser,
  );
  print(reply.text);

  // The same loop written by hand, e.g. to show progress between steps.
  var manual = await chat.sendMessage(Content.text('And in Pune?'));
  while (manual.functionCalls.isNotEmpty) {
    final results = [
      for (final call in manual.functionCalls)
        await allTools.respondTo(call, confirm: askUser),
    ];
    // toolResponses, not Content.functionResponses: newer models reject
    // firebase_ai's `function` role.
    manual = await chat.sendMessage(toolResponses(results));
  }
  print(manual.text);
}
