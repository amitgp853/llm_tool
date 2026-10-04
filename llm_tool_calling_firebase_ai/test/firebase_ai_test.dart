import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llm_tool_calling_firebase_ai/llm_tool_calling_firebase_ai.dart';

/// The schema llm_tool_calling_generator writes for
/// `bookFlight(String from, List<Passenger> passengers, {Cabin cabin})`.
final _bookFlightSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'from': {'type': 'string', 'description': 'Airport code'},
    'passengers': {
      'type': 'array',
      'items': {
        'type': 'object',
        'description': 'A person on the flight.',
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer'},
          'bags': {'type': 'integer'},
        },
        'required': ['name', 'age'],
        'additionalProperties': false,
      },
    },
    'cabin': {
      'type': 'string',
      'enum': ['economy', 'business'],
    },
    'ratio': {'type': 'number'},
    'vip': {'type': 'boolean'},
  },
  'required': ['from', 'passengers'],
  'additionalProperties': false,
};

ToolDefinition _tool({
  String name = 'bookFlight',
  Map<String, Object?>? schema,
  bool requiresConfirmation = false,
  Object? Function(Map<String, Object?> args)? execute,
}) => ToolDefinition(
  name: name,
  description: 'Books a flight.',
  parametersSchema: schema ?? _bookFlightSchema,
  requiresConfirmation: requiresConfirmation,
  execute: execute ?? (args) => 'booked from ${args['from']}',
);

const _validArgs = <String, Object?>{
  'from': 'DEL',
  'passengers': [
    {'name': 'Asha', 'age': 30},
  ],
};

void main() {
  group('schema conversion', () {
    test('sends the schema as parametersJsonSchema, without '
        'additionalProperties', () {
      expect(_tool().toFunctionDeclaration().toJson(), {
        'name': 'bookFlight',
        'description': 'Books a flight.',
        'parametersJsonSchema': {
          'type': 'object',
          'properties': {
            'from': {'type': 'string', 'description': 'Airport code'},
            'passengers': {
              'type': 'array',
              'items': {
                'type': 'object',
                'description': 'A person on the flight.',
                'properties': {
                  'name': {'type': 'string'},
                  'age': {'type': 'integer'},
                  'bags': {'type': 'integer'},
                },
                'required': ['name', 'age'],
              },
            },
            'cabin': {
              'type': 'string',
              // firebase_ai adds this to every enum it sends.
              'format': 'enum',
              'enum': ['economy', 'business'],
            },
            'ratio': {'type': 'number'},
            'vip': {'type': 'boolean'},
          },
          'required': ['from', 'passengers'],
        },
      });
    });

    test('a tool without parameters', () {
      final json = _tool(
        schema: {'type': 'object', 'properties': <String, Object?>{}},
      ).toFunctionDeclaration().toJson();
      expect(json['name'], 'bookFlight');
      expect(json.toString(), isNot(contains('additionalProperties')));
    });

    test('unsupported hand-written schemas fail clearly', () {
      expect(
        () => toFirebaseJsonSchema({'type': 'null'}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('not supported by the firebase_ai adapter'),
          ),
        ),
      );
      expect(
        () => toFirebaseJsonSchema({'type': 'array'}),
        throwsArgumentError,
      );
    });

    test('toFirebaseAiTool includes every tool', () {
      final tool = [_tool(name: 'one'), _tool(name: 'two')].toFirebaseAiTool();
      expect(tool.autoFunctionDeclarations.map((d) => d.name), ['one', 'two']);
      final declarations = (tool.toJson()['functionDeclarations']! as List)
          .cast<Map>();
      expect(declarations.map((d) => d['name']), ['one', 'two']);
    });
  });

  group('automatic function calling', () {
    test('valid arguments run the tool; the result is wrapped', () async {
      final declaration = _tool().toAutoFunctionDeclaration();
      expect(await declaration.callable(_validArgs), {
        'result': 'booked from DEL',
      });
    });

    test('map results are sent as they are, others made JSON-safe', () async {
      final asMap = _tool(execute: (_) => {'seat': '4A', 'at': DateTime(2026)});
      expect(await asMap.toAutoFunctionDeclaration().callable(_validArgs), {
        'seat': '4A',
        'at': DateTime(2026).toString(),
      });
      final asNull = _tool(execute: (_) => null);
      expect(await asNull.toAutoFunctionDeclaration().callable(_validArgs), {
        'result': null,
      });
    });

    test('invalid arguments are sent back as an error; the tool does not '
        'run', () async {
      var ran = false;
      final declaration = _tool(
        execute: (_) => ran = true,
      ).toAutoFunctionDeclaration();
      expect(
        await declaration.callable({
          'passengers': [
            {'name': 'Asha', 'age': 'thirty'},
          ],
        }),
        {
          'error':
              'Invalid arguments for "bookFlight": from is required; '
              'passengers[0].age must be an integer, got string',
        },
      );
      expect(ran, isFalse);
    });

    group('requiresConfirmation', () {
      test('without a confirm callback, the tool never runs', () async {
        var ran = false;
        final declaration = _tool(
          requiresConfirmation: true,
          execute: (_) => ran = true,
        ).toAutoFunctionDeclaration();
        final response = await declaration.callable(_validArgs);
        expect(response['error'], contains('needs the user\'s confirmation'));
        expect(ran, isFalse);
      });

      test('declined: the tool does not run and the model is told', () async {
        var ran = false;
        final declaration = _tool(
          requiresConfirmation: true,
          execute: (_) => ran = true,
        ).toAutoFunctionDeclaration(confirm: (tool, args) => false);
        expect(await declaration.callable(_validArgs), {
          'error': 'The user declined to run "bookFlight".',
        });
        expect(ran, isFalse);
      });

      test(
        'approved: the tool runs, and confirm saw the tool and args',
        () async {
          ToolDefinition? askedTool;
          Map<String, Object?>? askedArgs;
          final tool = _tool(requiresConfirmation: true);
          final declaration = tool.toAutoFunctionDeclaration(
            confirm: (tool, args) async {
              askedTool = tool;
              askedArgs = args;
              return true;
            },
          );
          expect(await declaration.callable(_validArgs), {
            'result': 'booked from DEL',
          });
          expect(askedTool, same(tool));
          expect(askedArgs, _validArgs);
        },
      );

      test('invalid arguments are rejected before asking the user', () async {
        var asked = false;
        final declaration = _tool(
          requiresConfirmation: true,
        ).toAutoFunctionDeclaration(confirm: (_, _) => asked = true);
        final response = await declaration.callable({'from': 1});
        expect(response['error'], startsWith('Invalid arguments'));
        expect(asked, isFalse);
      });

      test('tools without requiresConfirmation never ask', () async {
        var asked = false;
        await _tool()
            .toAutoFunctionDeclaration(confirm: (_, _) => asked = true)
            .callable(_validArgs);
        expect(asked, isFalse);
      });
    });
  });

  group('toolResponses', () {
    test('uses the user role, which newer Gemini models accept', () {
      final content = toolResponses([
        const FunctionResponse('getWeather', {'result': 'Sunny'}, id: 'c1'),
      ]);
      expect(content.role, 'user');
      expect(content.toJson(), {
        'role': 'user',
        'parts': [
          {
            'functionResponse': {
              'name': 'getWeather',
              'response': {'result': 'Sunny'},
              'id': 'c1',
            },
          },
        ],
      });
    });
  });

  group('duplicate tool names', () {
    final tools = [_tool(name: 'getWeather'), _tool(name: 'getWeather')];
    final error = throwsA(
      isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        'Two tools are named "getWeather". Tool names must be unique; '
            'rename one with @Tool(name: ...).',
      ),
    );

    test('toFirebaseAiTool refuses them', () {
      expect(tools.toFirebaseAiTool, error);
    });

    test('toFunctionDeclarations refuses them', () {
      expect(tools.toFunctionDeclarations, error);
    });

    test('respondTo refuses them', () {
      expect(
        () => tools.respondTo(const FunctionCall('getWeather', _validArgs)),
        error,
      );
    });
  });

  group('respondTo (manual function calling)', () {
    final tools = [
      _tool(),
      _tool(name: 'broken', execute: (_) => throw StateError('db is down')),
    ];

    test('runs the requested tool and keeps the call id', () async {
      final response = await tools.respondTo(
        const FunctionCall('bookFlight', _validArgs, id: 'call-1'),
      );
      expect(response.name, 'bookFlight');
      expect(response.id, 'call-1');
      expect(response.response, {'result': 'booked from DEL'});
    });

    test('unknown tool', () async {
      final response = await tools.respondTo(
        const FunctionCall('cancelFlight', {}),
      );
      expect(response.response, {
        'error': 'There is no tool named "cancelFlight".',
      });
    });

    test('an error thrown by the tool becomes an error response', () async {
      final response = await tools.respondTo(
        const FunctionCall('broken', _validArgs),
      );
      expect(response.response, {'error': 'Bad state: db is down'});
    });

    test('passes confirm through', () async {
      final response = await [_tool(requiresConfirmation: true)].respondTo(
        const FunctionCall('bookFlight', _validArgs),
        confirm: (_, _) => false,
      );
      expect(response.response, {
        'error': 'The user declined to run "bookFlight".',
      });
    });
  });
}
