import 'package:llm_tool/llm_tool.dart';
import 'package:test/test.dart';

const _schema = <String, Object?>{
  'type': 'object',
  'properties': {
    'city': {'type': 'string'},
  },
  'required': ['city'],
  'additionalProperties': false,
};

ToolDefinition _tool({
  String name = 'getWeather',
  bool requiresConfirmation = false,
  Object? Function(Map<String, Object?> args)? execute,
}) => ToolDefinition(
  name: name,
  description: 'Gets the weather.',
  parametersSchema: _schema,
  requiresConfirmation: requiresConfirmation,
  execute: execute ?? (args) => 'Sunny in ${args['city']}',
);

void main() {
  group('ToolDefinition.invoke', () {
    test('runs the tool and returns its result', () async {
      final result = await _tool().invoke({'city': 'Pune'});
      expect(result.isError, isFalse);
      expect(result.value, 'Sunny in Pune');
      expect(result.toText(), 'Sunny in Pune');
      expect(result.toJson(), {'result': 'Sunny in Pune'});
    });

    test('results are made JSON-safe', () async {
      final result = await _tool(
        execute: (_) => {
          'at': DateTime(2026),
          'list': [1, Uri.parse('https://a.b')],
        },
      ).invoke({'city': 'Pune'});
      expect(result.value, {
        'at': DateTime(2026).toString(),
        'list': [1, 'https://a.b'],
      });
      expect(result.toJson(), result.value, reason: 'maps are sent as is');
      expect(
        result.toText(),
        '{"at":"${DateTime(2026)}","list":[1,"https://a.b"]}',
      );
    });

    test('a null result', () async {
      final result = await _tool(execute: (_) => null).invoke({'city': 'Pune'});
      expect(result.toJson(), {'result': null});
      expect(result.toText(), 'null');
    });

    test('invalid arguments: a failure for the model, the tool does not '
        'run', () async {
      var ran = false;
      final result = await _tool(execute: (_) => ran = true).invoke({});
      expect(result.isError, isTrue);
      expect(
        result.error,
        'Invalid arguments for "getWeather": city is required',
      );
      expect(result.toJson(), {'error': result.error});
      expect(result.toText(), result.error);
      expect(ran, isFalse);
    });

    test('an exception from the tool becomes a failure', () async {
      final result = await _tool(
        execute: (_) => throw StateError('server down'),
      ).invoke({'city': 'Pune'});
      expect(result.error, 'Bad state: server down');
    });

    group('requiresConfirmation', () {
      test('without confirm, the tool never runs', () async {
        var ran = false;
        final result = await _tool(
          requiresConfirmation: true,
          execute: (_) => ran = true,
        ).invoke({'city': 'Pune'});
        expect(result.error, contains('needs the user\'s confirmation'));
        expect(ran, isFalse);
      });

      test('declined: the tool does not run', () async {
        var ran = false;
        final result = await _tool(
          requiresConfirmation: true,
          execute: (_) => ran = true,
        ).invoke({'city': 'Pune'}, confirm: (_, _) => false);
        expect(result.error, 'The user declined to run "getWeather".');
        expect(ran, isFalse);
      });

      test('approved: runs, and confirm saw the tool and args', () async {
        ToolDefinition? askedTool;
        Map<String, Object?>? askedArgs;
        final tool = _tool(requiresConfirmation: true);
        final result = await tool.invoke(
          {'city': 'Pune'},
          confirm: (tool, args) async {
            askedTool = tool;
            askedArgs = args;
            return true;
          },
        );
        expect(result.value, 'Sunny in Pune');
        expect(askedTool, same(tool));
        expect(askedArgs, {'city': 'Pune'});
      });

      test('invalid arguments are rejected before asking', () async {
        var asked = false;
        final result = await _tool(
          requiresConfirmation: true,
        ).invoke({}, confirm: (_, _) => asked = true);
        expect(result.isError, isTrue);
        expect(asked, isFalse);
      });

      test('other tools never ask', () async {
        var asked = false;
        await _tool().invoke({'city': 'Pune'}, confirm: (_, _) => asked = true);
        expect(asked, isFalse);
      });
    });
  });

  group('invoke on a list of tools', () {
    final tools = [_tool(), _tool(name: 'other')];

    test('finds the tool by name; map arguments', () async {
      final result = await tools.invoke('getWeather', {'city': 'Pune'});
      expect(result.value, 'Sunny in Pune');
    });

    test('JSON string arguments, as OpenAI sends them', () async {
      final result = await tools.invoke('getWeather', '{"city": "Pune"}');
      expect(result.value, 'Sunny in Pune');
    });

    test('null or empty arguments mean no arguments', () async {
      final noArgs = ToolDefinition(
        name: 'now',
        description: 'The time.',
        parametersSchema: const {'type': 'object', 'properties': {}},
        execute: (_) => 'noon',
      );
      expect((await [noArgs].invoke('now', null)).value, 'noon');
      expect((await [noArgs].invoke('now', '')).value, 'noon');
    });

    test('unknown tool', () async {
      final result = await tools.invoke('cancelFlight', {});
      expect(result.error, 'There is no tool named "cancelFlight".');
    });

    test('invalid JSON', () async {
      final result = await tools.invoke('getWeather', '{"city": ');
      expect(
        result.error,
        'The arguments for "getWeather" are not valid JSON: {"city": ',
      );
    });

    test('JSON that is not an object', () async {
      final result = await tools.invoke('getWeather', '[1, 2]');
      expect(
        result.error,
        'The arguments for "getWeather" must be a JSON object, got [1, 2]',
      );
    });

    test('passes confirm through', () async {
      final result = await [
        _tool(requiresConfirmation: true),
      ].invoke('getWeather', {'city': 'Pune'}, confirm: (_, _) => false);
      expect(result.error, 'The user declined to run "getWeather".');
    });

    test('duplicate names are a setup error', () {
      final duplicates = [_tool(), _tool()];
      final error = throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Two tools are named "getWeather"'),
        ),
      );
      expect(() => duplicates.invoke('getWeather', {}), error);
      expect(duplicates.toOpenAIJson, error);
    });
  });

  group('typed ToolDefinition<T>', () {
    test('T is inferred from execute; call returns T without a cast', () async {
      final tool = ToolDefinition(
        name: 'count',
        description: 'Counts.',
        parametersSchema: const {'type': 'object', 'properties': {}},
        execute: (_) async => 42,
      );
      expect(tool, isA<ToolDefinition<int>>());
      final int value = await tool({}); // compiles only if call returns int
      expect(value, 42);
    });

    test('a list of tools gets their common return type', () async {
      final tools = [
        ToolDefinition(
          name: 'a',
          description: 'A.',
          parametersSchema: const {'type': 'object', 'properties': {}},
          execute: (_) => const _Analyze(),
        ),
        ToolDefinition(
          name: 'b',
          description: 'B.',
          parametersSchema: const {'type': 'object', 'properties': {}},
          execute: (_) => const _Stats(),
        ),
      ];
      expect(tools, isA<List<ToolDefinition<_Command>>>());
      final _Command command = await tools.first({}); // no cast needed
      expect(command, isA<_Analyze>());
      // The list methods still work on typed lists:
      expect((await tools.invoke('b', {})).isError, isFalse);
    });
  });
}

sealed class _Command {
  const _Command();
}

final class _Analyze extends _Command {
  const _Analyze();
}

final class _Stats extends _Command {
  const _Stats();
}
