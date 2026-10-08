// On-device tool calling: llm_tool tools, run by Gemma 4 E2B through
// flutter_edge_ai. Nothing leaves the phone after the model download.
import 'package:flutter/material.dart';
// Prefixed, as the llm_tool README suggests for SDKs: it shows which names
// (Tool, Message...) come from flutter_edge_ai.
import 'package:flutter_edge_ai/flutter_edge_ai.dart' as edge;
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:llm_tool/llm_tool.dart';

import 'tools.dart';

const _gemma4E2B =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await edge.FlutterEdgeAi.initialize(
    inferenceEngines: const [LiteRtLmEngine()],
  );
  runApp(const MaterialApp(home: ChatScreen()));
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _todoTools = TodoTools();
  late final _tools = [...allTools, ..._todoTools.llmTools];

  final _input = TextEditingController();
  final _messages = <(String who, String text)>[];
  edge.InferenceChat? _chat;
  String _status = 'Starting...';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadModel().catchError(
      (Object e) => setState(() => _status = 'Error: $e'),
    );
  }

  Future<void> _loadModel() async {
    // Downloads 2.4 GB the first time; later runs skip straight to loading.
    await edge.FlutterEdgeAi.installModel(
      modelType: edge.ModelType.gemma4,
      fileType: edge.ModelFileType.litertlm,
    ).fromNetwork(_gemma4E2B).withProgress((percent) {
      setState(() => _status = 'Downloading Gemma 4 E2B: $percent%');
    }).install();

    final model = await edge.FlutterEdgeAi.getActiveModel(maxTokens: 4096);
    final chat = await model.createChat(
      modelType: edge.ModelType.gemma4,
      supportsFunctionCalls: true,
      tools: [
        for (final tool in _tools)
          edge.Tool(
            name: tool.name,
            description: tool.description,
            parameters: tool.parametersSchema,
          ),
      ],
    );
    setState(() {
      _chat = chat;
      _status = 'Ask me to add a to-do, clear the list, or tell the time.';
    });
  }

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty || _chat == null || _busy) return;
    _input.clear();
    setState(() {
      _busy = true;
      _messages
        ..add(('You', question))
        ..add(('Gemma', ''));
    });

    try {
      await _chat!.addQueryChunk(
        edge.Message.text(text: question, isUser: true),
      );
      await _reply();
    } catch (e) {
      setState(() => _messages.last = ('Gemma', 'Error: $e'));
    } finally {
      setState(() => _busy = false);
    }
  }

  /// Streams the model's answer, running every tool it calls on the way.
  Future<void> _reply() async {
    final reply = StringBuffer();
    await for (final response in _chat!.generateChatResponseWithTools(
      // Validates the arguments, asks for confirmation if the tool needs it,
      // runs it, and turns any problem into an error the model can read.
      onToolCall: (call) async {
        final result = await _tools.invoke(
          call.name,
          call.args,
          confirm: _confirm,
        );
        setState(() {}); // the to-do list may have changed
        return result.toJson();
      },
    )) {
      if (response is edge.TextResponse) {
        reply.write(response.token);
        setState(() => _messages.last = ('Gemma', reply.toString()));
      }
    }
  }

  /// Asks the user before a tool marked `requiresConfirmation` runs.
  Future<bool> _confirm(ToolDefinition tool, Map<String, Object?> args) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow this action?'),
        content: Text('The assistant wants to run "${tool.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return approved ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final todos = _todoTools.todos;
    return Scaffold(
      appBar: AppBar(title: const Text('On-device tools')),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.checklist),
            title: Text(todos.isEmpty ? 'No to-dos' : todos.join(' · ')),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_status, style: Theme.of(context).textTheme.bodySmall),
                for (final (who, text) in _messages)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('$who: $text'),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _input,
                enabled: _chat != null && !_busy,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
