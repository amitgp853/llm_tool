// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chess_coach.dart';

// **************************************************************************
// ToolGenerator
// **************************************************************************

/// The @LlmTool methods of [ChessCoach] as tools.
extension ChessCoachLlmTools on ChessCoach {
  /// Every tool of this [ChessCoach], bound to this instance, e.g. to send
  /// to an LLM or look up by name.
  List<ToolDefinition<String>> get llmTools => [
    ToolDefinition(
      name: "play_move",
      description: "Plays a move in the current game.",
      parametersSchema: {
        "type": "object",
        "properties": {
          "move": {
            "type": "string",
            "description": "The move in UCI, e.g. e2e4",
          },
        },
        "required": ["move"],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => playMove(args["move"] as String),
    ),
    ToolDefinition(
      name: "history",
      description: "Lists the moves played so far.",
      parametersSchema: {
        "type": "object",
        "properties": {},
        "required": [],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => history(),
    ),
    ToolDefinition(
      name: "resign",
      description: "Starts a new game, losing the current one.",
      parametersSchema: {
        "type": "object",
        "properties": {},
        "required": [],
        "additionalProperties": false,
      },
      requiresConfirmation: true,
      execute: (args) => resign(),
    ),
    ToolDefinition(
      name: "engineVersion",
      description: "The chess engine's version.",
      parametersSchema: {
        "type": "object",
        "properties": {},
        "required": [],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => ChessCoach.engineVersion(),
    ),
  ];
}
