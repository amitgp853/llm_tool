# edge_ai_example

Not published. A small Flutter app that runs `llm_tool` tools with an
**on-device model**: Gemma 4 E2B through
[`flutter_edge_ai`](https://pub.dev/packages/flutter_edge_ai). After the
model download, nothing leaves the phone.

It has three tools, in [`lib/tools.dart`](lib/tools.dart):

| Tool | Shows |
|---|---|
| `get_time` | A top-level `@LlmTool` function. |
| `add_todo` | A method of an `@LlmToolset` class, with `minLength`/`maxLength` limits. |
| `clear_todos` | `requiresConfirmation: true`, wired to a dialog. |

All of the integration is in `_loadModel` and `_reply` in
[`lib/main.dart`](lib/main.dart).

## Run it

You need a real Android (arm64, Android 11+) or iOS device; the iOS
Simulator runs on CPU only and is very slow.

```sh
flutter pub get
dart run build_runner build
flutter run
```

The first start downloads Gemma 4 E2B (2.4 GB), so use Wi-Fi. Later starts
load it from the device.

Then try:

- "Add buy milk and call mom to my list"
- "What time is it?"
- "Clear my to-do list": a dialog asks first; tap **No** and the model is
  told you declined.

**iOS:** after the first `flutter run` creates `ios/Podfile`, set
`platform :ios, '15.0'` and `use_frameworks! :linkage => :static` in it, as
the [flutter_edge_ai README](https://pub.dev/packages/flutter_edge_ai#ios)
describes.
