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
