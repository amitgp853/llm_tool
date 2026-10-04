/// Use llm_tool_calling tools with Firebase AI Logic (`firebase_ai`).
///
/// ```dart
/// final model = FirebaseAI.googleAI().generativeModel(
///   model: 'gemini-3.8-flash',
///   tools: [Tool.functionDeclarations(allTools.toFunctionDeclarations())],
/// );
/// final reply = await model.startChat().sendMessageWithTools(
///   Content.text('What is the weather in Kanpur?'),
///   allTools,
/// );
/// ```
library;

// So users need only this import and firebase_ai's. The @Tool and @Param
// annotations are left out: firebase_ai has its own `Tool` class.
export 'package:llm_tool_calling/llm_tool_calling.dart' hide Param, Tool;

export 'src/extensions.dart';
export 'src/json_schema.dart' show toFirebaseJsonSchema;
