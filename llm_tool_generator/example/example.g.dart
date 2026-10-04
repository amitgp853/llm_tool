// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'example.dart';

// **************************************************************************
// ToolGenerator
// **************************************************************************

final getWeatherTool = ToolDefinition(
  name: "getWeather",
  description: "Gets the current weather for a city.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "city": {"type": "string", "description": "City name, e.g. Kanpur"},
      "celsius": {
        "type": "boolean",
        "description": "Use Celsius instead of Fahrenheit",
      },
    },
    "required": ["city"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => getWeather(
    args["city"] as String,
    celsius: args["celsius"] as bool? ?? true,
  ),
);

final convertCurrencyTool = ToolDefinition(
  name: "convert_currency",
  description: "Converts an amount between two currencies.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "amount": {
        "type": "number",
        "minimum": 0,
        "description": "Amount to convert",
      },
      "from": {
        "type": "string",
        "pattern": "^[A-Z]{3}\$",
        "description": "ISO code to convert from, e.g. USD",
      },
      "to": {
        "type": "string",
        "pattern": "^[A-Z]{3}\$",
        "description": "ISO code to convert to, e.g. INR",
      },
    },
    "required": ["amount", "from", "to"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => convertCurrency(
    (args["amount"] as num).toDouble(),
    args["from"] as String,
    args["to"] as String,
  ),
);

/// Every tool in this file, e.g. to send to an LLM or look up by name.
/// Typed by the tools' common return type, so calling one needs no cast.
final exampleTools = [getWeatherTool, convertCurrencyTool];

/// The @LlmTool methods of [NoteTools] as tools.
extension NoteToolsLlmTools on NoteTools {
  /// Every tool of this [NoteTools], bound to this instance, e.g. to send
  /// to an LLM or look up by name.
  List<ToolDefinition<String?>> get llmTools => [
    ToolDefinition(
      name: "add_note",
      description: "Saves a note for the user.",
      parametersSchema: {
        "type": "object",
        "properties": {
          "text": {
            "type": "string",
            "minLength": 1,
            "maxLength": 200,
            "description": "The note",
          },
        },
        "required": ["text"],
        "additionalProperties": false,
      },
      requiresConfirmation: false,
      execute: (args) => addNote(args["text"] as String),
    ),
    ToolDefinition(
      name: "clear_notes",
      description: "Deletes all of the user's notes.",
      parametersSchema: {
        "type": "object",
        "properties": {},
        "required": [],
        "additionalProperties": false,
      },
      requiresConfirmation: true,
      execute: (args) {
        clearNotes();
        return null;
      },
    ),
  ];
}
