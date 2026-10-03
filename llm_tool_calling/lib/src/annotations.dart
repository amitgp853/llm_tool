class Tool {
  final String? name;
  final String? description;
  final bool requiresConfirmation;
  const Tool({this.name, this.description, this.requiresConfirmation = false});
}

class Param {
  final String description;
  const Param(this.description);
}
