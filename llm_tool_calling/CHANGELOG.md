## Unreleased

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
