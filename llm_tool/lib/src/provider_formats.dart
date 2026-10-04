import 'dart:convert';

import 'tool_definition.dart';
import 'tool_result.dart';

/// A tool in each provider's JSON format, to pass to that provider's SDK
/// (e.g. its `Tool.fromJson`) or REST API. No SDK is needed.
extension ToolDefinitionFormats on ToolDefinition {
  /// OpenAI Chat Completions (and compatible APIs such as Mistral, Groq or
  /// DeepSeek): `{"type": "function", "function": {...}}`.
  ///
  /// `strict` is `false`: strict mode requires every argument, which tools
  /// with optional parameters can't meet.
  Map<String, Object?> toOpenAIJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parametersSchema,
      'strict': false,
    },
  };

  /// OpenAI Responses API: `{"type": "function", "name": ..., ...}`.
  ///
  /// `strict` is `false` explicitly: when it's left out, the Responses API
  /// may turn the schema strict, which tools with optional parameters can't
  /// meet.
  Map<String, Object?> toOpenAIResponsesJson() => {
    'type': 'function',
    'name': name,
    'description': description,
    'parameters': parametersSchema,
    'strict': false,
  };

  /// Renamed to [toOpenAIJson].
  @Deprecated('Use toOpenAIJson(). Will be removed in 1.0.0.')
  Map<String, Object?> toOpenAiJson() => toOpenAIJson();

  /// Renamed to [toOpenAIResponsesJson].
  @Deprecated('Use toOpenAIResponsesJson(). Will be removed in 1.0.0.')
  Map<String, Object?> toOpenAiResponsesJson() => toOpenAIResponsesJson();

  /// Anthropic (Claude) Messages API: `{"name", "description",
  /// "input_schema"}`.
  Map<String, Object?> toAnthropicJson() => {
    'name': name,
    'description': description,
    'input_schema': parametersSchema,
  };

  /// Gemini function declaration: `{"name", "description",
  /// "parametersJsonSchema"}`, the field that accepts full JSON Schema
  /// (Gemini 2.5 and later).
  Map<String, Object?> toGeminiJson() => {
    'name': name,
    'description': description,
    'parametersJsonSchema': parametersSchema,
  };

  /// Model Context Protocol tool: `{"name", "description", "inputSchema",
  /// "annotations"}`. `destructiveHint` follows [requiresConfirmation], so
  /// MCP clients know which tools need care.
  Map<String, Object?> toMcpJson() => {
    'name': name,
    'description': description,
    'inputSchema': parametersSchema,
    'annotations': {'destructiveHint': requiresConfirmation},
  };
}

/// The same formats for a list of tools, e.g. the generated `allTools`, and
/// running a model's call by the tool name it sent.
extension ToolListFormats on Iterable<ToolDefinition> {
  /// See [ToolDefinitionFormats.toOpenAIJson].
  List<Map<String, Object?>> toOpenAIJson() =>
      _unique([for (final tool in this) tool.toOpenAIJson()]);

  /// See [ToolDefinitionFormats.toOpenAIResponsesJson].
  List<Map<String, Object?>> toOpenAIResponsesJson() =>
      _unique([for (final tool in this) tool.toOpenAIResponsesJson()]);

  /// Renamed to [toOpenAIJson].
  @Deprecated('Use toOpenAIJson(). Will be removed in 1.0.0.')
  List<Map<String, Object?>> toOpenAiJson() => toOpenAIJson();

  /// Renamed to [toOpenAIResponsesJson].
  @Deprecated('Use toOpenAIResponsesJson(). Will be removed in 1.0.0.')
  List<Map<String, Object?>> toOpenAiResponsesJson() => toOpenAIResponsesJson();

  /// See [ToolDefinitionFormats.toAnthropicJson].
  List<Map<String, Object?>> toAnthropicJson() =>
      _unique([for (final tool in this) tool.toAnthropicJson()]);

  /// See [ToolDefinitionFormats.toGeminiJson].
  List<Map<String, Object?>> toGeminiJson() =>
      _unique([for (final tool in this) tool.toGeminiJson()]);

  /// See [ToolDefinitionFormats.toMcpJson].
  List<Map<String, Object?>> toMcpJson() =>
      _unique([for (final tool in this) tool.toMcpJson()]);

  /// Runs the tool named [name] with [arguments] and returns what to send
  /// back to the model. Never throws for problems with the call.
  ///
  /// [arguments] can be a map (Claude, Gemini, MCP), a JSON string (OpenAI)
  /// or null for no arguments. An unknown tool or invalid JSON gives a
  /// failure the model can read; see [ToolDefinition.invoke] for the rest.
  ///
  /// Throws an [ArgumentError] if two tools have the same name, because the
  /// model couldn't tell them apart.
  Future<ToolResult> invoke(
    String name,
    Object? arguments, {
    ToolConfirmation? confirm,
  }) async {
    _unique(this);
    final tool = where((tool) => tool.name == name).firstOrNull;
    if (tool == null) {
      return ToolResult.failure('There is no tool named "$name".');
    }

    Object? decoded = arguments;
    if (arguments is String) {
      try {
        decoded = arguments.trim().isEmpty ? null : jsonDecode(arguments);
      } on FormatException {
        return ToolResult.failure(
          'The arguments for "$name" are not valid JSON: $arguments',
        );
      }
    }
    return switch (decoded) {
      null => tool.invoke(const {}, confirm: confirm),
      final Map<Object?, Object?> map => tool.invoke(
        map.cast<String, Object?>(),
        confirm: confirm,
      ),
      _ => ToolResult.failure(
        'The arguments for "$name" must be a JSON object, got $decoded',
      ),
    };
  }

  /// Returns [items] after checking that no two tools share a name.
  T _unique<T>(T items) {
    final seen = <String>{};
    for (final tool in this) {
      if (!seen.add(tool.name)) {
        throw ArgumentError(
          'Two tools are named "${tool.name}". Tool names must be unique; '
          'rename one with @Tool(name: ...).',
        );
      }
    }
    return items;
  }
}
