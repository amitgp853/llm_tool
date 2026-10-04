## 0.1.0

- Initial release.
- `chat.sendMessageWithTools(message, allTools)` runs the whole tool loop.
  Tested live with `gemini-3.8-flash`.
- `toolResponses(results)` sends tool results with the role `user`, because
  newer Gemini models reject the `function` role that firebase_ai's
  `Content.functionResponses` uses.
- `allTools.toFirebaseAiTool()` for firebase_ai's own automatic function
  calling (fails with newer models until firebase_ai releases
  flutterfire#18685; see the README).
- `toFunctionDeclarations()` and `respondTo(functionCall)` for manual
  function calling.
- Arguments are validated before anything runs; errors go back to Gemini.
- Tools with `requiresConfirmation` only run when a `confirm` callback
  approves them.
- Tools with duplicate names are refused with an `ArgumentError`, instead of
  firebase_ai silently keeping only one.
- Re-exports `ToolDefinition`, `ToolArgumentException` and the other runtime
  types, so a model-setup file only needs firebase_ai and this package.
- `toFirebaseJsonSchema()` converts llm_tool_calling JSON schemas to
  firebase_ai `JSONSchema`, sent as `parametersJsonSchema`.
