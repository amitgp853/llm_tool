// Offline checks: no Firebase project or network needed. The live checks
// run in the app (see README.md).
import 'package:firebase_live_check/tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llm_tool_firebase_ai/llm_tool_firebase_ai.dart';

void main() {
  test('every generated tool converts to firebase_ai', () {
    expect(allTools.map((tool) => tool.name), [
      'getWeather',
      'bookFlight',
      'deleteFile',
    ]);
    final declarations = allTools.toFunctionDeclarations();
    expect(declarations, hasLength(3));
    expect(allTools.toFirebaseAITool().autoFunctionDeclarations, hasLength(3));
  });
}
