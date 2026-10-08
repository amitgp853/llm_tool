import 'package:firebase_ai/firebase_ai.dart';
// firebase_ai has its own Tool class; ours is the annotation, not needed here.
import 'package:llm_tool/llm_tool.dart';

/// Converts a JSON Schema map, as in [ToolDefinition.parametersSchema], to
/// firebase_ai's [JSONSchema].
///
/// Supports what llm_tool generates: the types string, integer,
/// number, boolean, array and object, with `description`, `enum` (strings),
/// `items`, `properties`, `required` and the limits `minimum`, `maximum`,
/// `minItems` and `maxItems`.
///
/// firebase_ai can't express `minLength`, `maxLength` or `pattern`, so they
/// are added to the description for the model to read, e.g.
/// "Airport code (exactly 3 characters, matching ^[A-Z]{3}$)".
/// `additionalProperties` is dropped. [ToolDefinition.call] still checks all
/// of them.
///
/// Throws an [ArgumentError] for anything else, e.g. in a hand-written schema.
JSONSchema toFirebaseJsonSchema(Map<String, Object?> schema) {
  final description = schema['description'] as String?;
  switch (schema['type']) {
    case 'string':
      if (schema['enum'] case final List<Object?> values) {
        return JSONSchema.enumString(
          enumValues: [for (final value in values) '$value'],
          description: description,
        );
      }
      return JSONSchema.string(description: _withTextLimits(schema));
    case 'integer':
      return JSONSchema.integer(
        description: description,
        minimum: (schema['minimum'] as num?)?.toInt(),
        maximum: (schema['maximum'] as num?)?.toInt(),
      );
    case 'number':
      return JSONSchema.number(
        description: description,
        minimum: (schema['minimum'] as num?)?.toDouble(),
        maximum: (schema['maximum'] as num?)?.toDouble(),
      );
    case 'boolean':
      return JSONSchema.boolean(description: description);
    case 'array':
      final items = schema['items'];
      if (items is! Map) {
        throw ArgumentError.value(schema, 'schema', 'Array without "items"');
      }
      return JSONSchema.array(
        items: toFirebaseJsonSchema(items.cast()),
        description: description,
        minItems: schema['minItems'] as int?,
        maxItems: schema['maxItems'] as int?,
      );
    case 'object':
      final (:properties, :optional) = objectFields(schema);
      return JSONSchema.object(
        properties: properties,
        optionalProperties: optional,
        description: description,
      );
    case final type:
      throw ArgumentError.value(
        type,
        'type',
        'JSON Schema type not supported by the firebase_ai adapter',
      );
  }
}

/// A string schema's description, with the limits firebase_ai can't send
/// (minLength, maxLength, pattern) written out for the model.
String? _withTextLimits(Map<String, Object?> schema) {
  final description = schema['description'] as String?;
  final min = schema['minLength'] as int?;
  final max = schema['maxLength'] as int?;
  final pattern = schema['pattern'] as String?;
  String characters(int n) => n == 1 ? '1 character' : '$n characters';
  final limits = [
    switch ((min, max)) {
      (final min?, final max?) when min == max => 'exactly ${characters(min)}',
      (final min?, final max?) => '$min to ${characters(max)}',
      (final min?, null) => 'at least ${characters(min)}',
      (null, final max?) => 'at most ${characters(max)}',
      (null, null) => null,
    },
    if (pattern != null) 'matching $pattern',
  ].nonNulls.join(', ');
  if (limits.isEmpty) return description;
  return description == null ? limits : '$description ($limits)';
}

/// The converted `properties` of an object [schema], and the names of the
/// ones not listed in `required`.
({Map<String, JSONSchema> properties, List<String> optional}) objectFields(
  Map<String, Object?> schema,
) {
  final properties = switch (schema['properties']) {
    final Map<Object?, Object?> map => map,
    _ => const <Object?, Object?>{},
  };
  final required = switch (schema['required']) {
    final List<Object?> list => list,
    _ => const <Object?>[],
  };
  return (
    properties: {
      for (final MapEntry(:key, :value) in properties.entries)
        '$key': toFirebaseJsonSchema((value as Map).cast()),
    },
    // firebase_ai marks everything required unless listed as optional.
    optional: [
      for (final key in properties.keys)
        if (!required.contains(key)) '$key',
    ],
  );
}
