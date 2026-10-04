## 0.7.0

- **Renamed from `llm_tool_calling_generator`** (now discontinued), to go
  with the core package's new name, `llm_tool`. The builder is now
  `llm_tool_generator:llm_tool`, and generated parts are `.llm_tool.g.part`.
- Recognizes `@LlmTool()`, and still the deprecated `@Tool()`.
- Generated tools are typed by their function's return type (e.g.
  `ToolDefinition<String>`), and the list of all tools by their common
  return type (e.g. `List<ToolDefinition<Command>>`), so calling a tool
  needs no cast.
- Requires `llm_tool_calling` 0.7.0.

## 0.6.1

- Added the package homepage (https://amitgp.dev).

## 0.6.0

- No changes in the generated code. Requires `llm_tool_calling` 0.6.0, which
  adds built-in SDK formats and `invoke`.

## 0.5.0

- Supports `@Param(name: ...)`: the schema, `required` and validation use the
  JSON name, while your function is still called with its Dart parameter
  names. Invalid or duplicate JSON names are build-time errors.

## 0.4.0

- The generated code uses your import prefix for `ToolDefinition`, so
  `import 'package:llm_tool_calling/llm_tool_calling.dart' as ltc;` works,
  and so does another package's `ToolDefinition` in the same file (e.g.
  `flutter_ai_core`).
- Tool names are limited to 63 characters, the firebase_ai limit.

## 0.3.0

- Generates a list of all tools in each file, named after the file:
  `allTools` for `tools.dart`, `weatherTools` for `weather_tools.dart`.
  If you already declared a variable with that name in the file, rename it.
- README: author section.

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
