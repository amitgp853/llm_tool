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
      "amount": {"type": "number", "description": "Amount to convert"},
      "from": {
        "type": "string",
        "description": "ISO code to convert from, e.g. USD",
      },
      "to": {
        "type": "string",
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

final deleteFileTool = ToolDefinition(
  name: "deleteFile",
  description: "Deletes a file from the user's device.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "path": {"type": "string", "description": "Path of the file to delete"},
    },
    "required": ["path"],
    "additionalProperties": false,
  },
  requiresConfirmation: true,
  execute: (args) {
    deleteFile(args["path"] as String);
    return null;
  },
);

/// Every tool in this file, e.g. to send to an LLM or look up by name.
final List<ToolDefinition> exampleTools = [
  getWeatherTool,
  convertCurrencyTool,
  deleteFileTool,
];
