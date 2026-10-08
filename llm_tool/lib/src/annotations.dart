import 'tool_definition.dart';

/// Marks a top-level function, or a method of an [LlmToolset] class, as a
/// tool an LLM can call.
///
/// Run `dart run build_runner build` and the generator creates a
/// `<functionName>Tool` [ToolDefinition] in the file's `.g.dart` part.
///
/// ```dart
/// /// Gets the current weather for a city.
/// @LlmTool()
/// String getWeather(@Param('City name, e.g. Kanpur') String city) => '...';
/// ```
class LlmTool {
  /// The name sent to the LLM. Defaults to the function name.
  ///
  /// Must start with a letter or `_`, then letters, digits, `_` or `-`, up
  /// to 63 characters: the rules every supported provider and SDK accepts.
  final String? name;

  /// What the tool does, written for the LLM.
  ///
  /// Defaults to the function's `///` doc comment. One of the two is required.
  final String? description;

  /// Whether a human should approve each call before it runs.
  ///
  /// Copied to [ToolDefinition.requiresConfirmation]. [ToolDefinition.invoke]
  /// only runs such a tool when its `confirm` callback approves.
  final bool requiresConfirmation;

  /// Marks a function as a tool. See the class docs for an example.
  const LlmTool({
    this.name,
    this.description,
    this.requiresConfirmation = false,
  });
}

/// Marks a class whose `@LlmTool` methods are tools, e.g. tools that need
/// a service, a repository or other state.
///
/// The generator adds an extension with an `llmTools` getter that returns
/// the tools bound to one instance:
///
/// ```dart
/// @LlmToolset()
/// class WeatherTools {
///   WeatherTools(this._api);
///   final WeatherApi _api;
///
///   /// Gets the current weather for a city.
///   @LlmTool()
///   Future<String> getWeather(@Param('City name') String city) =>
///       _api.current(city);
/// }
///
/// final tools = WeatherTools(api).llmTools;
/// ```
///
/// Static methods work too. `@LlmTool` methods in a class without
/// `@LlmToolset` are a build error.
class LlmToolset {
  /// Marks a class as a toolset. See the class docs for an example.
  const LlmToolset();
}

/// Describes one parameter of an [LlmTool] function to the LLM.
///
/// Optional, but good descriptions make the LLM call your tool correctly far
/// more often.
class Param {
  /// The description included in the parameter's JSON schema.
  final String description;

  /// The name the LLM sees and sends, if it should differ from the Dart
  /// name, e.g. snake case for `gameId`:
  ///
  /// ```dart
  /// @Param('A game id', name: 'game_id') int gameId
  /// ```
  ///
  /// Must start with a letter or `_`, then letters, digits or `_` (up to 64
  /// characters), which every provider accepts.
  final String? name;

  /// The smallest allowed number (inclusive), for a number parameter or the
  /// items of a list of numbers.
  final num? min;

  /// The largest allowed number (inclusive), like [min].
  final num? max;

  /// The fewest characters allowed, for a `String` parameter or the items of
  /// a list of strings.
  final int? minLength;

  /// The most characters allowed, like [minLength].
  final int? maxLength;

  /// A regular expression the text must contain a match for, like
  /// [minLength]. Use `^` and `\$` to match the whole text:
  ///
  /// ```dart
  /// @Param('A square, e.g. e4', pattern: r'^[a-h][1-8]\$') String square
  /// ```
  final String? pattern;

  /// The fewest items allowed, for a `List` parameter.
  final int? minItems;

  /// The most items allowed, for a `List` parameter.
  final int? maxItems;

  /// Describes a parameter, e.g. `@Param('City name, e.g. Kanpur')`, with
  /// optional limits that go into the schema and are checked before your
  /// function runs:
  ///
  /// ```dart
  /// @Param('Age in years', min: 0, max: 130) int age
  /// ```
  const Param(
    this.description, {
    this.name,
    this.min,
    this.max,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.minItems,
    this.maxItems,
  });
}
