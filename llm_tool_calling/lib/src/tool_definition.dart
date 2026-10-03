import 'dart:async';
import 'schema_validator.dart';
import 'tool_argument_exception.dart';

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, Object?> parametersSchema;
  final bool requiresConfirmation;
  final FutureOr<Object?> Function(Map<String, Object?> args) execute;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
    required this.execute,
    this.requiresConfirmation = false,
  });

    /// Validates [args], then runs the tool. Use this instead of [execute].
  Future<Object?> call(Map<String, Object?> args) async {
    final errors = validateArguments(parametersSchema, args);
    if (errors.isNotEmpty) throw ToolArgumentException(name, errors);
    return await execute(args);
  }
}