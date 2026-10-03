import 'dart:async';
import 'schema_validator.dart';
import 'tool_argument_exception.dart';

/// A tool an LLM can call: its name, description, JSON schema and code.
///
/// Usually generated from a [Tool]-annotated function, but you can also
/// write one by hand.
class ToolDefinition {
  /// The name the LLM uses to call this tool.
  final String name;

  /// What the tool does, written for the LLM.
  final String description;

  /// JSON Schema (`"type": "object"`) describing the tool's arguments.
  ///
  /// Send this to the LLM provider as the tool's parameters.
  final Map<String, Object?> parametersSchema;

  /// Whether a human should approve each call before it runs.
  final bool requiresConfirmation;

  /// Runs the tool with already-decoded JSON arguments, without validation.
  ///
  /// Prefer [call], which validates first.
  final FutureOr<Object?> Function(Map<String, Object?> args) execute;

  /// Creates a tool definition. See the class docs.
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
    required this.execute,
    this.requiresConfirmation = false,
  });

  /// Validates [args], then runs the tool. Use this instead of [execute].
  ///
  /// Throws a [ToolArgumentException] listing every problem if [args] don't
  /// match [parametersSchema]. Send its message back to the LLM so it can
  /// fix the call.
  Future<Object?> call(Map<String, Object?> args) async {
    final errors = validateArguments(parametersSchema, args);
    if (errors.isNotEmpty) throw ToolArgumentException(name, errors);
    return await execute(args);
  }
}
