# llm_tool_firebase_ai

**Use [`llm_tool`](https://pub.dev/packages/llm_tool) tools
with Firebase AI Logic ([`firebase_ai`](https://pub.dev/packages/firebase_ai)).
Your `@LlmTool()` functions become Gemini function declarations, with no
hand-written `Schema` objects, and one call runs the whole tool loop.**

```dart
final model = FirebaseAI.googleAI().generativeModel(
  model: 'gemini-3.8-flash',
  tools: [Tool.functionDeclarations(allTools.toFunctionDeclarations())],
);
final reply = await model.startChat().sendMessageWithTools(
  Content.text('What is the weather in Kanpur?'),
  allTools,
);
print(reply.text); // The weather in Kanpur is currently sunny and 31°C.
```

## Install

```sh
flutter pub add llm_tool llm_tool_firebase_ai firebase_ai
flutter pub add dev:llm_tool_generator dev:build_runner
```

Write your tools and generate `allTools` as described in the
[llm_tool quick start](https://pub.dev/packages/llm_tool#quick-start-60-seconds).

Where you create the model, these imports are all you need (the adapter
also gives you `ToolDefinition` and `ToolArgumentException`):

```dart
import 'package:firebase_ai/firebase_ai.dart';
import 'package:llm_tool_firebase_ai/llm_tool_firebase_ai.dart';

import 'tools.dart'; // your @LlmTool functions and the generated allTools
```

## Running tools

Declare the tools with `toFunctionDeclarations()`, then send messages with
`sendMessageWithTools`. It sends your message, runs every tool Gemini asks
for, sends the results back, and repeats until Gemini answers:

```dart
final model = FirebaseAI.googleAI().generativeModel(
  model: 'gemini-3.8-flash',
  tools: [Tool.functionDeclarations(allTools.toFunctionDeclarations())],
);
final chat = model.startChat();
final reply = await chat.sendMessageWithTools(
  Content.text('Book a flight from DEL to BOM for Asha, 30'),
  allTools,
  confirm: askUser, // see below
);
print(reply.text);
```

For each tool call:

1. **Validation:** invalid arguments are sent back to Gemini as an error it
   can read and fix, and your function doesn't run.
2. **Confirmation:** tools marked `@LlmTool(requiresConfirmation: true)` only
   run when `confirm` approves them (see below).
3. **Result:** your function runs and its result goes back to Gemini. Results
   that aren't JSON (e.g. a `DateTime`) are sent as their `toString()`.

`sendMessageWithTools` stops after 10 rounds of tool calls (`maxRounds`), so
a confused model can't loop forever.

Tools from an [`@LlmToolset`](https://pub.dev/packages/llm_tool#tools-as-class-methods)
class work the same way. Combine lists as you like, and pass the same list
to both calls:

```dart
final tools = [...allTools, ...CoachTools(engine, games).llmTools];
final model = FirebaseAI.googleAI().generativeModel(
  model: 'gemini-3.8-flash',
  tools: [Tool.functionDeclarations(tools.toFunctionDeclarations())],
);
final reply = await model.startChat().sendMessageWithTools(
  Content.text('How did my last game go?'),
  tools,
);
```

## Tools that need confirmation

Tools marked `@LlmTool(requiresConfirmation: true)` only run when your
`confirm` callback returns `true`. It is called **after** validation, so
users are never asked about a call that would fail. In a Flutter app, pass a
callback that has a `BuildContext` and show a dialog:

```dart
// In your widget, e.g. in a button handler:
final reply = await chat.sendMessageWithTools(
  Content.text(userMessage),
  allTools,
  confirm: (tool, args) => askUser(context, tool, args),
);

Future<bool> askUser(
  BuildContext context,
  ToolDefinition tool,
  Map<String, Object?> args,
) async {
  final allowed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Allow ${tool.name}?'),
      content: Text('$args'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
  return allowed ?? false;
}
```

Without a `confirm` callback these tools **never run**; Gemini is told the
tool needs the user's confirmation. If the user declines, Gemini is told
that too, so it can answer without the tool.

## Writing the loop yourself

`sendMessageWithTools` is a short loop over `respondTo`. To control each step
(e.g. to show progress), write it yourself:

```dart
var reply = await chat.sendMessage(Content.text('Weather in Pune?'));
while (reply.functionCalls.isNotEmpty) {
  final results = [
    for (final call in reply.functionCalls)
      await allTools.respondTo(call, confirm: askUser),
  ];
  reply = await chat.sendMessage(toolResponses(results));
}
print(reply.text);
```

Send the results with **`toolResponses`**, not firebase_ai's
`Content.functionResponses`; see the next section for why. `respondTo` never
throws for problems with the call: unknown tools, invalid arguments,
declined confirmations and exceptions from your function all become an
`error` Gemini can read.

## firebase_ai's automatic function calling

firebase_ai can also run tools by itself, and `toFirebaseAITool()` gives it
everything it needs:

```dart
final model = FirebaseAI.googleAI().generativeModel(
  model: 'gemini-3.8-flash',
  tools: [allTools.toFirebaseAITool(confirm: askUser)],
);
final response = await model.startChat().sendMessage(Content.text('Hi'));
```

> **Doesn't work with newer models in firebase_ai 4.0.0.** It sends tool
> results with the role `function`, and newer Gemini models such as
> `gemini-3.8-flash` reject it: *"Role 'function' is not supported"*. Your
> tool still runs, but the chat fails afterwards. The same applies to
> firebase_ai's `Content.functionResponses`. It's fixed in firebase_ai's
> source ([flutterfire#18685](https://github.com/firebase/flutterfire/pull/18685))
> but not released yet. Until it is, use `sendMessageWithTools` (or
> `toolResponses`), which send results with the role `user`, the same fix.

## Tested with real Gemini

Checked live in October 2026 with `gemini-3.8-flash` on the Gemini
Developer API, using tools made by the generator: a simple tool, a tool with
nested classes, lists and an enum (with defaults filled in) after an
approved confirmation, and the hand-written loop. Declined confirmations and
the other error paths are covered by the package's unit tests. The check app is
[in the repository](https://github.com/amitgp853/llm_tool/tree/main/firebase_live_check).

## Good to know

- **App Check:** firebase_ai sends an App Check token with every request. If
  App Check is enforced for Firebase AI Logic in your project, set App Check
  up in your app, or requests fail with *"Firebase App Check token is
  invalid"*.
- **`Tool` name clash:** firebase_ai has a class called `Tool`. Until
  1.0.0, llm_tool still has `Tool` too, as a deprecated alias of
  `@LlmTool`. Keep your `@LlmTool()` functions in their own file (e.g.
  `tools.dart`), and in the file that creates the model import only
  firebase_ai and this adapter, as shown above: the adapter leaves out the
  annotations. If a file must import both packages, use
  `import 'package:llm_tool/llm_tool.dart' hide Tool;`.
- **Unique names:** all tools passed together must have different names
  (e.g. when combining `allTools` from several files); otherwise the adapter
  throws an `ArgumentError` naming the duplicate, instead of firebase_ai
  silently keeping only one.
- Schemas are sent as `parametersJsonSchema`, the field Gemini 2.5+ uses for
  full JSON Schema. `additionalProperties` is left out because firebase_ai
  can't express it; unknown arguments are still rejected by validation.
  The same goes for the `@Param` limits `minLength`, `maxLength` and
  `pattern`: they are written into the parameter's description instead, so
  Gemini still reads them.
- Supported: everything llm_tool generates (strings, numbers,
  booleans, enums, lists and nested classes). For hand-written schemas with
  other keywords, `toFirebaseJsonSchema` throws an `ArgumentError` naming the
  unsupported part.
- Tool names can be up to 63 characters, firebase_ai's limit.

## Author

Built and maintained by [Amit Gupta](https://github.com/amitgp853).
Bug reports, ideas and pull requests are welcome on
[GitHub](https://github.com/amitgp853/llm_tool/issues).
