import 'package:firebase_ai/firebase_ai.dart';
// firebase_ai has its own Tool class; ours is the annotation, not needed here.
import 'package:llm_tool/llm_tool.dart' hide Tool;

/// Converts a JSON Schema map, as in [ToolDefinition.parametersSchema], to
/// firebase_ai's [JSONSchema].
///
/// Supports what llm_tool generates: the types string, integer,
/// number, boolean, array and object, with `description`, `enum` (strings),
/// `items`, `properties` and `required`. `additionalProperties` is dropped
/// because firebase_ai can't express it; [ToolDefinition.call] still rejects
/// unknown arguments.
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
      return JSONSchema.string(description: description);
    case 'integer':
      return JSONSchema.integer(description: description);
    case 'number':
      return JSONSchema.number(description: description);
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
