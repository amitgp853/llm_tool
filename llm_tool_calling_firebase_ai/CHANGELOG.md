## 0.1.0

- Initial release.
- `allTools.toFirebaseAiTool()` for automatic function calling in a
  firebase_ai `ChatSession`.
- `toFunctionDeclarations()` and `respondTo(functionCall)` for manual
  function calling.
- Arguments are validated before anything runs; errors go back to Gemini.
- Tools with `requiresConfirmation` only run when a `confirm` callback
  approves them.
- `toFirebaseJsonSchema()` converts llm_tool_calling JSON schemas to
  firebase_ai `JSONSchema`, sent as `parametersJsonSchema`.
