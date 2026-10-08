/// The build_runner builder for `llm_tool`.
///
/// You don't use this library directly: add `llm_tool_generator`
/// and `build_runner` as dev dependencies and run
/// `dart run build_runner build`.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/tool_generator.dart';

/// Creates the builder that turns `@LlmTool()` functions into `ToolDefinition`s
/// in each library's shared `.g.dart` part. Referenced from `build.yaml`.
Builder toolBuilder(BuilderOptions options) =>
    SharedPartBuilder([ToolGenerator()], 'llm_tool');
