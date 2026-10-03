# llm_tool_calling

**Turn any Dart function into an LLM tool with one annotation. No hand-written JSON schemas.**

Annotate a function with `@Tool()`, run `build_runner`, and get a ready-to-use
`ToolDefinition` with:

- the **JSON Schema** to send to your LLM (OpenAI, Anthropic, Gemini, local models…),
- **argument validation** that reports every problem in a message the LLM can fix,
- **type-safe dispatch** to your function, sync or async.

Works in Dart and Flutter, with any LLM SDK or plain HTTP.

## Quick start (60 seconds)

**1. Install**

```sh
dart pub add llm_tool_calling dev:llm_tool_calling_generator dev:build_runner
```

(In a Flutter app, use `flutter pub add` with the same arguments.)

**2. Write a tool** in, for example, `lib/tools.dart`:

```dart
import 'package:llm_tool_calling/llm_tool_calling.dart';

part 'tools.g.dart';

/// Gets the current weather for a city.
@Tool()
String getWeather(
  @Param('City name, e.g. Kanpur') String city, {
  @Param('Use Celsius instead of Fahrenheit') bool celsius = true,
}) => 'Sunny, ${celsius ? '31°C' : '88°F'} in $city';
```

**3. Generate**

```sh
dart run build_runner build
```

This creates `lib/tools.g.dart` containing `getWeatherTool`.

**4. Use it**

```dart
// Send the tool to your LLM:
getWeatherTool.name;             // 'getWeather'
getWeatherTool.description;      // 'Gets the current weather for a city.'
getWeatherTool.parametersSchema; // JSON Schema map

// When the LLM calls it, pass the decoded JSON arguments:
final result = await getWeatherTool({'city': 'Kanpur'});
// 'Sunny, 31°C in Kanpur'
```

## Before and after

**Before:** you write and maintain the schema and the dispatch code by hand,
and keep them in sync with the function forever.

```dart
String getWeather(String city, {bool celsius = true}) => '...';

final getWeatherTool = ToolDefinition(
  name: 'getWeather',
  description: 'Gets the current weather for a city.',
  parametersSchema: {
    'type': 'object',
    'properties': {
      'city': {'type': 'string', 'description': 'City name, e.g. Kanpur'},
      'celsius': {
        'type': 'boolean',
        'description': 'Use Celsius instead of Fahrenheit',
      },
    },
    'required': ['city'],
    'additionalProperties': false,
  },
  execute: (args) => getWeather(
    args['city'] as String,
    celsius: args['celsius'] as bool? ?? true,
  ),
);
```

**After:** the function is the single source of truth.

```dart
/// Gets the current weather for a city.
@Tool()
String getWeather(
  @Param('City name, e.g. Kanpur') String city, {
  @Param('Use Celsius instead of Fahrenheit') bool celsius = true,
}) => '...';
```

Rename a parameter, add one, or change a default, and the schema and
dispatch code follow on the next build.

## Sending tools to your LLM

`ToolDefinition` is provider-neutral. Map it to the shape your provider
expects, for example:

```dart
// OpenAI Chat Completions
{
  'type': 'function',
  'function': {
    'name': tool.name,
    'description': tool.description,
    'parameters': tool.parametersSchema,
  },
}

// Anthropic Messages
{
  'name': tool.name,
  'description': tool.description,
  'input_schema': tool.parametersSchema,
}
```

When the model replies with a tool call, look the tool up by name and call
it with the decoded arguments:

```dart
final tools = {for (final t in [getWeatherTool, searchTool]) t.name: t};

final tool = tools[toolCall.name]!;
try {
  final result = await tool(jsonDecode(toolCall.arguments));
  // Send `result` back to the model as the tool result.
} on ToolArgumentException catch (e) {
  // Send `e.toString()` back as the tool result; the model can fix its call.
}
```

Ready-made adapters for popular SDKs are on the [roadmap](#roadmap).

## Annotations

| | |
|---|---|
| `@Tool()` | Marks a **top-level function** as a tool. |
| `@Tool(name: 'get_weather')` | Name sent to the LLM. Defaults to the function name. Must be 1–64 letters, digits, `_` or `-`. |
| `@Tool(description: '...')` | Description sent to the LLM. Defaults to the function's doc comment (`///` or `/** */`). One of the two is required. |
| `@Tool(requiresConfirmation: true)` | Sets `ToolDefinition.requiresConfirmation`, so your app can ask the user before running it (e.g. for deleting or paying). |
| `@Param('...')` | Description of one parameter. Optional, but it helps the LLM a lot. |

The generated variable is always `<functionName>Tool`, e.g. `getWeatherTool`,
even when you set a custom `name`.

## Supported types

| Dart type | JSON Schema | Notes |
|---|---|---|
| `String` | `"string"` | |
| `int` | `"integer"` | `5.0` is accepted and converted to `5`. |
| `double` | `"number"` | `5` is accepted and converted to `5.0`. |
| `num` | `"number"` | |
| `bool` | `"boolean"` | |

Parameters can be positional or named, and any of them can be nullable or
have a default value:

| Parameter | Required in schema? |
|---|---|
| `String city` / `{required String city}` | Yes |
| `String? city` / `{String? city}` / `{required String? city}` | No (missing means `null`) |
| `{String unit = 'metric'}` / `[int count = 3]` | No (missing means the default) |

Functions can return anything, including `Future<T>` and `void` (`void`
tools return `null`).

`List`, enums and custom classes are not supported yet; see the
[roadmap](#roadmap). Using them is a build-time error, not a silent bug.

## Validation and errors

`tool(args)` (that is, `ToolDefinition.call`) validates the arguments
**before** running your function. It reports **every** problem at once:

| Problem | Message |
|---|---|
| Required argument missing or `null` | `city is required` |
| Argument not in the schema | `colour is not a known argument` |
| Wrong JSON type | `city must be a string, got integer` |

If anything is wrong, your function does not run and a
`ToolArgumentException` is thrown. Its `toString()` is written for the LLM:

```
Invalid arguments for "getWeather": city is required; colour is not a known argument
```

Send it back as the tool result and most models will correct the call on
their next turn. You can also read `e.toolName` and `e.errors` directly.

Good to know:

- Exceptions thrown **by your function** are not caught. Handle them in your
  function or around the call.
- `execute(args)` runs the function **without** validation. Prefer
  `tool(args)`.
- Generated schemas include `"additionalProperties": false`, matching the
  "unknown argument" check.
- `requiresConfirmation` is only a flag. Your app decides how to ask.
- `validateArguments(schema, args)` is public if you want to validate
  hand-written schemas yourself.

## Troubleshooting

**`Undefined name 'getWeatherTool'`**
- Add `part 'your_file.g.dart';` to the file with your tools.
- Run `dart run build_runner build`, or `dart run build_runner watch` to
  rebuild on every save.
- `@Tool` only works on **top-level** functions. On a class method it is an
  error, but in a file that has no other top-level annotation it is skipped
  without a message. Move the method out of the class.

**`The function 'ToolDefinition' isn't defined` in the `.g.dart` file**
- Import `package:llm_tool_calling/llm_tool_calling.dart` **without** a
  prefix (no `as ...`). The generated code uses unprefixed names.

**`Could not resolve annotation for ...`**
- The file uses `@Tool` without importing
  `package:llm_tool_calling/llm_tool_calling.dart`.

**`Tool "x" needs a description`**
- Add a `///` doc comment above the function, or use
  `@Tool(description: '...')`. The LLM relies on it to decide when to call
  your tool.

**`Tool name "..." is invalid`**
- Providers only accept 1–64 letters, digits, `_` and `-`. Use
  `@Tool(name: 'valid_name')`. This also applies to function names that
  contain `$`.

**`Parameter "x" has type ..., which is not supported yet`**
- Use `String`, `int`, `double`, `num` or `bool`; see
  [Supported types](#supported-types).

**`Conflicting outputs were detected`**
- Run `dart run build_runner build --delete-conflicting-outputs`.

**Using `json_serializable` or `freezed` in the same file?** That's fine.
All of them write into the same shared `.g.dart` part.

## Roadmap

- `List`, enum and custom class parameters (nested object schemas).
- A generated list of all tools in a file, e.g. `allTools`.
- Ready-made tool objects and schemas for popular SDKs such as `llm_sdk`,
  `flutter_ai_tools` and `firebase_ai`.
- `llm_tool_calling_flutter`: an approval widget for
  `requiresConfirmation` tools.

Ideas and bug reports are welcome on
[GitHub](https://github.com/amitgp853/llm_tool_calling/issues).

## Packages

| Package | Purpose | Add as |
|---|---|---|
| [`llm_tool_calling`](https://pub.dev/packages/llm_tool_calling) | Annotations, `ToolDefinition`, validation | dependency |
| [`llm_tool_calling_generator`](https://pub.dev/packages/llm_tool_calling_generator) | The `build_runner` code generator | dev dependency |
