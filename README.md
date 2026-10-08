# llm_tool

Turn any Dart function into an LLM tool with one annotation. Works with OpenAI, Claude, Gemini, MCP and on-device models. No hand-written JSON schemas.

```dart
/// Gets the current weather for a city.
@LlmTool()
String getWeather(@Param('City name, e.g. Kanpur') String city) => '...';
```

Run `build_runner` and you get `getWeatherTool`, with its JSON Schema,
argument validation and type-safe dispatch.

**Documentation: [llm_tool/README.md](llm_tool/README.md)**

## Packages in this repository

| Package | Description |
|---|---|
| [`llm_tool`](llm_tool) | Annotations, `ToolDefinition` and argument validation. |
| [`llm_tool_generator`](llm_tool_generator) | The `build_runner` generator. |
| [`llm_tool_firebase_ai`](llm_tool_firebase_ai) | Adapter for Firebase AI Logic (`firebase_ai`). |
| [`tool_calling_playground`](tool_calling_playground) | Not published; used to try the generator end to end. |
| [`firebase_live_check`](firebase_live_check) | Not published; a Flutter web app that checks the firebase_ai adapter against real Gemini. |
| [`edge_ai_example`](edge_ai_example) | Not published; a Flutter app that runs tools on-device with Gemma 4 via `flutter_edge_ai`. |

## Development

This is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces).

```sh
dart pub get                            # once, at the root
dart analyze
(cd llm_tool && dart test)
(cd llm_tool_generator && dart test)
```

To check the generated schemas against real providers with your own API
keys (see the comment at the top of the file for the variables):

```sh
cd tool_calling_playground && dart run bin/provider_check.dart
```

`llm_tool_firebase_ai` is a Flutter package and is **not** part of
the workspace: Flutter's `flutter_test` pins a `test_api` version that
conflicts with the generator's `analyzer`. Work on it on its own:

```sh
cd llm_tool_firebase_ai && flutter pub get && flutter test
```

Publish `llm_tool` before `llm_tool_generator`, which depends
on it.

## Author

Built and maintained by [Amit Gupta](https://github.com/amitgp853).

## License

[MIT](LICENSE)
