# llm_tool_calling_firebase_ai

**Use [`llm_tool_calling`](https://pub.dev/packages/llm_tool_calling) tools
with Firebase AI Logic ([`firebase_ai`](https://pub.dev/packages/firebase_ai)).
Your `@Tool()` functions become Gemini function declarations, with no
hand-written `Schema` objects.**

```dart
final model = FirebaseAI.googleAI().generativeModel(
  model: 'gemini-2.5-flash',
  tools: [allTools.toFirebaseAiTool()],
);
final chat = model.startChat(); // Gemini calls your tools automatically
```

## Install

```sh
flutter pub add llm_tool_calling llm_tool_calling_firebase_ai firebase_ai
flutter pub add dev:llm_tool_calling_generator dev:build_runner
```

Write your tools and generate `allTools` as described in the
[llm_tool_calling quick start](https://pub.dev/packages/llm_tool_calling#quick-start-60-seconds).

## Automatic function calling

`toFirebaseAiTool()` returns a firebase_ai `Tool` whose functions a
`ChatSession` runs by itself:

```dart
final model = FirebaseAI.googleAI().generativeModel(
  model: 'gemini-2.5-flash',
  tools: [allTools.toFirebaseAiTool(confirm: askUser)],
);
final chat = model.startChat();
final response = await chat.sendMessage(Content.text('Weather in Kanpur?'));
print(response.text);
```

For each call, the adapter:

1. **Validates** the arguments. Invalid ones are sent back to Gemini as an
   error it can read and fix, and your function doesn't run.
2. **Asks for confirmation** if the tool is `@Tool(requiresConfirmation: true)`
   (see below).
3. **Runs** your function and sends the result back. Results that aren't
   JSON (e.g. a `DateTime`) are sent as their `toString()`.

## Tools that need confirmation

Tools marked `@Tool(requiresConfirmation: true)` only run when your
`confirm` callback returns `true`. It is called **after** validation, so
users are never asked about a call that would fail:

```dart
Future<bool> askUser(ToolDefinition tool, Map<String, Object?> args) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Allow ${tool.name}?'),
          content: Text('$args'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
          ],
        ),
      ) ??
      false;
}
```

Without a `confirm` callback these tools **never run**; Gemini is told the
tool needs the user's confirmation. If the user declines, Gemini is told
that too, so it can answer without the tool.

## Manual function calling

To decide yourself when each call runs, declare the tools without the
automatic callable and answer the calls with `respondTo`:

```dart
final model = FirebaseAI.googleAI().generativeModel(
  model: 'gemini-2.5-flash',
  tools: [Tool.functionDeclarations(allTools.toFunctionDeclarations())],
);
final chat = model.startChat();
var reply = await chat.sendMessage(Content.text('Weather in Pune?'));
while (reply.functionCalls.isNotEmpty) {
  final responses = [
    for (final call in reply.functionCalls)
      await allTools.respondTo(call, confirm: askUser),
  ];
  reply = await chat.sendMessage(Content.functionResponses(responses));
}
print(reply.text);
```

`respondTo` never throws: unknown tools, invalid arguments, declined
confirmations and exceptions from your function all become an `error`
Gemini can read.

## Good to know

- **`Tool` name clash:** firebase_ai has a class called `Tool`, and so does
  llm_tool_calling (the `@Tool()` annotation). In files that use both, hide
  ours: `import 'package:llm_tool_calling/llm_tool_calling.dart' hide Tool;`.
  Your tool files (with `@Tool()`) usually don't import firebase_ai, so they
  don't need this.
- Schemas are sent as `parametersJsonSchema`, the field Gemini 2.5+ uses for
  full JSON Schema. `additionalProperties` is left out because firebase_ai
  can't express it; unknown arguments are still rejected by validation.
- Supported: everything llm_tool_calling generates (strings, numbers,
  booleans, enums, lists and nested classes). For hand-written schemas with
  other keywords, `toFirebaseJsonSchema` throws an `ArgumentError` naming the
  unsupported part.
- Tool names can be up to 63 characters, firebase_ai's limit.

## Author

Built and maintained by [Amit Gupta](https://github.com/amitgp853).
Bug reports, ideas and pull requests are welcome on
[GitHub](https://github.com/amitgp853/llm_tool_calling/issues).
