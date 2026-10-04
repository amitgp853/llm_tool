import 'tool_definition.dart';

/// Thrown when the AI sends arguments that don't match a tool's schema.
///
/// [toString] is written for the LLM: send it back as the tool result and
/// the model can usually correct its call.
class ToolArgumentException implements Exception {
  /// The name of the tool that was called.
  final String toolName;

  /// Every problem found, e.g. `city is required`.
  final List<String> errors;

  /// Creates the exception. Thrown by [ToolDefinition.call].
  const ToolArgumentException(this.toolName, this.errors);

  @override
  String toString() =>
      'Invalid arguments for "$toolName": ${errors.join('; ')}';
}
