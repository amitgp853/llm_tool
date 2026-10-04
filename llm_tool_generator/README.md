# llm_tool_generator

**The code generator for [`llm_tool`](https://pub.dev/packages/llm_tool):
turn any Dart function into an LLM tool with one annotation. No hand-written JSON schemas.**

For every `@LlmTool()` function it generates a `ToolDefinition` with the JSON
Schema for the LLM, argument validation and type-safe dispatch.

The full documentation, including supported types, validation and errors, and
how to send tools to OpenAI, Anthropic or Gemini, is in the
[`llm_tool` README](https://pub.dev/packages/llm_tool).

## Quick start

**1. Install**

```sh
dart pub add llm_tool dev:llm_tool_generator dev:build_runner
```

**2. Write a tool**

```dart
import 'package:llm_tool/llm_tool.dart';

part 'tools.g.dart';

/// Gets the current weather for a city.
@LlmTool()
String getWeather(
  @Param('City name, e.g. Kanpur') String city, {
  @Param('Use Celsius instead of Fahrenheit') bool celsius = true,
}) => 'Sunny, ${celsius ? '31°C' : '88°F'} in $city';
```

**3. Generate**

```sh
dart run build_runner build
```

**4. Use the generated `getWeatherTool`**

```dart
print(getWeatherTool.parametersSchema); // send to your LLM
print(await getWeatherTool({'city': 'Kanpur'})); // Sunny, 31°C in Kanpur
```

## What gets generated

```dart
final getWeatherTool = ToolDefinition(
  name: "getWeather",
  description: "Gets the current weather for a city.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "city": {"type": "string", "description": "City name, e.g. Kanpur"},
      "celsius": {
        "type": "boolean",
        "description": "Use Celsius instead of Fahrenheit",
      },
    },
    "required": ["city"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => getWeather(
    args["city"] as String,
    celsius: args["celsius"] as bool? ?? true,
  ),
);

/// Every tool in this file, e.g. to send to an LLM or look up by name.
final List<ToolDefinition> allTools = [getWeatherTool];
```

The list is named after the file: `tools.dart` gives `allTools`,
`weather_tools.dart` gives `weatherTools`.

## Supported

- Top-level functions: sync, async (`Future<T>`) and `void`.
- `String`, `int`, `double`, `num`, `bool`, enum, class and `List`
  parameters (lists of any of these, including nested lists): positional or
  named, nullable or not, with or without defaults.
- Descriptions from `@LlmTool(description: ...)` or the doc comment.
- Custom JSON names with `@Param('...', name: 'game_id')`, so your Dart
  code keeps camelCase while the LLM sees snake case.

- Class parameters become nested object schemas, built through the class's
  unnamed constructor. freezed classes work too. See
  [Class parameters](https://pub.dev/packages/llm_tool#class-parameters).

Anything else is a **build-time error** with a message explaining the fix:
unsupported types, missing descriptions, tool names that LLM providers would
reject, generic functions, and `@LlmTool` on methods.

## Troubleshooting

**`Undefined name 'getWeatherTool'`**: add `part 'your_file.g.dart';` and run
`dart run build_runner build`. `@LlmTool` only works on top-level functions; in a
file with no other top-level annotation, a `@LlmTool` method is skipped without a
message.

**`The name 'ToolDefinition' is defined in the libraries ...`**: another
package (e.g. `flutter_ai_core`) also has a `ToolDefinition`. Import
`llm_tool` with a prefix (`as ltc`) and use `@ltc.Tool()`; the
generated code follows your prefix.

**`Conflicting outputs were detected`**: run
`dart run build_runner build --delete-conflicting-outputs`.

More in the
[full troubleshooting guide](https://pub.dev/packages/llm_tool#troubleshooting).

## Author

Built and maintained by [Amit Gupta](https://github.com/amitgp853).
Bug reports, ideas and pull requests are welcome on
[GitHub](https://github.com/amitgp853/llm_tool/issues).
If this package saves you time, a like on pub.dev or a star on GitHub helps
others find it.
