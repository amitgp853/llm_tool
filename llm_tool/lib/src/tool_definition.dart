import 'dart:async';
import 'schema_validator.dart';
import 'tool_argument_exception.dart';
import 'tool_result.dart';

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

  /// Runs the tool for a model's call and returns what to send back to the
  /// model. Never throws.
  ///
  /// 1. Invalid [args] give a failure with the [ToolArgumentException]
  ///    message, so the model can fix its call. The tool doesn't run.
  /// 2. If [requiresConfirmation] is set, the tool only runs when [confirm]
  ///    returns `true`; without [confirm], or if the user declines, the
  ///    failure tells the model why.
  /// 3. Otherwise the tool runs. Its result is made JSON-safe; an exception
  ///    it throws becomes a failure with the exception's message.
  ///
  /// ```dart
  /// final result = await getWeatherTool.invoke({'city': 'Kanpur'});
  /// send(result.isError ? result.error : result.toText());
  /// ```
  Future<ToolResult> invoke(
    Map<String, Object?> args, {
    ToolConfirmation? confirm,
  }) async {
    // Validate first, so nobody is asked to confirm a call that would fail.
    final errors = validateArguments(parametersSchema, args);
    if (errors.isNotEmpty) {
      return ToolResult.failure(ToolArgumentException(name, errors).toString());
    }

    if (requiresConfirmation) {
      if (confirm == null) {
        return ToolResult.failure(
          'The tool "$name" needs the user\'s confirmation, and this app has '
          'not set that up, so it was not run.',
        );
      }
      if (!await confirm(this, args)) {
        return ToolResult.failure('The user declined to run "$name".');
      }
    }

    try {
      return ToolResult.success(jsonSafe(await execute(args)));
    } catch (error) {
      return ToolResult.failure('$error');
    }
  }
}
