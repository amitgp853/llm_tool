import 'package:llm_tool/llm_tool.dart';
import 'package:test/test.dart';
import 'package:tool_calling_playground/chess_coach.dart';
import 'package:tool_calling_playground/tools.dart';

void main() {
  test('tools run on their own instance', () async {
    final amit = ChessCoach('Amit').llmTools;
    final other = ChessCoach('Other').llmTools;

    await amit.invoke('play_move', '{"move": "e2e4"}');
    final result = await amit.invoke('play_move', {'move': 'e7e5'});
    expect(result.toJson(), {'result': 'Amit played e7e5 (move 2)'});
    expect((await amit.invoke('history', null)).toJson(), {
      'result': 'e2e4 e7e5',
    });
    expect((await other.invoke('history', null)).toJson(), {
      'result': 'No moves yet',
    });
  });

  test('typed: calling a tool needs no cast', () async {
    final String version = await ChessCoach('Amit').llmTools.last({});
    expect(version, 'Stockfish 17');
  });

  test('arguments are validated', () async {
    final result = await ChessCoach('Amit').llmTools.invoke('play_move', {});
    expect(result.isError, isTrue);
    expect(result.toJson(), {
      'error': 'Invalid arguments for "play_move": move is required',
    });
  });

  test('limits are checked before the method runs', () async {
    final coach = ChessCoach('Amit');
    final result = await coach.llmTools.invoke('play_move', {'move': 'Nf3'});
    expect(result.toJson(), {
      'error':
          'Invalid arguments for "play_move": move must match the pattern '
          r'^[a-h][1-8][a-h][1-8][qrbn]?$, got "Nf3"',
    });
    expect(coach.moves, isEmpty);
    expect(coach.llmTools.first.parametersSchema['properties'], {
      'move': {
        'type': 'string',
        'pattern': r'^[a-h][1-8][a-h][1-8][qrbn]?$',
        'description': 'The move in UCI, e.g. e2e4',
      },
    });
  });

  test('requiresConfirmation works on methods', () async {
    final coach = ChessCoach('Amit')..moves.add('e2e4');
    final tools = coach.llmTools;
    final declined = await tools.invoke(
      'resign',
      null,
      confirm: (tool, args) => false,
    );
    expect(declined.isError, isTrue);
    expect(coach.moves, ['e2e4']);

    await tools.invoke('resign', null, confirm: (tool, args) => true);
    expect(coach.moves, isEmpty);
  });

  test('combines with top-level tools and provider formats', () {
    final tools = [...allTools, ...ChessCoach('Amit').llmTools];
    expect(tools.toOpenAIJson(), hasLength(tools.length));
    expect(
      tools.toAnthropicJson().map((t) => t['name']),
      containsAll(['getWeather', 'play_move', 'engineVersion']),
    );
  });
}
