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
// out (put @LlmTool functions in their own file); the deprecated `Tool` alias
// would clash with firebase_ai's `Tool` class.
export 'package:llm_tool/llm_tool.dart' hide LlmTool, Param, Tool;

export 'src/extensions.dart';
export 'src/json_schema.dart' show toFirebaseJsonSchema;
