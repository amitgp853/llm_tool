// Each provider format is checked against that provider's real Dart SDK:
// the SDK must read our JSON, and give the same JSON back.
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:llm_tool/llm_tool.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:test/test.dart';

/// Like a generated schema: nested object, list, enum, optional field and
/// @Param limits.
const _schema = <String, Object?>{
  'type': 'object',
  'properties': {
    'from': {
      'type': 'string',
      'minLength': 3,
      'maxLength': 3,
      'pattern': r'^[A-Z]{3}$',
      'description': 'Airport code',
    },
    'passengers': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer', 'minimum': 0, 'maximum': 130},
        },
        'required': ['name', 'age'],
        'additionalProperties': false,
      },
      'minItems': 1,
      'maxItems': 9,
    },
    'cabin': {
      'type': 'string',
      'enum': ['economy', 'business'],
    },
  },
  'required': ['from', 'passengers'],
  'additionalProperties': false,
};

final _tool = ToolDefinition(
  name: 'book_flight',
  description: 'Books a flight.',
  parametersSchema: _schema,
  requiresConfirmation: true,
  execute: (_) => 'booked',
);

void main() {
  test('OpenAI Chat Completions', () {
    final json = _tool.toOpenAIJson();
    expect(json, {
      'type': 'function',
      'function': {
        'name': 'book_flight',
        'description': 'Books a flight.',
        'parameters': _schema,
        'strict': false,
      },
    });
    final tool = openai.Tool.fromJson(json);
    expect(tool.function.name, 'book_flight');
    expect(tool.function.parameters, _schema);
    expect(tool.function.strict, isFalse);
    // openai_dart only writes `strict` when true; false is Chat Completions'
    // default anyway. Everything else comes back unchanged.
    expect(tool.toJson(), {
      'type': 'function',
      'function': {...json['function']! as Map}..remove('strict'),
    });
  });

  test('OpenAI Responses API', () {
    final json = _tool.toOpenAIResponsesJson();
    final tool = openai.ResponseTool.fromJson(json);
    expect(tool, isA<openai.FunctionTool>());
    tool as openai.FunctionTool;
    expect(tool.name, 'book_flight');
    expect(tool.parameters, _schema);
    expect(tool.strict, isFalse);
    expect(tool.toJson(), json);
  });

  test('Anthropic (Claude)', () {
    final json = _tool.toAnthropicJson();
    final tool = anthropic.Tool.fromJson(json);
    expect(tool.name, 'book_flight');
    expect(tool.description, 'Books a flight.');
    expect(tool.inputSchema.toJson(), _schema, reason: 'nothing dropped');
    expect(tool.toJson(), json);
  });

  test('MCP', () {
    final json = _tool.toMcpJson();
    final tool = mcp.Tool.fromJson(json);
    expect(tool.name, 'book_flight');
    expect(tool.description, 'Books a flight.');
    expect(tool.inputSchema.toJson(), _schema, reason: 'nothing dropped');
    expect(tool.annotations?.destructiveHint, isTrue);
  });

  test('MCP: tools without requiresConfirmation are not destructive', () {
    final safe = ToolDefinition(
      name: 'get_weather',
      description: 'Gets the weather.',
      parametersSchema: const {'type': 'object', 'properties': {}},
      execute: (_) => 'sunny',
    );
    expect(
      mcp.Tool.fromJson(safe.toMcpJson()).annotations?.destructiveHint,
      isFalse,
    );
  });

  test('Gemini', () {
    expect(_tool.toGeminiJson(), {
      'name': 'book_flight',
      'description': 'Books a flight.',
      'parametersJsonSchema': _schema,
    });
  });

  test('the deprecated toOpenAiJson names still work until 1.0', () {
    // ignore: deprecated_member_use_from_same_package
    expect(_tool.toOpenAiJson(), _tool.toOpenAIJson());
    // ignore: deprecated_member_use_from_same_package
    expect([_tool].toOpenAiResponsesJson(), [_tool].toOpenAIResponsesJson());
  });

  test('lists keep the order of the tools', () {
    final other = ToolDefinition(
      name: 'other',
      description: 'Other.',
      parametersSchema: const {'type': 'object', 'properties': {}},
      execute: (_) => null,
    );
    for (final json in [
      [_tool, other].toOpenAIJson().map((t) => (t['function'] as Map)['name']),
      [_tool, other].toOpenAIResponsesJson().map((t) => t['name']),
      [_tool, other].toAnthropicJson().map((t) => t['name']),
      [_tool, other].toGeminiJson().map((t) => t['name']),
      [_tool, other].toMcpJson().map((t) => t['name']),
    ]) {
      expect(json, ['book_flight', 'other']);
    }
  });
}
