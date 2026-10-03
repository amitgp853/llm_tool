/// Checks [args] against a JSON Schema [schema].
/// Returns a list of problems; an empty list means the arguments are valid.
List<String> validateArguments(
  Map<String, Object?> schema,
  Map<String, Object?> args,
) {
  final errors = <String>[];
  _checkObject('', args, schema, errors);
  return errors;
}

/// Checks the fields of [object] against an object [schema]. [path] is empty
/// for the top-level arguments, or e.g. `passenger` for a nested object.
void _checkObject(
  String path,
  Map<Object?, Object?> object,
  Map<Object?, Object?> schema,
  List<String> errors,
) {
  final properties = switch (schema['properties']) {
    final Map<Object?, Object?> map => map,
    _ => const <Object?, Object?>{},
  };
  final required = switch (schema['required']) {
    final List<Object?> list => list,
    _ => const <Object?>[],
  };
  String pathOf(Object? key) => path.isEmpty ? '$key' : '$path.$key';

  // 1. Every required field must be present.
  for (final name in required) {
    if (object[name] == null) errors.add('${pathOf(name)} is required');
  }

  // 2. Every sent field must be known and have the right type.
  for (final MapEntry(:key, :value) in object.entries) {
    final property = properties[key];
    if (property == null) {
      errors.add(
        path.isEmpty
            ? '$key is not a known argument'
            : '${pathOf(key)} is not a known field',
      );
      continue;
    }
    if (value == null) continue; // already reported above if required
    _checkValue(pathOf(key), value, property, errors);
  }
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
  if (value is Map && schema['properties'] is Map) {
    _checkObject(path, value, schema, errors);
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
