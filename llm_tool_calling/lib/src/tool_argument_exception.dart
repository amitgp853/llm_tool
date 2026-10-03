/// Thrown when the AI sends arguments that don't match a tool's schema.
class ToolArgumentException implements Exception {
  final String toolName;
  final List<String> errors;

  const ToolArgumentException(this.toolName, this.errors);

  @override
  String toString() =>
      'Invalid arguments for "$toolName": ${errors.join('; ')}';
}