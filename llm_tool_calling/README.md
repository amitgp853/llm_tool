# llm_tool_calling

**Turn any Dart function into an LLM tool with one annotation. Works with
OpenAI, Claude, Gemini and MCP. No hand-written JSON schemas.**

```dart
/// Gets the current weather for a city.
@Tool()
String getWeather(@Param('City name, e.g. Kanpur') String city) => '...';
```

Run `build_runner`, and the model can call it: the JSON schema, argument
validation and the call into your function are generated for you.

## Why llm_tool_calling?

- **No hand-written JSON schemas.** Your Dart function is the single source
  of truth. Rename a parameter or add one, and the schema follows on the
  next build, instead of silently drifting out of sync.
- **One package for every provider.** OpenAI, Claude, Gemini, MCP and
  OpenAI-compatible APIs (Mistral, Groq, DeepSeek, Ollama...) are built in.
  No extra package per SDK, and no runtime dependencies at all: it runs on
  every platform, including web.
- **Validation that helps the model.** Wrong arguments never reach your
  code. Every problem is reported in one message written for the model,
  e.g. `passengers[0].age must be an integer, got string`, so it fixes the
  call itself on the next turn.
- **Safe by default for risky actions.** Mark a tool
  `@Tool(requiresConfirmation: true)` and it only runs after the user says
  yes. Without a confirmation step, it never runs.
- **Real Dart types.** Enums, lists, nested classes (freezed too), nullable
  parameters and defaults. JSON quirks are handled for you: `5.0` becomes
  an `int`, `"economy"` becomes `Cabin.economy`.
- **Provider rules handled.** Tool and parameter names follow the strictest
  provider's rules, so a tool that works with one model works with all of
  them.
- **Tested against the real thing.** Each provider format is checked
  against that provider's official Dart SDK, and the Firebase adapter was
  tested live against Gemini.

## How it works

```
 your @Tool() function
          │  dart run build_runner build
          ▼
 getWeatherTool (+ allTools: every tool in the file)
          │  allTools.toOpenAiJson() / toAnthropicJson() / toGeminiJson() / toMcpJson()
          ▼
 the model ── calls a tool ──► allTools.invoke(name, arguments)
                                  validate → confirm (if needed) → run your function
          ◄── result.toText() ─────────────┘
```

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

This creates `lib/tools.g.dart` with `getWeatherTool`, and `allTools`, a
list of every tool in the file.

**4. Use it** with your SDK (see [Use with your SDK](#use-with-your-sdk)):

```dart
import 'package:llm_tool_calling/llm_tool_calling.dart';

import 'tools.dart';

final tools = allTools.toOpenAiJson(); // or toAnthropicJson(), toGeminiJson()...

// When the model calls a tool:
final result = await allTools.invoke('getWeather', {'city': 'Kanpur'});
print(result.toText()); // Sunny, 31°C in Kanpur
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

## Use with your SDK

Everything is built into this package; you don't add anything per SDK.

| Method | For |
|---|---|
| `allTools.toOpenAiJson()` | OpenAI Chat Completions, and compatible APIs (Mistral, Groq, DeepSeek, Ollama...) |
| `allTools.toOpenAiResponsesJson()` | OpenAI Responses API |
| `allTools.toAnthropicJson()` | Anthropic (Claude) |
| `allTools.toGeminiJson()` | Gemini (as `parametersJsonSchema`) |
| `allTools.toMcpJson()` | Model Context Protocol servers |
| `allTools.invoke(name, arguments)` | Running the model's call: validates, asks for confirmation, runs, and never throws |

`invoke` takes the arguments as a map, or as a JSON string (how OpenAI sends
them), and returns a `ToolResult`. Send `result.toText()` back to the model
(or `result.toJson()` where the API wants an object), and use
`result.isError` where the API has an error flag. Invalid arguments, unknown
tools and exceptions from your function all become an error the model can
read and fix.

> **Import `llm_tool_calling` in every file that uses these methods.** They
> are extension methods, which Dart only finds where the package is
> imported; importing your `tools.dart` isn't enough.
>
> **Import SDKs with a prefix** (`as openai`, `as anthropic`, `as mcp`):
> most AI SDKs also have classes called `Tool`, and Anthropic's has a
> `ToolDefinition`, just like this package.

### OpenAI

With [`openai_dart`](https://pub.dev/packages/openai_dart). A complete loop:
ask a question, run every tool the model calls, return its answer.

```dart
import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:llm_tool_calling/llm_tool_calling.dart';

import 'tools.dart'; // your @Tool functions and the generated allTools

Future<String?> askOpenAi(String question) async {
  final client = openai.OpenAIClient.fromEnvironment(); // OPENAI_API_KEY
  final tools = allTools.toOpenAiJson().map(openai.Tool.fromJson).toList();
  final messages = <openai.ChatMessage>[openai.ChatMessage.user(question)];
  try {
    while (true) {
      final response = await client.chat.completions.create(
        openai.ChatCompletionCreateRequest(
          model: 'gpt-5.5',
          messages: messages,
          tools: tools,
        ),
      );
      if (!response.hasToolCalls) return response.text;

      messages.add(
        openai.ChatMessage.assistant(toolCalls: response.allToolCalls),
      );
      for (final call in response.allToolCalls) {
        final result = await allTools.invoke(
          call.function.name,
          call.function.arguments, // a JSON string; invoke decodes it
        );
        messages.add(
          openai.ChatMessage.tool(toolCallId: call.id, content: result.toText()),
        );
      }
    }
  } finally {
    client.close();
  }
}
```

Using the Responses API? Use `toOpenAiResponsesJson()` instead.

### Claude

With [`anthropic_sdk_dart`](https://pub.dev/packages/anthropic_sdk_dart):

```dart
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:llm_tool_calling/llm_tool_calling.dart';

import 'tools.dart'; // your @Tool functions and the generated allTools

Future<String> askClaude(String question) async {
  final client = anthropic.AnthropicClient.fromEnvironment(); // ANTHROPIC_API_KEY
  final tools = [
    for (final json in allTools.toAnthropicJson())
      anthropic.ToolDefinition.custom(anthropic.Tool.fromJson(json)),
  ];
  final messages = <anthropic.InputMessage>[
    anthropic.InputMessage.user(question),
  ];
  try {
    while (true) {
      final response = await client.messages.create(
        anthropic.MessageCreateRequest(
          model: 'claude-opus-5-5',
          maxTokens: 16000,
          tools: tools,
          messages: messages,
        ),
      );
      if (!response.hasToolUse) return response.text;

      messages.add(response.toInputMessage());
      final results = <anthropic.InputContentBlock>[];
      for (final toolUse in response.toolUseBlocks) {
        final result = await allTools.invoke(toolUse.name, toolUse.input);
        results.add(
          anthropic.InputContentBlock.toolResultText(
            toolUseId: toolUse.id,
            text: result.toText(),
            isError: result.isError, // lets Claude see the call failed
          ),
        );
      }
      messages.add(anthropic.InputMessage.userBlocks(results));
    }
  } finally {
    client.close();
  }
}
```

### Gemini

- **In a Flutter app with Firebase:** use the
  [`llm_tool_calling_firebase_ai`](https://pub.dev/packages/llm_tool_calling_firebase_ai)
  adapter. One call runs the whole loop:
  `chat.sendMessageWithTools(Content.text(question), allTools)`. (firebase_ai
  needs typed schema objects rather than JSON, which is why this one part is
  a separate package.)
- **Gemini REST API, or another Gemini SDK:** send `allTools.toGeminiJson()`
  as the `functionDeclarations`, and run each `functionCall` with
  `allTools.invoke(call['name'], call['args'])`, sending back
  `result.toJson()` as its `functionResponse`.

### MCP server

With [`mcp_dart`](https://pub.dev/packages/mcp_dart): serve your tools to
Claude Desktop, Cursor and other MCP clients.

```dart
import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:llm_tool_calling/llm_tool_calling.dart';

import 'tools.dart'; // your @Tool functions and the generated allTools

Future<void> main() async {
  final server = mcp.McpServer(
    const mcp.Implementation(name: 'weather', version: '1.0.0'),
  );
  for (final tool in allTools.toMcpJson().map(mcp.Tool.fromJson)) {
    server.registerTool(
      tool.name,
      description: tool.description,
      inputSchema: tool.inputSchema as mcp.JsonObject,
      annotations: tool.annotations, // destructiveHint from requiresConfirmation
      callback: (args, extra) async {
        final result = await allTools.invoke(tool.name, args);
        return mcp.CallToolResult(
          content: [mcp.TextContent(text: result.toText())],
          isError: result.isError,
        );
      },
    );
  }
  await server.connect(mcp.StdioServerTransport());
}
```

### Any other SDK, or plain HTTP

Send the JSON from the table above in your request (most SDKs can build
their tool objects from it with `fromJson`), and pass each tool call the
model makes to `allTools.invoke(name, arguments)`. That's all the
integration there is.

### Tools that need confirmation

Pass `confirm` to `invoke` to ask the user before running a tool marked
`@Tool(requiresConfirmation: true)`. It's called after validation, so users
are never asked about a call that would fail:

```dart
final result = await allTools.invoke(
  name,
  arguments,
  confirm: (tool, args) => showConfirmDialog(tool.name, args),
);
```

Without `confirm`, these tools never run, and the model is told they need
the user's confirmation. If the user declines, the model is told that too.

## Compatibility

Generated schemas use plain JSON Schema (`type`, `properties`, `required`,
`enum`, `items`, nested objects, `description`, `additionalProperties`), and
generated tool and parameter names follow the strictest provider rules. They
work with:

| Provider | Use | Arguments arrive as | Notes |
|---|---|---|---|
| **OpenAI** (Chat Completions, Responses) | `toOpenAiJson()` / `toOpenAiResponsesJson()` | JSON **string** (`invoke` accepts it as is) | Works as-is. Strict mode (`strict: true`) also needs every field in `required`, so it only fits tools without optional parameters. |
| **Anthropic Claude** | `toAnthropicJson()` | Object (`input`) | Current models don't allow forced `tool_choice`; use `auto` and name the tool in your prompt. |
| **Google Gemini** 2.5+ | `toGeminiJson()` (`parametersJsonSchema`) | Object (`args`) | Use `parametersJsonSchema`, **not** `parameters`: the older field rejects `additionalProperties`. Works with `firebase_ai` via the same field. |
| **Mistral** | `toOpenAiJson()` | JSON string | Same shape as OpenAI. |
| **Ollama** (local models) | `toOpenAiJson()` | Object | How well the model fills nested objects depends on the model. |
| Other OpenAI-compatible APIs (DeepSeek, Groq, xAI…) | `toOpenAiJson()` | Usually a JSON string | Same request shape as OpenAI. |

Some SDKs still send schemas to Gemini in the older `parameters` field. If
yours does, pass `withoutAdditionalProperties(tool.parametersSchema)`
instead; unknown arguments are still rejected by `tool(args)`.

Checked against each provider's official documentation in October 2026.
To test it live with your own API keys, run
[`provider_check.dart`](https://github.com/amitgp853/llm_tool_calling/blob/main/tool_calling_playground/bin/provider_check.dart):
it sends a tool with nested objects, lists and enums to every provider you
have a key for, and checks that the model's arguments pass validation.

## Annotations

| | |
|---|---|
| `@Tool()` | Marks a **top-level function** as a tool. |
| `@Tool(name: 'get_weather')` | Name sent to the LLM. Defaults to the function name. Must start with a letter or `_`, then letters, digits, `_` or `-`, up to 63 characters. |
| `@Tool(description: '...')` | Description sent to the LLM. Defaults to the function's doc comment (`///` or `/** */`). One of the two is required. |
| `@Tool(requiresConfirmation: true)` | Sets `ToolDefinition.requiresConfirmation`, so your app can ask the user before running it (e.g. for deleting or paying). |
| `@Param('...')` | Description of one parameter. Optional, but it helps the LLM a lot. |
| `@Param('...', name: 'game_id')` | The name the LLM sees and sends, e.g. snake case, while your Dart parameter stays `gameId`. Works on class fields too. |

The generated variable is always `<functionName>Tool`, e.g. `getWeatherTool`,
even when you set a custom `name`.

### All tools in a file

Each file with tools also gets a list of all of them, in source order, named
after the file so that several tool files never clash:

| File | Generated list |
|---|---|
| `tools.dart` | `allTools` |
| `weather.dart` or `weather_tools.dart` | `weatherTools` |
| `flight_booking.dart` | `flightBookingTools` |

```dart
// Send every tool to the LLM, from one file or several:
final tools = [...weatherTools, ...flightBookingTools];
```

## Supported types

| Dart type | JSON Schema | Notes |
|---|---|---|
| `String` | `"string"` | |
| `int` | `"integer"` | `5.0` is accepted and converted to `5`. |
| `double` | `"number"` | `5` is accepted and converted to `5.0`. |
| `num` | `"number"` | |
| `bool` | `"boolean"` | |
| any `enum` | `"string"` with `"enum": [...]` | Sent as value names, e.g. `"celsius"`. |
| your own classes | `"object"` with `"properties": {...}` | See [Class parameters](#class-parameters). |
| `List<T>` of any type above | `"array"` with `"items": {...}` | Includes lists of enums, classes and lists. Items can't be nullable. |

Parameters can be positional or named, and any of them can be nullable or
have a default value:

| Parameter | Required in schema? |
|---|---|
| `String city` / `{required String city}` | Yes |
| `String? city` / `{String? city}` / `{required String? city}` | No (missing means `null`) |
| `{String unit = 'metric'}` / `[int count = 3]` | No (missing means the default) |

Functions can return anything, including `Future<T>` and `void` (`void`
tools return `null`).

`Map`, `Set`, `DateTime` and generic classes are not supported yet. Using
them is a build-time error, not a silent bug.

### Class parameters

A class parameter becomes a nested object schema, built from the class's
**unnamed constructor**: each constructor parameter is a field, with the same
rules as tool parameters (types, required, nullable, defaults).

```dart
/// A person on the flight.
class Passenger {
  Passenger({required this.name, required this.age, this.bags = 1});

  /// Full name as on the passport.
  final String name;
  final int age;
  final int bags;
}

/// Books a flight.
@Tool(requiresConfirmation: true)
String bookFlight(List<Passenger> passengers, String from, String to) => '...';
```

- **Descriptions** come from `@Param('...')` on the constructor parameter,
  or the field's `///` doc comment for `this.name` parameters. The class's
  doc comment describes the object, unless the tool parameter has `@Param`.
- **Defaults** like `this.bags = 1` work. For classes in another file, the
  default must be a literal, an enum value or a const list of those;
  otherwise you get a build error explaining how to fix it.
- **freezed classes** work: their unnamed `factory` constructor is used.
- Classes can contain other classes, enums and lists. A class can't contain
  itself (e.g. a linked-list `Node`); that's a build-time error.
- Classes from a prefixed import (`import 'models.dart' as models;`) work.

## Validation and errors

`invoke` (and `tool(args)`, that is `ToolDefinition.call`) validates the
arguments **before** running your function. It reports **every** problem at
once:

| Problem | Message |
|---|---|
| Required argument missing or `null` | `city is required` |
| Argument not in the schema | `colour is not a known argument` |
| Wrong JSON type | `city must be a string, got integer` |
| Value not in an enum | `unit must be one of "celsius", "fahrenheit", got "kelvin"` |
| Wrong list item (every one is checked) | `tags[2] must be a string, got integer` |
| Problem inside an object | `booking.passengers[0].age is required`, `passenger.seat is not a known field` |

If anything is wrong, your function does not run. `invoke` returns a
failed `ToolResult`, and `tool(args)` throws a `ToolArgumentException`.
Either way, the message is written for the LLM:

```
Invalid arguments for "getWeather": city is required; colour is not a known argument
```

Send it back as the tool result and most models will correct the call on
their next turn. You can also read `e.toolName` and `e.errors` directly.

Good to know:

- `invoke` never throws: exceptions from your function become a failed
  `ToolResult` too. `tool(args)` lets them through, for when you want to
  handle them yourself.
- `execute(args)` runs the function **without** validation or
  confirmation. Prefer `invoke`.
- Generated schemas include `"additionalProperties": false`, matching the
  "unknown argument" check.
- `invoke` enforces `requiresConfirmation` through `confirm`; `tool(args)`
  and `execute` don't, so check `tool.requiresConfirmation` yourself if you
  use them.
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

**`The name 'ToolDefinition' is defined in the libraries ...`**
- Another package you import also has a `ToolDefinition` (for example
  `flutter_ai_core`). Import one of them with a prefix, e.g.
  `import 'package:llm_tool_calling/llm_tool_calling.dart' as ltc;` and
  annotate with `@ltc.Tool()`. The generated code follows your prefix.

**`The method 'toOpenAiJson' isn't defined for the type 'List'`** (or
`invoke`, `toAnthropicJson`, ...)
- Add `import 'package:llm_tool_calling/llm_tool_calling.dart';` to that
  file. These are extension methods, and importing only your `tools.dart`
  doesn't bring them into scope.

**`Could not resolve annotation for ...`**
- The file uses `@Tool` without importing
  `package:llm_tool_calling/llm_tool_calling.dart`.

**`Tool "x" needs a description`**
- Add a `///` doc comment above the function, or use
  `@Tool(description: '...')`. The LLM relies on it to decide when to call
  your tool.

**`Tool name "..." is invalid`**
- To work with every provider, a name must start with a letter or `_` and
  use only letters, digits, `_` and `-`, up to 63 characters. Use
  `@Tool(name: 'valid_name')`. This also applies to function names that
  contain `$`.

**`Parameter "..." has a name some LLM providers reject`**
- Gemini only accepts letters, digits and `_` in parameter names, so rename
  parameters or fields that contain `$`.

**`Parameter "x" has type ..., which is not supported yet`**
- Use `String`, `int`, `double`, `num`, `bool`, an enum, your own class, or a
  `List` of these; see [Supported types](#supported-types). The same message
  starts with `Field "passenger.birthday"` when it's a field of a class.

**`... but list items can't be nullable`**
- Use `List<String>` instead of `List<String?>`. The whole list can still be
  nullable: `List<String>?`.

**`... which has no unnamed constructor` / `... which is abstract` / `... which contains itself`**
- Class parameters are built through the class's unnamed constructor. See
  [Class parameters](#class-parameters).

**`Field "..." has a default value that can't be copied into the generated code`**
- The class is in another file and its default isn't a literal, an enum
  value or a const list of those. Make the field nullable or required, or use
  a simpler default.

**`Conflicting outputs were detected`**
- Run `dart run build_runner build --delete-conflicting-outputs`.

**Using `json_serializable` or `freezed` in the same file?** That's fine.
All of them write into the same shared `.g.dart` part.

## Roadmap

- An optional MCP package that registers `allTools` on an `McpServer` in one
  line (today it's the short loop shown above).
- `llm_tool_calling_flutter`: an approval widget for
  `requiresConfirmation` tools.

## Packages

| Package | Purpose | Add as |
|---|---|---|
| [`llm_tool_calling`](https://pub.dev/packages/llm_tool_calling) | Annotations, `ToolDefinition`, validation | dependency |
| [`llm_tool_calling_generator`](https://pub.dev/packages/llm_tool_calling_generator) | The `build_runner` code generator | dev dependency |
| [`llm_tool_calling_firebase_ai`](https://pub.dev/packages/llm_tool_calling_firebase_ai) | Adapter for Firebase AI Logic (`firebase_ai`) | dependency |

## Author

Built and maintained by [Amit Gupta](https://github.com/amitgp853).
Bug reports, ideas and pull requests are welcome on
[GitHub](https://github.com/amitgp853/llm_tool_calling/issues).
If this package saves you time, a like on pub.dev or a star on GitHub helps
others find it.
