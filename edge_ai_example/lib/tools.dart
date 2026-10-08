import 'package:llm_tool/llm_tool.dart';

part 'tools.g.dart';

/// Gets the current date and time on this device.
@LlmTool(name: 'get_time')
String getTime() => DateTime.now().toString();

/// The user's to-do list. The tools change it, and the app shows it.
@LlmToolset()
class TodoTools {
  final todos = <String>[];

  /// Adds an item to the user's to-do list.
  @LlmTool(name: 'add_todo')
  String addTodo(
    @Param('The to-do item, e.g. Buy milk', minLength: 1, maxLength: 100)
    String item,
  ) {
    todos.add(item);
    return 'Added. The list has ${todos.length} items.';
  }

  /// Deletes every item on the user's to-do list.
  @LlmTool(name: 'clear_todos', requiresConfirmation: true)
  String clearTodos() {
    todos.clear();
    return 'The list is empty.';
  }
}
