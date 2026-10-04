// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tools.dart';

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
    },
    "required": ["city"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => getWeather(args["city"] as String),
);

final bookFlightTool = ToolDefinition(
  name: "bookFlight",
  description: "Books a flight for one or more passengers.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "from": {
        "type": "string",
        "description": "Departure airport code, e.g. DEL",
      },
      "to": {"type": "string", "description": "Arrival airport code, e.g. BOM"},
      "passengers": {
        "type": "array",
        "items": {
          "type": "object",
          "description": "A person on the flight.",
          "properties": {
            "name": {
              "type": "string",
              "description": "Full name as on the passport.",
            },
            "age": {"type": "integer", "description": "Age in years."},
            "bags": {
              "type": "integer",
              "description": "Number of checked bags.",
            },
          },
          "required": ["name", "age"],
          "additionalProperties": false,
        },
        "description": "Everyone flying",
      },
      "cabin": {
        "type": "string",
        "enum": ["economy", "business"],
        "description": "Cabin class",
      },
    },
    "required": ["from", "to", "passengers"],
    "additionalProperties": false,
  },
  requiresConfirmation: true,
  execute: (args) => bookFlight(
    args["from"] as String,
    args["to"] as String,
    (args["passengers"] as List)
        .map(
          (e) => ((Map json) => Passenger(
            name: json["name"] as String,
            age: (json["age"] as num).toInt(),
            bags: (json["bags"] as num?)?.toInt() ?? 1,
          ))(e as Map),
        )
        .toList(),
    cabin:
        (args["cabin"] == null
            ? null
            : Cabin.values.byName(args["cabin"] as String)) ??
        Cabin.economy,
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
  execute: (args) => deleteFile(args["path"] as String),
);

/// Every tool in this file, e.g. to send to an LLM or look up by name.
final List<ToolDefinition> allTools = [
  getWeatherTool,
  bookFlightTool,
  deleteFileTool,
];
