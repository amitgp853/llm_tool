/// Checks [args] against a JSON Schema [schema].
/// Returns a list of problems; an empty list means the arguments are valid.
List<String> validateArguments(
  Map<String, Object?> schema,
  Map<String, Object?> args,
) {
  final errors = <String>[];
  final properties =
      (schema['properties'] as Map?)?.cast<String, Object?>() ?? const {};
  final required = (schema['required'] as List?)?.cast<String>() ?? const [];

  // 1. Every required argument must be present.
  for (final name in required) {
    if (args[name] == null) errors.add('$name is required');
  }

  // 2. Every sent argument must be known and have the right type.
  for (final MapEntry(:key, :value) in args.entries) {
    final property = properties[key];
    if (property == null) {
      errors.add('$key is not a known argument');
      continue;
    }
    if (value == null) continue; // already reported above if required

    final expected = (property as Map)['type'] as String?;
    if (expected != null && !_matchesType(value, expected)) {
      errors.add('$key must be a $expected, got ${_jsonType(value)}');
    }
  }
  return errors;
}

bool _matchesType(Object value, String type) => switch (type) {
      'string' => value is String,
      'integer' => value is int,
      'number' => value is num,
      'boolean' => value is bool,
      'array' => value is List,
      'object' => value is Map,
      _ => true, // unknown type: don't block it
    };

String _jsonType(Object value) => switch (value) {
      String() => 'string',
      int() => 'integer',
      double() => 'number',
      bool() => 'boolean',
      List() => 'array',
      Map() => 'object',
      _ => value.runtimeType.toString(),
    };