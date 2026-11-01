import 'package:flutter/widgets.dart';

abstract interface class SystemAppearanceSource {
  Color? get accentColor;
  Brightness get brightness;
  bool get highContrast;
  Stream<void> get changes;
}

abstract interface class DesktopWindowService {
  Future<void> setHideOnClose(bool enabled);
  Future<void> hideWindow();
  Future<void> showWindow();
  Future<void> quitApp();
  Future<bool> isWindowVisible();
}
