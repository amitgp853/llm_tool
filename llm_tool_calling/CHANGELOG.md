## 0.1.0

- Initial release.
- `@Tool` and `@Param` annotations.
- `ToolDefinition` with name, description, JSON schema, `requiresConfirmation`
  and `call()`, which validates arguments before running the tool.
- `validateArguments()`: checks required, unknown and wrongly typed arguments
  and reports every problem at once. Whole numbers sent as `5.0` are accepted
  for `integer`.
- `ToolArgumentException` with a message an LLM can use to fix its call.
