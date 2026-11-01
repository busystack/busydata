import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ModalCommandBoundary extends StatelessWidget {
  const ModalCommandBoundary({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter, control: true):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.enter, control: true, shift: true):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.keyS, control: true):
          DoNothingAndStopPropagationIntent(),
      SingleActivator(LogicalKeyboardKey.keyT, control: true):
          DoNothingAndStopPropagationIntent(),
    },
    child: child,
  );
}

/// Local editing in in-window Settings/search never routes to the workbench.
class WorkbenchLocalInputBoundary extends StatelessWidget {
  const WorkbenchLocalInputBoundary({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;
  static bool get hasFocus =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<WorkbenchLocalInputBoundary>()
          ?.enabled ==
      true;
  @override
  Widget build(BuildContext context) => child;
}
