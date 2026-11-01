import 'package:flutter/material.dart';
import '../platform/gtk_font_service.dart';
import 'busydata_yaru_theme.dart';

ThemeData buildBusyDataTheme({
  required Brightness brightness,
  required Color accentColor,
  GtkThemeColors? gtkThemeColors,
  bool highContrast = false,
}) => BusyDataYaruTheme.build(
  brightness: brightness,
  accentColor: highContrast
      ? (brightness == Brightness.dark ? Colors.white : Colors.black)
      : accentColor,
  gtkThemeColors: gtkThemeColors,
  highContrast: highContrast,
);
