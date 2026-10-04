import 'dart:async';
import 'dart:convert';

import 'tool_definition.dart';

/// Asks the user whether [tool] may run with [args]. Return `true` to run it.
///
/// Only called for tools with [ToolDefinition.requiresConfirmation], and only
/// after the arguments passed validation.
typedef ToolConfirmation =
    FutureOr<bool> Function(ToolDefinition tool, Map<String, Object?> args);

/// What happened when a tool was invoked, ready to send back to the model:
/// a [value] on success, or an [error] written for the model to read.
///
/// See [ToolDefinition.invoke].
final class ToolResult {
  /// The tool ran and returned [value] (JSON-safe: maps, lists, strings,
  /// numbers, booleans and null; anything else as its `toString()`).
  const ToolResult.success(this.value) : error = null;

  /// The tool didn't run, or failed: [error] says why, for the model.
  const ToolResult.failure(String this.error) : value = null;

  /// The tool's result, if it succeeded.
  final Object? value;

  /// Why the tool didn't run or failed, if it did.
  final String? error;

  /// Whether this is a [ToolResult.failure].
  bool get isError => error != null;

  /// The result as a JSON object, for APIs that take one (e.g. Gemini):
  /// map results as they are, other values as `{"result": value}`, and
  /// failures as `{"error": "..."}`.
  Map<String, Object?> toJson() => switch (this) {
    ToolResult(:final String error) => {'error': error},
    ToolResult(value: final Map<String, Object?> map) => map,
    ToolResult(:final value) => {'result': value},
  };

  /// The result as text, for APIs that take a string (e.g. OpenAI tool
  /// messages, Claude tool results): strings as they are, other values as
  /// JSON, and failures as the error message.
  String toText() => switch (this) {
    ToolResult(:final String error) => error,
    ToolResult(value: final String text) => text,
    ToolResult(:final value) => jsonEncode(value),
  };

  @override
  String toString() =>
      isError ? 'ToolResult.failure($error)' : 'ToolResult.success($value)';
}

/// [value] as JSON-encodable data. Unknown objects become their `toString()`.
Object? jsonSafe(Object? value) => switch (value) {
  null || String() || num() || bool() => value,
  List() => [for (final item in value) jsonSafe(item)],
  Map() => <String, Object?>{
    for (final MapEntry(:key, :value) in value.entries) '$key': jsonSafe(value),
  },
  _ => value.toString(),
};
