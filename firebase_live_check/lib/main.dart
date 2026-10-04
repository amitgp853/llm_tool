import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'checks.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(home: LiveCheckPage()));
}

class LiveCheckPage extends StatefulWidget {
  const LiveCheckPage({super.key});

  @override
  State<LiveCheckPage> createState() => _LiveCheckPageState();
}

class _LiveCheckPageState extends State<LiveCheckPage> {
  final _results = <CheckResult>[];
  bool _running = false;
  String? _status;

  Future<void> _run({required bool vertexAI, String? only}) async {
    setState(() {
      _results.clear();
      _running = true;
    });
    void report(CheckResult result) {
      // Also printed, so the results can be copied from the console.
      debugPrint(
        '${result.passed ? 'OK  ' : 'FAIL'} ${result.name}\n'
        '     ${result.details}',
      );
      setState(() => _results.add(result));
    }

    void waiting(String message) => setState(() => _status = message);
    void running() => setState(() => _status = null);

    await runChecks(
      'Gemini Developer API',
      FirebaseAI.googleAI(),
      (result) {
        running();
        report(result);
      },
      waiting: waiting,
      only: only,
    );
    if (vertexAI) {
      await runChecks(
        'Vertex AI',
        FirebaseAI.agentPlatform(),
        report,
        waiting: waiting,
        only: only,
      );
    }
    final failed = _results.where((r) => !r.passed).length;
    debugPrint('${_results.length - failed} passed, $failed failed');
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('llm_tool_calling_firebase_ai live check'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: _running ? null : () => _run(vertexAI: false),
                child: const Text('Run (Gemini Developer API)'),
              ),
              PopupMenuButton<String>(
                enabled: !_running,
                tooltip: 'Run one check (Gemini Developer API)',
                onSelected: (name) => _run(vertexAI: false, only: name),
                itemBuilder: (context) => [
                  for (final name in checkNames)
                    PopupMenuItem(value: name, child: Text(name)),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('Run one check ▾'),
                ),
              ),
              OutlinedButton(
                onPressed: _running ? null : () => _run(vertexAI: true),
                child: const Text('Run (+ Vertex AI, needs Blaze plan)'),
              ),
            ],
          ),
        ),
        if (_running) const LinearProgressIndicator(),
        if (_status case final status?)
          Padding(padding: const EdgeInsets.all(8), child: Text(status)),
        Expanded(
          child: ListView(
            children: [
              for (final result in _results)
                ListTile(
                  leading: Icon(
                    result.passed ? Icons.check_circle : Icons.error,
                    color: result.passed ? Colors.green : Colors.red,
                  ),
                  title: Text(result.name),
                  subtitle: SelectableText(result.details),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
