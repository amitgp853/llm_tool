## Unreleased

- Generates a list of all tools in each file, named after the file:
  `allTools` for `tools.dart`, `weatherTools` for `weather_tools.dart`.
  If you already declared a variable with that name in the file, rename it.

## 0.2.0

- Class parameters become nested object schemas, built through the class's
  unnamed constructor. Descriptions from `@Param` or field doc comments;
  defaults, nested classes, lists of classes, freezed classes and prefixed
  imports are supported.
- Generated code no longer causes analyzer warnings in your project.
- Tool names must start with a letter or `_`, and parameter names may only
  use letters, digits and `_`, so every schema works with Gemini as well as
  OpenAI and Claude. Other names are a build-time error.
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
