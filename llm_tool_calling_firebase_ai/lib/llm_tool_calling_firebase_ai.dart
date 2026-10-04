/// Use llm_tool_calling tools with Firebase AI Logic (`firebase_ai`).
///
/// ```dart
/// final model = FirebaseAI.googleAI().generativeModel(
///   model: 'gemini-2.5-flash',
///   tools: [allTools.toFirebaseAiTool()],
/// );
/// ```
library;

export 'src/extensions.dart';
export 'src/json_schema.dart' show toFirebaseJsonSchema;
