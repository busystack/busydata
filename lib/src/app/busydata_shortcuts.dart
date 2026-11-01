import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

abstract final class BusyDataShortcutActivators {
  static const back = SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true);
  static const settings = SingleActivator(
    LogicalKeyboardKey.keyS,
    control: true,
    alt: true,
  );
  static const keyboardShortcuts = SingleActivator(
    LogicalKeyboardKey.keyK,
    control: true,
    alt: true,
  );
  static const dismiss = SingleActivator(LogicalKeyboardKey.escape);
  static const execute = SingleActivator(
    LogicalKeyboardKey.enter,
    control: true,
  );
  static const script = SingleActivator(
    LogicalKeyboardKey.enter,
    control: true,
    shift: true,
  );
  static const search = SingleActivator(LogicalKeyboardKey.keyF, control: true);
}
