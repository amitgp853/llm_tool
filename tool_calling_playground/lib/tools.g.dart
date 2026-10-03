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
