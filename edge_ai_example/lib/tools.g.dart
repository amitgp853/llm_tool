// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tools.dart';

// **************************************************************************
// ToolGenerator
// **************************************************************************

final getTimeTool = ToolDefinition(
  name: "get_time",
  description: "Gets the current date and time on this device.",
  parametersSchema: {
    "type": "object",
    "properties": {},
    "required": [],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => getTime(),
);

/// Every tool in this file, e.g. to send to an LLM or look up by name.
/// Typed by the tools' common return type, so calling one needs no cast.
final allTools = [getTimeTool];

/// The @LlmTool methods of [TodoTools] as tools.
extension TodoToolsLlmTools on TodoTools {
  /// Every tool of this [TodoTools], bound to this instance, e.g. to send
  /// to an LLM or look up by name.
  List<ToolDefinition<String>> get llmTools => [
    ToolDefinition(
      name: "add_todo",
      description: "Adds an item to the user's to-do list.",
      parametersSchema: {
        "type": "object",
        "properties": {
          "item": {
            "type": "string",
            "minLength": 1,
            "maxLength": 100,
            "description": "The to-do item, e.g. Buy milk",
          },
        },
        "required": ["item"],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => addTodo(args["item"] as String),
    ),
    ToolDefinition(
      name: "clear_todos",
      description: "Deletes every item on the user's to-do list.",
      parametersSchema: {
        "type": "object",
        "properties": {},
        "required": [],
        "additionalProperties": false,
      },
      requiresConfirmation: true,
      execute: (args) => clearTodos(),
    ),
  ];
}
