// Using llm_tool_calling tools with Firebase AI Logic.
//
// In a real app, write the tools as @Tool() functions and let
// llm_tool_calling_generator create `allTools` for you (see the
// llm_tool_calling README). A hand-written tool is used here so the example
// runs without code generation.
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
// firebase_ai has its own Tool class, so hide the @Tool annotation here.
import 'package:llm_tool_calling/llm_tool_calling.dart' hide Tool;
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

  // Automatic function calling: the chat runs the tools for you.
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    tools: [allTools.toFirebaseAiTool(confirm: askUser)],
  );
  final chat = model.startChat();
  final response = await chat.sendMessage(
    Content.text('What is the weather in Kanpur?'),
  );
  print(response.text);

  // Manual function calling: you decide when to run each call.
  final manualModel = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    tools: [Tool.functionDeclarations(allTools.toFunctionDeclarations())],
  );
  final manualChat = manualModel.startChat();
  var reply = await manualChat.sendMessage(Content.text('Weather in Pune?'));
  while (reply.functionCalls.isNotEmpty) {
    final responses = [
      for (final call in reply.functionCalls)
        await allTools.respondTo(call, confirm: askUser),
    ];
    reply = await manualChat.sendMessage(Content.functionResponses(responses));
  }
  print(reply.text);
}
