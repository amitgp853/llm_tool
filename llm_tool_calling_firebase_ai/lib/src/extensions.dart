import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
// firebase_ai has its own Tool class; ours is the annotation, not needed here.
import 'package:llm_tool_calling/llm_tool_calling.dart' hide Tool;

import 'json_schema.dart';

/// Asks the user whether [tool] may run with [args]. Return `true` to run it.
///
/// Only called for tools marked `@Tool(requiresConfirmation: true)`, and only
/// after the arguments passed validation.
typedef ToolConfirmation =
    FutureOr<bool> Function(ToolDefinition tool, Map<String, Object?> args);

/// Converts one tool to firebase_ai declarations.
extension ToolDefinitionFirebaseAi on ToolDefinition {
  /// A declaration for manual function calling: the model asks for the call,
  /// your code runs it, e.g. with [ToolListFirebaseAi.respondTo].
  FunctionDeclaration toFunctionDeclaration() {
    final (:properties, :optional) = objectFields(parametersSchema);
    return FunctionDeclaration(
      name,
      description,
      parameters: properties,
      optionalParameters: optional,
    );
  }

  /// A declaration that firebase_ai's `ChatSession` runs automatically.
  ///
  /// Tools with [ToolDefinition.requiresConfirmation] only run when
  /// [confirm] returns `true`; without [confirm] they never run, and the
  /// model is told why.
  AutoFunctionDeclaration toAutoFunctionDeclaration({
    ToolConfirmation? confirm,
  }) {
    final (:properties, :optional) = objectFields(parametersSchema);
    return AutoFunctionDeclaration(
      name: name,
      description: description,
      parameters: properties,
      optionalParameters: optional,
      callable: (args) => _run(this, args, confirm),
    );
  }
}

/// Converts a list of tools, e.g. the generated `allTools`.
extension ToolListFirebaseAi on Iterable<ToolDefinition> {
  /// A firebase_ai [Tool] whose functions run automatically in a
  /// `ChatSession`. See [ToolDefinitionFirebaseAi.toAutoFunctionDeclaration].
  ///
  /// ```dart
  /// final model = FirebaseAI.googleAI().generativeModel(
  ///   model: 'gemini-2.5-flash',
  ///   tools: [allTools.toFirebaseAiTool(confirm: askUser)],
  /// );
  /// ```
  Tool toFirebaseAiTool({ToolConfirmation? confirm}) =>
      Tool.functionDeclarations([
        for (final tool in this)
          tool.toAutoFunctionDeclaration(confirm: confirm),
      ]);

  /// Declarations for manual function calling, e.g.
  /// `Tool.functionDeclarations(allTools.toFunctionDeclarations())`.
  List<FunctionDeclaration> toFunctionDeclarations() => [
    for (final tool in this) tool.toFunctionDeclaration(),
  ];

  /// Runs the tool the model asked for and returns the response to send back.
  ///
  /// Never throws: unknown tools, invalid arguments, declined confirmations
  /// and errors thrown by the tool become an `error` the model can read.
  Future<FunctionResponse> respondTo(
    FunctionCall call, {
    ToolConfirmation? confirm,
  }) async {
    Map<String, Object?> response;
    final tool = where((tool) => tool.name == call.name).firstOrNull;
    if (tool == null) {
      response = {'error': 'There is no tool named "${call.name}".'};
    } else {
      try {
        response = await _run(tool, call.args, confirm);
      } catch (error) {
        response = {'error': '$error'};
      }
    }
    return FunctionResponse(call.name, response, id: call.id);
  }
}

/// Validates, asks for confirmation if needed, runs, and converts the result
/// to the map firebase_ai sends to the model.
Future<Map<String, Object?>> _run(
  ToolDefinition tool,
  Map<String, Object?> args,
  ToolConfirmation? confirm,
) async {
  // Validate first, so nobody is asked to confirm a call that would fail.
  final errors = validateArguments(tool.parametersSchema, args);
  if (errors.isNotEmpty) {
    return {'error': ToolArgumentException(tool.name, errors).toString()};
  }

  if (tool.requiresConfirmation) {
    if (confirm == null) {
      return {
        'error':
            'The tool "${tool.name}" needs the user\'s confirmation, and this '
            'app has not set that up, so it was not run.',
      };
    }
    if (!await confirm(tool, args)) {
      return {'error': 'The user declined to run "${tool.name}".'};
    }
  }

  return switch (_jsonSafe(await tool.execute(args))) {
    final Map<String, Object?> map => map,
    final value => {'result': value},
  };
}

/// [value] as JSON-encodable data. Unknown objects become their `toString()`.
Object? _jsonSafe(Object? value) => switch (value) {
  null || String() || num() || bool() => value,
  List() => [for (final item in value) _jsonSafe(item)],
  Map() => <String, Object?>{
    for (final MapEntry(:key, :value) in value.entries)
      '$key': _jsonSafe(value),
  },
  _ => value.toString(),
};
