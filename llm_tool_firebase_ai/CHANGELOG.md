## 0.4.0

- Sends `@Param` limits from `llm_tool` 0.8.0: `minimum`, `maximum`,
  `minItems` and `maxItems` as firebase_ai schema fields. firebase_ai has
  no fields for `minLength`, `maxLength` and `pattern`, so they are added
  to the parameter's description, e.g. "Airport code (exactly 3
  characters, matching ^[A-Z]{3}$)". `call()` and `invoke()` check them
  all.
- The re-export of `llm_tool` also leaves out the new `LlmToolset`
  annotation.
- Requires `llm_tool` 0.8.0.

## 0.3.0

- **Renamed from `llm_tool_calling_firebase_ai`** (now discontinued), to go
  with the core package's new name, `llm_tool`. Import
  `package:llm_tool_firebase_ai/llm_tool_firebase_ai.dart`.
- `toFirebaseAITool()` replaces `toFirebaseAiTool()` (Dart style for
  two-letter acronyms); the old name is deprecated until 1.0.0. The
  extensions are now `ToolDefinitionFirebaseAI` and `ToolListFirebaseAI`.
- The re-export of `llm_tool_calling` leaves out the annotations
  (`LlmTool`, `Param` and the deprecated `Tool`).
- Requires `llm_tool_calling` 0.7.0.

## 0.2.0

- Uses `ToolDefinition.invoke` from `llm_tool_calling` 0.6.0, so tools behave
  the same with every SDK. `ToolConfirmation` now comes from
  `llm_tool_calling` (still available through this package).
- If a tool throws during firebase_ai's automatic function calling, Gemini
  now gets a clear `error`.
- Requires `llm_tool_calling` 0.6.0.

## 0.1.1

- Works with `llm_tool_calling` 0.5.x (and still 0.3.x and 0.4.x).
- Clearer package description: the adapter runs the whole tool loop.

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
