import 'tool_definition.dart';

/// Marks a top-level function as a tool an LLM can call.
///
/// Run `dart run build_runner build` and the generator creates a
/// `<functionName>Tool` [ToolDefinition] in the file's `.g.dart` part.
///
/// ```dart
/// /// Gets the current weather for a city.
/// @Tool()
/// String getWeather(@Param('City name, e.g. Kanpur') String city) => '...';
/// ```
class Tool {
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
  /// Copied to [ToolDefinition.requiresConfirmation]. Your agent loop decides
  /// how to ask; this flag only records the intent.
  final bool requiresConfirmation;

  /// Marks a function as a tool. See the class docs for an example.
  const Tool({this.name, this.description, this.requiresConfirmation = false});
}

/// Describes one parameter of a [Tool] function to the LLM.
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

  /// Describes a parameter, e.g. `@Param('City name, e.g. Kanpur')`.
  const Param(this.description, {this.name});
}
