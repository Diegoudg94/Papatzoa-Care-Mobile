import 'package:flutter/widgets.dart';

/// Marks root pages whose shared navigation is owned by PatientRootShell.
class PatientRootScope extends InheritedWidget {
  const PatientRootScope({
    super.key,
    required this.onSelectRoute,
    required super.child,
  });

  final ValueChanged<String> onSelectRoute;

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PatientRootScope>() != null;

  static bool selectRoute(BuildContext context, String route) {
    final scope = context.getInheritedWidgetOfExactType<PatientRootScope>();
    if (scope == null) return false;
    scope.onSelectRoute(route);
    return true;
  }

  @override
  bool updateShouldNotify(PatientRootScope oldWidget) => false;
}
