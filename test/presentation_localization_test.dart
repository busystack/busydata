import 'dart:convert';
import 'dart:io';
import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all touched presentation messages and ICU contracts exist in every supported ARB',
    () async {
      final base =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final keys = base.keys
          .skipWhile((key) => key != 'resizeColumn')
          .where((key) => !key.startsWith('@'))
          .toList();
      expect(keys.length, greaterThanOrEqualTo(19));
      for (final file
          in Directory('lib/l10n').listSync().whereType<File>().where(
            (file) => file.path.endsWith('.arb'),
          )) {
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final key in keys) {
          expect(data[key], isA<String>(), reason: '${file.path}: $key');
          if (data.containsKey('@$key')) {
            expect(
              data['@$key']['placeholders'],
              base['@$key']['placeholders'],
              reason: '${file.path}: $key placeholder types',
            );
          }
        }
      }
      for (final locale in AppLocalizations.supportedLocales) {
        final l = await AppLocalizations.delegate.load(locale);
        for (final (message, arguments) in [
          (l.resizeColumn('識別子'), ['識別子']),
          (l.sqlEditorLabel('Query 17'), ['Query 17']),
          (l.editorExtent('61'), ['61']),
          (l.explorerExtent('320'), ['320']),
          (l.planTextPage('1', '16384', '32768'), ['1', '16384', '32768']),
          (l.queryTimeoutDetail('120', '1000'), ['120', '1000']),
        ]) {
          for (final argument in arguments) {
            expect(message, contains(argument), reason: '$locale: $message');
          }
          expect(message, isNot(contains('{')));
        }
      }
    },
  );
}
