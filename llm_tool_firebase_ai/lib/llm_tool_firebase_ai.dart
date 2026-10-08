/// Use llm_tool with Firebase AI Logic (`firebase_ai`).
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

// So users need only this import and firebase_ai's. The annotations are left
// out: they belong in the file with your @LlmTool functions.
export 'package:llm_tool/llm_tool.dart' hide LlmTool, LlmToolset, Param;

export 'src/extensions.dart';
export 'src/json_schema.dart' show toFirebaseJsonSchema;
