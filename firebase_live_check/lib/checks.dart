import 'package:firebase_ai/firebase_ai.dart';
import 'package:llm_tool_firebase_ai/llm_tool_firebase_ai.dart';

import 'tools.dart';

/// The model every check uses. Change it if your project uses another one.
const modelName = 'gemini-3.8-flash';

/// Pause between checks. The free tier allows 5 requests per minute and each
/// check sends about 2.
const pauseBetweenChecks = Duration(seconds: 30);

typedef CheckResult = ({String name, bool passed, String details});

/// Every check, in the order they run. Pass one as `only` to run just it,
/// e.g. to save free-tier quota (20 requests a day).
const checkNames = [
  'sendMessageWithTools: simple tool',
  'sendMessageWithTools: nested classes, lists, enum (approved)',
  'sendMessageWithTools: declined confirmation does not run',
  'manual: respondTo + toolResponses',
  'firebase_ai automatic calling (fails on 4.0.0, flutterfire#18685)',
];

/// Runs every check (or only the one named [only]) against [ai], reporting
/// each result as it finishes.
/// [waiting] is called before each pause, so the UI can say why it's idle.
Future<void> runChecks(
  String backend,
  FirebaseAI ai,
  void Function(CheckResult result) report, {
  void Function(String message)? waiting,
  String? only,
}) async {
  final checks = <String, Future<String> Function()>{
    checkNames[0]: () => _simple(ai),
    checkNames[1]: () => _nested(ai),
    checkNames[2]: () => _declined(ai),
    checkNames[3]: () => _manual(ai),
    checkNames[4]: () => _firebaseAutomatic(ai),
  }..removeWhere((name, _) => only != null && name != only);
  var first = true;
  for (final MapEntry(key: name, value: check) in checks.entries) {
    if (!first) {
      waiting?.call('Waiting ${pauseBetweenChecks.inSeconds}s (rate limit)');
      await Future<void>.delayed(pauseBetweenChecks);
    }
    first = false;
    try {
      String details;
      try {
        toolCalls.clear();
        details = await check();
      } catch (error) {
        if (!_isTemporary(error)) rethrow;
        // Google was overloaded or rate-limited us: not a real result.
        waiting?.call('Gemini is busy, retrying in 40s');
        await Future<void>.delayed(const Duration(seconds: 40));
        toolCalls.clear();
        details = await check();
      }
      report((name: '$backend / $name', passed: true, details: details));
    } catch (error) {
      // Say whether our tool ran before the failure: it shows which side
      // (our code or the round trip to Gemini) went wrong.
      final ran = toolCalls.isEmpty
          ? 'No tool ran.'
          : 'Tools that ran before the failure: '
                '${toolCalls.map((c) => '${c.tool}${c.args}').join(', ')}.';
      report((
        name: '$backend / $name',
        passed: false,
        details: '$error\n$ran',
      ));
    }
  }
}

/// Whether [error] is a temporary server problem worth one retry.
bool _isTemporary(Object error) {
  final message = '$error';
  return message.contains('[429]') ||
      message.contains('[500]') ||
      message.contains('[503]') ||
      message.contains('high demand') ||
      message.contains('exceeded your current quota');
}

/// Fails the check with [message].
Never _fail(String message) => throw StateError(message);

/// A chat whose tools run through the adapter's own loop.
ChatSession _manualChat(FirebaseAI ai) => ai
    .generativeModel(
      model: modelName,
      tools: [Tool.functionDeclarations(allTools.toFunctionDeclarations())],
    )
    .startChat();

Future<String> _simple(FirebaseAI ai) async {
  final reply = await _manualChat(ai).sendMessageWithTools(
    Content.text('What is the weather in Kanpur? Use the getWeather tool.'),
    allTools,
  );
  if (!toolCalls.any((call) => call.tool == 'getWeather')) {
    _fail('getWeather never ran. Gemini replied: ${reply.text}');
  }
  return 'getWeather ran with ${toolCalls.first.args}. '
      'Gemini replied: ${reply.text}';
}

Future<String> _nested(FirebaseAI ai) async {
  var asked = false;
  final reply = await _manualChat(ai).sendMessageWithTools(
    Content.text(
      'Book a business class flight from DEL to BOM for Asha (age 30) and '
      'Ravi (age 8, no checked bags). Use the bookFlight tool.',
    ),
    allTools,
    confirm: (tool, args) {
      asked = true;
      return true;
    },
  );
  final call = toolCalls.where((call) => call.tool == 'bookFlight').firstOrNull;
  if (call == null) {
    _fail('bookFlight never ran. Gemini replied: ${reply.text}');
  }
  if (!asked) _fail('bookFlight ran without asking for confirmation');

  final passengers = (call.args['passengers']! as List)
      .cast<({String name, int age, int bags})>();
  final ravi = passengers.where((p) => p.name.startsWith('Ravi'));
  if (call.args['cabin'] != Cabin.business ||
      passengers.length != 2 ||
      ravi.isEmpty ||
      ravi.first.age != 8 ||
      ravi.first.bags != 0) {
    _fail('bookFlight ran with unexpected arguments: ${call.args}');
  }
  return 'bookFlight ran with ${call.args}. Gemini replied: ${reply.text}';
}

Future<String> _declined(FirebaseAI ai) async {
  var asked = false;
  final reply = await _manualChat(ai).sendMessageWithTools(
    Content.text('Delete the file /tmp/notes.txt. Use the deleteFile tool.'),
    allTools,
    confirm: (tool, args) {
      asked = true;
      return false;
    },
  );
  if (toolCalls.any((call) => call.tool == 'deleteFile')) {
    _fail('deleteFile ran although the user declined');
  }
  if (!asked) {
    _fail(
      'Inconclusive: Gemini never called deleteFile. It replied: '
      '${reply.text}',
    );
  }
  return 'Declined, so deleteFile did not run. Gemini replied: ${reply.text}';
}

/// The loop written by hand, as the README shows for manual calling.
Future<String> _manual(FirebaseAI ai) async {
  final chat = _manualChat(ai);
  var reply = await chat.sendMessage(
    Content.text('What is the weather in Pune? Use the getWeather tool.'),
  );
  var rounds = 0;
  while (reply.functionCalls.isNotEmpty && rounds++ < 5) {
    final responses = [
      for (final call in reply.functionCalls) await allTools.respondTo(call),
    ];
    reply = await chat.sendMessage(toolResponses(responses));
  }
  if (!toolCalls.any((call) => call.tool == 'getWeather')) {
    _fail('getWeather never ran. Gemini replied: ${reply.text}');
  }
  return 'getWeather ran with ${toolCalls.first.args}. '
      'Gemini replied: ${reply.text}';
}

/// firebase_ai's own automatic loop. firebase_ai 4.0.0 sends tool results
/// with the role `function`, which newer models reject. Fixed in
/// flutterfire#18685, so this should pass once a release includes it.
Future<String> _firebaseAutomatic(FirebaseAI ai) async {
  final chat = ai
      .generativeModel(model: modelName, tools: [allTools.toFirebaseAITool()])
      .startChat();
  final reply = await chat.sendMessage(
    Content.text('What is the weather in Delhi? Use the getWeather tool.'),
  );
  if (!toolCalls.any((call) => call.tool == 'getWeather')) {
    _fail('getWeather never ran. Gemini replied: ${reply.text}');
  }
  return 'firebase_ai automatic calling works now. getWeather ran with '
      '${toolCalls.first.args}. Gemini replied: ${reply.text}';
}
