import 'package:flutter/widgets.dart';

class LinuxApplicationMediaQuery extends StatelessWidget {
  const LinuxApplicationMediaQuery({
    super.key,
    required this.alwaysUse24HourFormat,
    required this.gtkAnimationsEnabled,
    required this.child,
  });
  final bool alwaysUse24HourFormat, gtkAnimationsEnabled;
  final Widget child;
  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      alwaysUse24HourFormat: alwaysUse24HourFormat,
      disableAnimations:
          MediaQuery.disableAnimationsOf(context) || !gtkAnimationsEnabled,
    ),
    child: child,
  );
}
