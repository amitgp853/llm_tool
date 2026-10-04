import 'dart:convert';

import 'package:llm_tool/llm_tool.dart';
import 'package:test/test.dart';

ToolDefinition _tool(
  String name, {
  Map<String, Object?> properties = const {},
  bool requiresConfirmation = false,
}) => ToolDefinition(
  name: name,
  description: 'Does $name.',
  parametersSchema: {'type': 'object', 'properties': properties},
  requiresConfirmation: requiresConfirmation,
  execute: (_) => null,
);

void main() {
  test('readable JSON with everything the LLM sees', () {
    final snapshot = toolSchemaSnapshot([
      _tool(
        'get_weather',
        properties: {
          'city': {'type': 'string', 'minLength': 1},
        },
      ),
      _tool('delete_file', requiresConfirmation: true),
    ]);
    expect(snapshot, '''
[
  {
    "name": "get_weather",
    "description": "Does get_weather.",
    "requiresConfirmation": false,
    "parameters": {
      "type": "object",
      "properties": {
        "city": {
          "type": "string",
          "minLength": 1
        }
      }
    }
  },
  {
    "name": "delete_file",
    "description": "Does delete_file.",
    "requiresConfirmation": true,
    "parameters": {
      "type": "object",
      "properties": {}
    }
  }
]
''');
    expect(jsonDecode(snapshot), hasLength(2));
  });

  test('keeps the order the LLM sees', () {
    final ab = toolSchemaSnapshot([_tool('a'), _tool('b')]);
    final ba = toolSchemaSnapshot([_tool('b'), _tool('a')]);
    expect(ab, isNot(ba));
  });

  test('the same tools always give the same snapshot', () {
    expect(
      toolSchemaSnapshot([_tool('a'), _tool('b')]),
      toolSchemaSnapshot([_tool('a'), _tool('b')]),
    );
  });

  test('a schema change changes the snapshot', () {
    final before = toolSchemaSnapshot([_tool('a')]);
    final after = toolSchemaSnapshot([
      _tool(
        'a',
        properties: {
          'x': {'type': 'integer'},
        },
      ),
    ]);
    expect(after, isNot(before));
  });

  test('no tools', () => expect(toolSchemaSnapshot([]), '[]\n'));

  test('duplicate names are an error', () {
    expect(
      () => toolSchemaSnapshot([_tool('a'), _tool('a')]),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'Two tools are named "a"',
        ),
      ),
    );
  });
}
