## 0.8.0

- **Toolsets: tools as class methods.** Mark a class with `@LlmToolset()`
  and its `@LlmTool` methods become tools that can use the instance's
  fields, e.g. a repository or an API client. The generator adds an
  `llmTools` getter: `CoachTools(engine, games).llmTools`. Static methods
  work too.
- **Limits on parameters.** `@Param` takes `min`, `max`, `minLength`,
  `maxLength`, `pattern`, `minItems` and `maxItems`. They go into the JSON
  Schema, and `call()` and `invoke()` reject arguments outside them with a
  message for the LLM, e.g. `age must be at most 130, got 131`.
- `validateArguments` checks `minimum`, `maximum`, `minLength`,
  `maxLength`, `pattern`, `minItems` and `maxItems` in any schema.

## 0.7.0

**Renamed from `llm_tool_calling`.** This package continues
`llm_tool_calling` (now discontinued) under a shorter name that matches the
`@LlmTool` annotation. The generator is now `llm_tool_generator` and the
Firebase adapter `llm_tool_firebase_ai`. To switch, update `pubspec.yaml`
and replace `package:llm_tool_calling/llm_tool_calling.dart` with
`package:llm_tool/llm_tool.dart`. If your `build.yaml` configures the
builder, it's now `llm_tool_generator:llm_tool`.

Preparing the 1.0 API. Nothing else breaks: old names still work and are
marked deprecated until 1.0.0.

- `@LlmTool()` replaces `@Tool()`. Almost every AI SDK (firebase_ai,
  openai_dart, anthropic_sdk_dart, mcp_dart) has its own `Tool` class, which
  clashed in files that import both. `@Tool()` is a deprecated alias.
- `toOpenAIJson()` and `toOpenAIResponsesJson()` replace `toOpenAiJson()`
  and `toOpenAiResponsesJson()` (Dart style for two-letter acronyms, like
  `OpenAIClient`). The old names are deprecated aliases.
- `ToolDefinition<T>` is typed by the tool's return type: `call` returns
  `Future<T>`, so results need no cast. Hand-written tools get `T` inferred.

To upgrade from `llm_tool_calling`: switch the package names (above), then
replace `@Tool(` with `@LlmTool(` and `toOpenAi` with `toOpenAI`; your IDE
shows each remaining place as a deprecation hint.

## 0.6.2

- README: every "Use with your SDK" example now imports
  `package:llm_tool_calling/llm_tool_calling.dart`. `toOpenAiJson()`,
  `invoke()` and the other list methods are extension methods, so a file
  that only imports your `tools.dart` can't see them. Added a
  troubleshooting entry for the resulting error. No code changes.

## 0.6.1

- Added the package homepage (https://amitgp.dev).

## 0.6.0

- Built-in support for every major SDK, with no extra packages:
  `toOpenAiJson()`, `toOpenAiResponsesJson()`, `toAnthropicJson()`,
  `toGeminiJson()` and `toMcpJson()` on a tool or a list of tools (e.g.
  `allTools`). Each format is tested against the real SDK
  (`openai_dart`, `anthropic_sdk_dart`, `mcp_dart`).
- `tool.invoke(args, confirm: ...)` and `allTools.invoke(name, arguments)` run
  a model's call and never throw: validation, confirmation for
  `requiresConfirmation` tools, the run, and a JSON-safe `ToolResult`
  (`toText()`, `toJson()`, `isError`). Arguments can be a map or a JSON
  string.
- `ToolConfirmation`, the callback that asks the user.
- README: "Use with your SDK" with OpenAI, Claude, MCP and Firebase examples
  (compiled and run in the tests).

## 0.5.0

- `@Param(name: ...)` sets the name the LLM sees and sends, e.g.
  `@Param('A game id', name: 'game_id') int gameId`.

## 0.4.0

- `withoutAdditionalProperties(schema)`: a copy of a schema for SDKs that
  send it to Gemini's older `parameters` field, which rejects
  `additionalProperties`.
- Tool names are documented as up to 63 characters (the firebase_ai limit).
- README: "Use with your SDK" section, with the new
  [`llm_tool_calling_firebase_ai`](https://pub.dev/packages/llm_tool_calling_firebase_ai)
  adapter.

## 0.3.0

- No code changes. Released together with `llm_tool_calling_generator`
  0.3.0, which generates a list of all tools in each file.
- README: the list of all tools, and an author section.

## 0.2.0

- `validateArguments()` checks nested objects (fields with `properties`),
  reporting paths like `booking.passengers[0].age is required`.
- `validateArguments()` checks every item of an `array` against `items`,
  reporting paths like `tags[2]` and `grid[1][0]`.
- `validateArguments()` checks `enum` lists and reports the allowed values,
  e.g. `unit must be one of "celsius", "fahrenheit", got "kelvin"`.

## 0.1.0

- Initial release.
- `@Tool` and `@Param` annotations.
- `ToolDefinition` with name, description, JSON schema, `requiresConfirmation`
  and `call()`, which validates arguments before running the tool.
- `validateArguments()`: checks required, unknown and wrongly typed arguments
  and reports every problem at once. Whole numbers sent as `5.0` are accepted
  for `integer`.
- `ToolArgumentException` with a message an LLM can use to fix its call.
