import 'dart:convert';

import 'tool_definition.dart';

/// Everything the LLM sees of [tools], as stable, readable JSON, for a
/// snapshot test that fails when a schema changes:
///
/// ```dart
/// test('tool schemas', () {
///   final file = File('test/tool_schemas.json');
///   final snapshot = toolSchemaSnapshot(allTools);
///   if (!file.existsSync()) file.writeAsStringSync(snapshot);
///   expect(snapshot, file.readAsStringSync());
/// });
/// ```
///
/// Renaming a parameter, editing a doc comment or adding a limit changes
/// what the model gets; the test makes that a reviewed change. Delete the
/// file to accept a new snapshot.
///
/// Each tool is written with its name, description, requiresConfirmation
/// and parameters, in the order given. Nothing is sorted: the order is part
/// of what the LLM sees, and generated schemas are always written the same
/// way. Throws an [ArgumentError] if two tools share a name.
String toolSchemaSnapshot(Iterable<ToolDefinition> tools) {
  final names = <String>{};
  final json = [
    for (final tool in tools)
      if (!names.add(tool.name))
        throw ArgumentError.value(
          tool.name,
          'tools',
          'Two tools are named "${tool.name}"',
        )
      else
        {
          'name': tool.name,
          'description': tool.description,
          'requiresConfirmation': tool.requiresConfirmation,
          'parameters': tool.parametersSchema,
        },
  ];
  return '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}
