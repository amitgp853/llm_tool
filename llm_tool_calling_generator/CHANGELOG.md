## Unreleased

- `List<T>` parameters for every supported `T`, including enums and nested
  lists. `List<int>` and `List<double>` accept any JSON number.
- Enum parameters, sent to the LLM as their value names. Works with
  nullable enums, defaults, enhanced enums and prefixed imports
  (`import 'units.dart' as u;`).

## 0.1.0

- Initial release.
- Generates a `<functionName>Tool` `ToolDefinition` for every `@Tool`
  top-level function.
- Parameter types: `String`, `int`, `double`, `num`, `bool`, nullable or not,
  positional or named, with or without defaults.
- Description from `@Tool(description:)` or the doc comment (`///` or `/** */`).
- Sync, async and `void` functions.
- Build-time errors for unsupported types, missing descriptions, invalid tool
  names, generic functions and `@Tool` on methods.
