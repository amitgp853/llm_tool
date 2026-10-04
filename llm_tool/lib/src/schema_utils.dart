import 'tool_definition.dart';

/// A copy of [schema] without `additionalProperties`, at every level.
///
/// Gemini's older `parameters` field rejects `additionalProperties`, and some
/// SDKs still send schemas there. Removing it is safe:
/// [ToolDefinition.call] rejects unknown arguments either way.
///
/// ```dart
/// final schema = withoutAdditionalProperties(tool.parametersSchema);
/// ```
Map<String, Object?> withoutAdditionalProperties(Map<String, Object?> schema) =>
    _strip(schema) as Map<String, Object?>;

/// Keywords whose keys are names (of fields or definitions), not keywords.
const _namedSchemas = {'properties', r'$defs', 'definitions'};

Object? _strip(Object? schema) => switch (schema) {
  Map() => <String, Object?>{
    for (final MapEntry(:key, :value) in schema.entries)
      if (key != 'additionalProperties')
        '$key': _namedSchemas.contains(key) && value is Map
            // Keep every name, even a field called "additionalProperties".
            ? {
                for (final MapEntry(key: name, value: field) in value.entries)
                  '$name': _strip(field),
              }
            : _strip(value),
  },
  List() => [for (final item in schema) _strip(item)],
  _ => schema,
};
