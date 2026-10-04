// The "Use with your SDK" examples from the README, as code that compiles
// and runs against the real SDKs (no network: the model's tool calls are
// built by hand). If you change one here, change the README too.
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:llm_tool_calling/llm_tool_calling.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;
import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:test/test.dart';

/// Stands in for the generated `allTools`.
final allTools = [
  ToolDefinition(
    name: 'getWeather',
    description: 'Gets the current weather for a city.',
    parametersSchema: const {
      'type': 'object',
      'properties': {
        'city': {'type': 'string'},
      },
      'required': ['city'],
      'additionalProperties': false,
    },
    execute: (args) => 'Sunny, 31°C in ${args['city']}',
  ),
];

// Complete loops, as in the README. Compiled and analyzed, not run: they
// need API keys and the network.

/// Asks OpenAI a question, running every tool it calls, until it answers.
Future<String?> askOpenAi(String question) async {
  final client = openai.OpenAIClient.fromEnvironment(); // OPENAI_API_KEY
  final tools = allTools.toOpenAiJson().map(openai.Tool.fromJson).toList();
  final messages = <openai.ChatMessage>[openai.ChatMessage.user(question)];
  try {
    while (true) {
      final response = await client.chat.completions.create(
        openai.ChatCompletionCreateRequest(
          model: 'gpt-5.5',
          messages: messages,
          tools: tools,
        ),
      );
      if (!response.hasToolCalls) return response.text;

      messages.add(
        openai.ChatMessage.assistant(toolCalls: response.allToolCalls),
      );
      for (final call in response.allToolCalls) {
        final result = await allTools.invoke(
          call.function.name,
          call.function.arguments, // a JSON string; invoke decodes it
        );
        messages.add(
          openai.ChatMessage.tool(
            toolCallId: call.id,
            content: result.toText(),
          ),
        );
      }
    }
  } finally {
    client.close();
  }
}

/// Asks Claude a question, running every tool it calls, until it answers.
Future<String> askClaude(String question) async {
  final client =
      anthropic.AnthropicClient.fromEnvironment(); // ANTHROPIC_API_KEY
  final tools = [
    for (final json in allTools.toAnthropicJson())
      anthropic.ToolDefinition.custom(anthropic.Tool.fromJson(json)),
  ];
  final messages = <anthropic.InputMessage>[
    anthropic.InputMessage.user(question),
  ];
  try {
    while (true) {
      final response = await client.messages.create(
        anthropic.MessageCreateRequest(
          model: 'claude-opus-5-5',
          maxTokens: 16000,
          tools: tools,
          messages: messages,
        ),
      );
      if (!response.hasToolUse) return response.text;

      messages.add(response.toInputMessage());
      final results = <anthropic.InputContentBlock>[];
      for (final toolUse in response.toolUseBlocks) {
        final result = await allTools.invoke(toolUse.name, toolUse.input);
        results.add(
          anthropic.InputContentBlock.toolResultText(
            toolUseId: toolUse.id,
            text: result.toText(),
            isError: result.isError, // lets Claude see the call failed
          ),
        );
      }
      messages.add(anthropic.InputMessage.userBlocks(results));
    }
  } finally {
    client.close();
  }
}

void main() {
  test('OpenAI (openai_dart)', () async {
    // Tools for the request:
    final tools = allTools.toOpenAiJson().map(openai.Tool.fromJson).toList();
    expect(tools.single.function.name, 'getWeather');

    // A tool call from the model (arguments arrive as a JSON string):
    const call = openai.ToolCall(
      id: 'call_1',
      type: 'function',
      function: openai.FunctionCall(
        name: 'getWeather',
        arguments: '{"city": "Pune"}',
      ),
    );

    // Run it and build the message to send back:
    final result = await allTools.invoke(
      call.function.name,
      call.function.arguments,
    );
    final reply = openai.ChatMessage.tool(
      toolCallId: call.id,
      content: result.toText(),
    );
    expect(reply.toJson()['content'], 'Sunny, 31°C in Pune');
  });

  test('Anthropic (anthropic_sdk_dart)', () async {
    final tools = allTools.toAnthropicJson().map(anthropic.Tool.fromJson);
    expect(tools.single.name, 'getWeather');

    // A tool_use block from Claude (input is already a map):
    const toolUse = anthropic.ToolUseBlock(
      id: 'toolu_1',
      name: 'getWeather',
      input: {'city': 'Pune'},
    );

    final result = await allTools.invoke(toolUse.name, toolUse.input);
    final block = anthropic.InputContentBlock.toolResultText(
      toolUseId: toolUse.id,
      text: result.toText(),
      isError: result.isError,
    );
    expect(block.toJson(), containsPair('tool_use_id', 'toolu_1'));
  });

  test('Anthropic: invalid arguments are flagged as is_error', () async {
    final result = await allTools.invoke('getWeather', {'town': 'Pune'});
    final block = anthropic.InputContentBlock.toolResultText(
      toolUseId: 'toolu_2',
      text: result.toText(),
      isError: result.isError,
    );
    expect(block.toJson(), containsPair('is_error', true));
  });

  test('MCP server (mcp_dart)', () async {
    final server = mcp.McpServer(
      const mcp.Implementation(name: 'weather', version: '1.0.0'),
    );

    // Runs a tool for an MCP client.
    Future<mcp.CallToolResult> callTool(
      String name,
      Map<String, dynamic> args,
    ) async {
      final result = await allTools.invoke(name, args);
      return mcp.CallToolResult(
        content: [mcp.TextContent(text: result.toText())],
        isError: result.isError,
      );
    }

    for (final tool in allTools.toMcpJson().map(mcp.Tool.fromJson)) {
      server.registerTool(
        tool.name,
        description: tool.description,
        // Tool schemas are always objects.
        inputSchema: tool.inputSchema as mcp.JsonObject,
        annotations: tool.annotations,
        callback: (args, extra) => callTool(tool.name, args),
      );
    }
    // Then connect it, e.g. `await server.connect(mcp.StdioServerTransport());`

    final ok = await callTool('getWeather', {'city': 'Pune'});
    expect((ok.content.single as mcp.TextContent).text, 'Sunny, 31°C in Pune');
    expect(ok.isError, isFalse);

    final bad = await callTool('getWeather', {});
    expect(bad.isError, isTrue);
  });
}
