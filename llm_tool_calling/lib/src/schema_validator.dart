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
    _checkValue(key, value, property, errors);
  }
  return errors;
}

/// Checks one [value] against its [schema], adding problems to [errors].
/// [path] names the value in messages, e.g. `tags[2]`.
void _checkValue(
  String path,
  Object? value,
  Object? schema,
  List<String> errors,
) {
  // A malformed (hand-written) schema shouldn't crash validation.
  if (schema is! Map) return;

  final expected = schema['type'];
  if (expected is String && (value == null || !_matchesType(value, expected))) {
    errors.add(
      '$path must be ${_withArticle(expected)}, got ${_jsonType(value)}',
    );
    return;
  }

  // Only the listed values are allowed. Listing them lets the LLM fix it.
  final allowed = schema['enum'];
  if (allowed is List && !allowed.contains(value)) {
    errors.add(
      '$path must be one of ${allowed.map(_quote).join(', ')}, '
      'got ${_quote(value)}',
    );
    return;
  }

  if (value is List) {
    for (final (index, item) in value.indexed) {
      _checkValue('$path[$index]', item, schema['items'], errors);
    }
  }
}

String _quote(Object? value) => value is String ? '"$value"' : '$value';

bool _matchesType(Object value, String type) => switch (type) {
  'string' => value is String,
  // LLMs sometimes send whole numbers as 5.0, and jsonDecode turns that
  // into a double. Accept it; generated code converts with toInt().
  'integer' => value is int || (value is double && _isWhole(value)),
  'number' => value is num,
  'boolean' => value is bool,
  'array' => value is List,
  'object' => value is Map,
  _ => true, // unknown type: don't block it
};

bool _isWhole(double value) => value.isFinite && value == value.truncate();

String _withArticle(String type) =>
    type.startsWith(RegExp('[aeiou]')) ? 'an $type' : 'a $type';

String _jsonType(Object? value) => switch (value) {
  null => 'null',
  String() => 'string',
  int() => 'integer',
  double() => 'number',
  bool() => 'boolean',
  List() => 'array',
  Map() => 'object',
  _ => value.runtimeType.toString(),
};
