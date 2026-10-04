import 'package:llm_tool/llm_tool.dart';

part 'chess_coach.g.dart';

/// Tools that share state: they all work on this coach's game.
@LlmToolset()
class ChessCoach {
  ChessCoach(this.player);

  final String player;
  final moves = <String>[];

  /// Plays a move in the current game.
  @LlmTool(name: 'play_move')
  String playMove(@Param('The move in UCI, e.g. e2e4') String move) {
    moves.add(move);
    return '$player played $move (move ${moves.length})';
  }

  /// Lists the moves played so far.
  @LlmTool()
  Future<String> history() async =>
      moves.isEmpty ? 'No moves yet' : moves.join(' ');

  /// Starts a new game, losing the current one.
  @LlmTool(requiresConfirmation: true)
  String resign() {
    moves.clear();
    return '$player resigned';
  }

  /// The chess engine's version.
  @LlmTool()
  static String engineVersion() => 'Stockfish 17';
}
