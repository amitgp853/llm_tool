import 'dart:io';

import 'package:llm_tool/llm_tool.dart';
import 'package:test/test.dart';
import 'package:tool_calling_playground/chess_coach.dart';
import 'package:tool_calling_playground/tools.dart';

void main() {
  // Fails when a schema the LLM sees changes. If the change is intended,
  // delete test/tool_schemas.json and run the tests again.
  test('tool schemas', () {
    final file = File('test/tool_schemas.json');
    final snapshot = toolSchemaSnapshot([
      ...allTools,
      ...ChessCoach('snapshot').llmTools,
    ]);
    if (!file.existsSync()) file.writeAsStringSync(snapshot);
    expect(snapshot, file.readAsStringSync());
  });
}
