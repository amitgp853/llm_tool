// Live check: sends a generated tool to real LLM providers and checks that
// each one (1) accepts the schema, (2) calls the tool, and (3) sends
// arguments that pass validation and run the function.
//
// Set a key for each provider you want to check, then run:
//   dart run bin/provider_check.dart
//
//   OPENAI_API_KEY     [OPENAI_MODEL]     default gpt-5-mini
//   ANTHROPIC_API_KEY  [ANTHROPIC_MODEL]  default claude-opus-5-5
//   GEMINI_API_KEY     [GEMINI_MODEL]     default gemini-2.5-flash
//   MISTRAL_API_KEY    [MISTRAL_MODEL]    default mistral-small-latest
//   DEEPSEEK_API_KEY   [DEEPSEEK_MODEL]   default deepseek-chat
//   GROQ_API_KEY       GROQ_MODEL         (required, e.g. a Llama model id)
//   XAI_API_KEY        XAI_MODEL          (required)
//   OLLAMA_MODEL       [OLLAMA_URL]       local, e.g. qwen3; default URL
//                                         http://localhost:11434
//
// Each check makes one small request, billed to your account.
import 'dart:convert';
import 'dart:io';

import 'package:llm_tool_calling/llm_tool_calling.dart';
import 'package:tool_calling_playground/tools.dart';

const _prompt =
    'Book a business class flight from DEL to BOM for Asha (age 30) and '
    'Ravi (age 8, no checked bags). Use the bookFlight tool.';

final ToolDefinition _tool = bookFlightTool;

/// Sends [_prompt] with [_tool] and returns the arguments of the tool call.
typedef _Check = Future<Map<String, Object?>> Function(String model);

Future<void> main() async {
  final env = Platform.environment;
  final checks = <(String, String?, _Check)>[
    (
      'OpenAI',
      _model('OPENAI', 'gpt-5-mini'),
      _openAiCompatible('https://api.openai.com/v1', env['OPENAI_API_KEY']),
    ),
    ('Anthropic (Claude)', _model('ANTHROPIC', 'claude-opus-5-5'), _anthropic),
    ('Google Gemini', _model('GEMINI', 'gemini-2.5-flash'), _gemini),
    (
      'Mistral',
      _model('MISTRAL', 'mistral-small-latest'),
      _openAiCompatible(
        'https://api.mistral.ai/v1',
        env['MISTRAL_API_KEY'],
        toolChoice: 'any',
      ),
    ),
    (
      'DeepSeek',
      _model('DEEPSEEK', 'deepseek-chat'),
      _openAiCompatible('https://api.deepseek.com', env['DEEPSEEK_API_KEY']),
    ),
    (
      'Groq',
      env['GROQ_MODEL'],
      _openAiCompatible('https://api.groq.com/openai/v1', env['GROQ_API_KEY']),
    ),
    (
      'xAI (Grok)',
      env['XAI_MODEL'],
      _openAiCompatible('https://api.x.ai/v1', env['XAI_API_KEY']),
    ),
    ('Ollama (local)', env['OLLAMA_MODEL'], _ollama),
  ];

  final keys = {
    'OpenAI': env['OPENAI_API_KEY'],
    'Anthropic (Claude)': env['ANTHROPIC_API_KEY'],
    'Google Gemini': env['GEMINI_API_KEY'],
    'Mistral': env['MISTRAL_API_KEY'],
    'DeepSeek': env['DEEPSEEK_API_KEY'],
    'Groq': env['GROQ_API_KEY'],
    'xAI (Grok)': env['XAI_API_KEY'],
    'Ollama (local)': 'local',
  };

  var failures = 0;
  var ran = 0;
  for (final (provider, model, check) in checks) {
    if (keys[provider] == null || model == null) {
      print('-  $provider: skipped (no key or model set)');
      continue;
    }
    ran++;
    try {
      final args = await check(model);
      final result = await _tool(args); // validates, then runs the function
      print(
        'OK $provider ($model)\n   args:   ${jsonEncode(args)}\n'
        '   result: $result',
      );
    } on ToolArgumentException catch (e) {
      failures++;
      print('X  $provider ($model): called the tool, but $e');
    } catch (e) {
      failures++;
      print('X  $provider ($model): $e');
    }
  }
  print('\n$ran checked, ${ran - failures} passed, $failures failed.');
  exitCode = failures == 0 ? 0 : 1;
}

String? _model(String prefix, String fallback) =>
    Platform.environment['${prefix}_MODEL'] ?? fallback;

/// OpenAI Chat Completions, and the many APIs that copy its shape.
_Check _openAiCompatible(
  String baseUrl,
  String? apiKey, {
  Object? toolChoice,
}) => (model) async {
  final response = await _post(
    '$baseUrl/chat/completions',
    {'authorization': 'Bearer $apiKey'},
    {
      'model': model,
      'messages': [
        {'role': 'user', 'content': _prompt},
      ],
      'tools': [
        {
          'type': 'function',
          'function': {
            'name': _tool.name,
            'description': _tool.description,
            'parameters': _tool.parametersSchema,
          },
        },
      ],
      'tool_choice':
          toolChoice ??
          {
            'type': 'function',
            'function': {'name': _tool.name},
          },
    },
  );
  final message = (response['choices'] as List).first['message'] as Map;
  final calls = message['tool_calls'] as List?;
  if (calls == null || calls.isEmpty) throw 'no tool call: $message';
  final arguments = (calls.first as Map)['function']['arguments'];
  // OpenAI sends arguments as a JSON string; some compatible APIs send a map.
  return (arguments is String ? jsonDecode(arguments) : arguments)
      as Map<String, Object?>;
};

/// Anthropic Messages API. Current models reject forced tool choice, so this
/// uses `auto` and names the tool in the prompt.
Future<Map<String, Object?>> _anthropic(String model) async {
  final response = await _post(
    'https://api.anthropic.com/v1/messages',
    {
      'x-api-key': Platform.environment['ANTHROPIC_API_KEY']!,
      'anthropic-version': '2023-06-01',
      // Retries on another model if a safety classifier declines.
      'anthropic-beta': 'server-side-fallback-2026-07-01',
    },
    {
      'model': model,
      'max_tokens': 16000,
      'fallbacks': 'default',
      'tools': [
        {
          'name': _tool.name,
          'description': _tool.description,
          'input_schema': _tool.parametersSchema,
        },
      ],
      'tool_choice': {'type': 'auto'},
      'messages': [
        {'role': 'user', 'content': _prompt},
      ],
    },
  );
  if (response['stop_reason'] == 'refusal') throw 'refused: $response';
  for (final block in response['content'] as List) {
    if (block is Map && block['type'] == 'tool_use') {
      return (block['input'] as Map).cast<String, Object?>();
    }
  }
  throw 'no tool call: ${response['content']}';
}

/// Gemini API. `parametersJsonSchema` accepts full JSON Schema, including
/// `additionalProperties`; the older `parameters` field does not.
Future<Map<String, Object?>> _gemini(String model) async {
  final response = await _post(
    'https://generativelanguage.googleapis.com/v1beta/models/'
    '$model:generateContent',
    {'x-goog-api-key': Platform.environment['GEMINI_API_KEY']!},
    {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': _prompt},
          ],
        },
      ],
      'tools': [
        {
          'functionDeclarations': [
            {
              'name': _tool.name,
              'description': _tool.description,
              'parametersJsonSchema': _tool.parametersSchema,
            },
          ],
        },
      ],
      'toolConfig': {
        'functionCallingConfig': {
          'mode': 'ANY',
          'allowedFunctionNames': [_tool.name],
        },
      },
    },
  );
  final parts =
      ((response['candidates'] as List).first['content'] as Map)['parts']
          as List;
  for (final part in parts) {
    if (part is Map && part['functionCall'] != null) {
      return ((part['functionCall'] as Map)['args'] as Map)
          .cast<String, Object?>();
    }
  }
  throw 'no tool call: $parts';
}

/// Ollama's local chat API. Arguments arrive as a map.
Future<Map<String, Object?>> _ollama(String model) async {
  final url = Platform.environment['OLLAMA_URL'] ?? 'http://localhost:11434';
  final response = await _post('$url/api/chat', {}, {
    'model': model,
    'stream': false,
    'messages': [
      {'role': 'user', 'content': _prompt},
    ],
    'tools': [
      {
        'type': 'function',
        'function': {
          'name': _tool.name,
          'description': _tool.description,
          'parameters': _tool.parametersSchema,
        },
      },
    ],
  });
  final calls = (response['message'] as Map)['tool_calls'] as List?;
  if (calls == null || calls.isEmpty) throw 'no tool call: $response';
  return ((calls.first as Map)['function']['arguments'] as Map)
      .cast<String, Object?>();
}

/// POSTs [body] as JSON and returns the decoded response, or throws with the
/// provider's error message (e.g. a schema it rejected).
Future<Map<String, Object?>> _post(
  String url,
  Map<String, String> headers,
  Map<String, Object?> body,
) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;
    headers.forEach(request.headers.set);
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw 'HTTP ${response.statusCode}: $text';
    }
    return jsonDecode(text) as Map<String, Object?>;
  } finally {
    client.close();
  }
}
