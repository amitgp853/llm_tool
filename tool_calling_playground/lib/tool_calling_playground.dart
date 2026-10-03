import 'package:tool_calling_playground/tools.dart';

void main() async {
  print(await getWeatherTool({'city': 'Kanpur'}));
  print(getWeatherTool.parametersSchema);
}