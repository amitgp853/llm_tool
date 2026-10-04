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

final convertTemperatureTool = ToolDefinition(
  name: "convertTemperature",
  description: "Converts a temperature between units.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "value": {"type": "number", "description": "The temperature to convert"},
      "from": {
        "type": "string",
        "enum": ["celsius", "fahrenheit", "kelvin"],
        "description": "Unit to convert from",
      },
      "to": {
        "type": "string",
        "enum": ["celsius", "fahrenheit", "kelvin"],
        "description": "Unit to convert to",
      },
    },
    "required": ["value", "from"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => convertTemperature(
    (args["value"] as num).toDouble(),
    TemperatureUnit.values.byName(args["from"] as String),
    to:
        (args["to"] == null
            ? null
            : TemperatureUnit.values.byName(args["to"] as String)) ??
        TemperatureUnit.celsius,
  ),
);

final averageTemperatureTool = ToolDefinition(
  name: "averageTemperature",
  description:
      "Averages a list of temperatures, converting each to one unit first.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "readings": {
        "type": "array",
        "items": {"type": "number"},
        "description": "Readings to average",
      },
      "units": {
        "type": "array",
        "items": {
          "type": "string",
          "enum": ["celsius", "fahrenheit", "kelvin"],
        },
        "description": "Unit of each reading, same order as readings",
      },
    },
    "required": ["readings"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => averageTemperature(
    (args["readings"] as List).map((e) => (e as num).toDouble()).toList(),
    units: (args["units"] == null
        ? null
        : (args["units"] as List)
              .map((e) => TemperatureUnit.values.byName(e as String))
              .toList()),
  ),
);

final bookFlightTool = ToolDefinition(
  name: "bookFlight",
  description: "Books a flight and returns a confirmation summary.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "booking": {
        "type": "object",
        "description": "One flight booking request.",
        "properties": {
          "from": {
            "type": "string",
            "description": "Departure airport code, e.g. DEL.",
          },
          "to": {
            "type": "string",
            "description": "Arrival airport code, e.g. BOM.",
          },
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
                "age": {"type": "integer"},
                "bags": {"type": "integer", "description": "Checked bags."},
              },
              "required": ["name", "age"],
              "additionalProperties": false,
            },
          },
          "cabin": {
            "type": "string",
            "enum": ["economy", "business"],
          },
        },
        "required": ["from", "to", "passengers"],
        "additionalProperties": false,
      },
    },
    "required": ["booking"],
    "additionalProperties": false,
  },
  requiresConfirmation: true,
  execute: (args) => bookFlight(
    ((Map json) => models.Booking(
      from: json["from"] as String,
      to: json["to"] as String,
      passengers: (json["passengers"] as List)
          .map(
            (e) => ((Map json) => models.Passenger(
              name: json["name"] as String,
              age: (json["age"] as num).toInt(),
              bags: (json["bags"] as num?)?.toInt() ?? 1,
            ))(e as Map),
          )
          .toList(),
      cabin:
          (json["cabin"] == null
              ? null
              : models.Cabin.values.byName(json["cabin"] as String)) ??
          models.Cabin.economy,
    ))(args["booking"] as Map),
  ),
);

final getMoveTool = ToolDefinition(
  name: "get_move",
  description: "Gets one move of a game by its number.",
  parametersSchema: {
    "type": "object",
    "properties": {
      "game_id": {"type": "integer", "description": "A game id"},
      "move_number": {"type": "integer", "description": "Move number"},
      "with_eval": {"type": "boolean", "description": "Include the evaluation"},
    },
    "required": ["game_id", "move_number"],
    "additionalProperties": false,
  },
  requiresConfirmation: false,
  execute: (args) => getMove(
    (args["game_id"] as num).toInt(),
    (args["move_number"] as num).toInt(),
    withEval: args["with_eval"] as bool? ?? false,
  ),
);

/// Every tool in this file, e.g. to send to an LLM or look up by name.
final List<ToolDefinition> allTools = [
  getWeatherTool,
  convertTemperatureTool,
  averageTemperatureTool,
  bookFlightTool,
  getMoveTool,
];
