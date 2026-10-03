# llm_tool_calling

Turn any Dart function into an LLM tool with one annotation. No hand-written JSON schemas.

```dart
/// Gets the current weather for a city.
@Tool()
String getWeather(@Param('City name, e.g. Kanpur') String city) => '...';
```

Run `build_runner` and you get `getWeatherTool`, with its JSON Schema,
argument validation and type-safe dispatch.

**Documentation: [llm_tool_calling/README.md](llm_tool_calling/README.md)**

## Packages in this repository

| Package | Description |
|---|---|
| [`llm_tool_calling`](llm_tool_calling) | Annotations, `ToolDefinition` and argument validation. |
| [`llm_tool_calling_generator`](llm_tool_calling_generator) | The `build_runner` generator. |
| [`tool_calling_playground`](tool_calling_playground) | Not published; used to try the generator end to end. |

## Development

This is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces).

```sh
dart pub get                            # once, at the root
dart analyze
(cd llm_tool_calling && dart test)
(cd llm_tool_calling_generator && dart test)
```

To check the generated schemas against real providers with your own API
keys (see the comment at the top of the file for the variables):

```sh
cd tool_calling_playground && dart run bin/provider_check.dart
```

Publish `llm_tool_calling` before `llm_tool_calling_generator`, which depends
on it.

## License

[MIT](LICENSE)
