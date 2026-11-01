import 'dart:io';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Synthetic role-size variation for retention/layout regressions.
// Source comparison galleries load actual reference fonts and use production themes.
ThemeData presentationTheme(
  Brightness brightness, {
  bool contrast = false,
  double fontSize = 15,
}) {
  final base = BusyDataYaruTheme.build(
    brightness: brightness,
    accentColor: contrast
        ? brightness == Brightness.dark
              ? Colors.white
              : Colors.black
        : Colors.deepOrange,
    highContrast: contrast,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontSizeFactor: fontSize / 11),
  );
}

Widget presentationHost(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool contrast = false,
  double scale = 1,
  double fontSize = 15,
}) => MaterialApp(
  theme: presentationTheme(brightness, contrast: contrast, fontSize: fontSize),
  builder: (context, body) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), highContrast: contrast),
    child: body!,
  ),
  home: Scaffold(body: child),
);

Future<void> loadPresentationFonts() async {
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await (FontLoader(
    'packages/yaru/YaruIcons',
  )..addFont(rootBundle.load('packages/yaru/assets/yaru_icons.otf'))).load();
  for (final (family, file) in [
    ('Ubuntu', 'DejaVuSans.ttf'),
    ('packages/yaru/Ubuntu', 'DejaVuSans.ttf'),
    ('monospace', 'DejaVuSansMono.ttf'),
    ('Ubuntu Mono', 'DejaVuSansMono.ttf'),
  ]) {
    await (FontLoader(family)..addFont(
          Future.value(
            ByteData.sublistView(File('test/fonts/$file').readAsBytesSync()),
          ),
        ))
        .load();
  }
}
