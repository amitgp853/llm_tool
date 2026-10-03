import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/tool_generator.dart';

Builder toolBuilder(BuilderOptions options) =>
    SharedPartBuilder([ToolGenerator()], 'llm_tool_calling');
