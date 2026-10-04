/// Annotate Dart functions with `@LlmTool()` and get LLM tool definitions:
/// JSON schema, argument validation and type-safe dispatch.
///
/// Add `llm_tool_generator` and `build_runner` as dev dependencies
/// to generate a [ToolDefinition] for every [LlmTool] function.
library;

export 'src/annotations.dart';
export 'src/provider_formats.dart';
export 'src/schema_snapshot.dart';
export 'src/schema_utils.dart';
export 'src/schema_validator.dart';
export 'src/tool_argument_exception.dart';
export 'src/tool_definition.dart';
export 'src/tool_result.dart' hide jsonSafe;
