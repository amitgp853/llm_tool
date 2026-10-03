# llm_tool_calling_generator

**The code generator for [`llm_tool_calling`](https://pub.dev/packages/llm_tool_calling):
turn any Dart function into an LLM tool with one annotation. No hand-written JSON schemas.**

For every `@Tool()` function it generates a `ToolDefinition` with the JSON
Schema for the LLM, argument validation and type-safe dispatch.

The full documentation, including supported types, validation and errors, and
how to send tools to OpenAI or Anthropic, is in the
[`llm_tool_calling` README](https://pub.dev/packages/llm_tool_calling).

## Quick start

**1. Install**

```sh
dart pub add llm_tool_calling dev:llm_tool_calling_generator dev:build_runner
```

**2. Write a tool**

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
```

## Supported

- Top-level functions: sync, async (`Future<T>`) and `void`.
- `String`, `int`, `double`, `num`, `bool`, enum and `List` parameters
  (lists of any of these, including nested lists): positional or
  named, nullable or not, with or without defaults.
- Descriptions from `@Tool(description: ...)` or the doc comment.

Anything else is a **build-time error** with a message explaining the fix:
unsupported types, missing descriptions, tool names that LLM providers would
reject, generic functions, and `@Tool` on methods.

## Troubleshooting

**`Undefined name 'getWeatherTool'`**: add `part 'your_file.g.dart';` and run
`dart run build_runner build`. `@Tool` only works on top-level functions; in a
file with no other top-level annotation, a `@Tool` method is skipped without a
message.

**`The function 'ToolDefinition' isn't defined` in the `.g.dart` file**: import
`package:llm_tool_calling/llm_tool_calling.dart` without a prefix.

**`Conflicting outputs were detected`**: run
`dart run build_runner build --delete-conflicting-outputs`.

More in the
[full troubleshooting guide](https://pub.dev/packages/llm_tool_calling#troubleshooting).
