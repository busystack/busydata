import 'dart:convert';

import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/sql_language_preferences.dart';
import 'package:busydata/src/ui/common/sql_diagnostics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const semanticInspections = {
  'binding.duplicate-using-column': 'Duplicate JOIN USING column',
  'binding.unresolved-using-column':
      'JOIN USING column missing from an operand',
  'binding.ambiguous-using-column': 'Ambiguous shared JOIN column',
  'binding.output-column-count': 'Declared output column count mismatch',
  'routine.ambiguous-overload': 'Ambiguous routine overload',
  'type.invalid-boolean': 'Invalid Boolean expression type',
  'type.incompatible-operator': 'Incompatible operator operand types',
  'type.incompatible-array': 'Incompatible array element types',
  'type.invalid-case-condition': 'Incompatible CASE condition type',
  'type.incompatible-case': 'Incompatible CASE result types',
  'type.incompatible-coalesce': 'Incompatible COALESCE argument types',
  'type.set-column-count': 'Set operation column count mismatch',
  'type.incompatible-set': 'Incompatible set operation result types',
  'type.recursive-cte-mismatch': 'Recursive CTE type mismatch',
};

void main() {
  test(
    'new checks extend saved version-one settings without resetting choices',
    () {
      final saved = {
        'version': 1,
        'formats': <String, Object?>{},
        'inspections': {
          'POSTGRESQL': [
            {
              'code': 'binding.unresolved-column',
              'enabled': false,
              'severity': 'hint',
            },
          ],
          'POSTGRESQL:chosen': [
            {
              'code': 'inspection.unrestricted-update',
              'enabled': true,
              'severity': 'error',
            },
          ],
        },
      };
      final preferences = SqlLanguagePreferences.fromJson(saved);
      final before = preferences.toJson();
      final chosen = {
        for (final setting in preferences.inspectionsFor(
          rpc.Engine.POSTGRESQL,
          'chosen',
        ))
          setting.code: setting,
      };
      expect(chosen['binding.unresolved-column']!.enabled, isFalse);
      expect(chosen['binding.unresolved-column']!.severity, 'hint');
      expect(chosen['inspection.unrestricted-update']!.severity, 'error');
      for (final code in semanticInspections.keys) {
        expect(chosen[code]!.enabled, isTrue, reason: code);
        expect(chosen[code]!.severity, 'error', reason: code);
      }
      expect(
        preferences
            .inspectionsFor(rpc.Engine.POSTGRESQL, 'other')
            .first
            .severity,
        'warning',
      );
      expect(
        preferences
            .inspectionsFor(rpc.Engine.MYSQL, 'chosen')
            .singleWhere((item) => item.code == 'binding.unresolved-column')
            .enabled,
        isTrue,
      );
      expect(preferences.toJson(), before);
      expect(preferences.toJson()['version'], 1);
    },
  );

  for (final engine in SqlLanguagePreferences.engines) {
    test(
      '${engine.name} semantic severities and enablement survive recovery',
      () {
        final preferences = SqlLanguagePreferences();
        final settings = preferences.inspectionsFor(engine, 'chosen');
        final codes = settings.map((item) => item.code).toList();
        expect(codes.toSet(), hasLength(codes.length));
        expect(codes, containsAll(semanticInspections.keys));
        for (final item in settings) {
          if (semanticInspections.containsKey(item.code)) {
            item.enabled = false;
            item.severity = 'information';
          }
        }
        preferences.setInspections(engine, 'chosen', settings);
        final restored = SqlLanguagePreferences.fromJson(
          jsonDecode(jsonEncode(preferences.toJson())),
        );
        for (final setting in restored.inspectionsFor(engine, 'chosen')) {
          if (semanticInspections.containsKey(setting.code)) {
            expect(setting.enabled, isFalse, reason: setting.code);
            expect(setting.severity, 'information', reason: setting.code);
          }
        }
        for (final setting in restored.inspectionsFor(engine, 'other')) {
          if (semanticInspections.containsKey(setting.code)) {
            expect(setting.enabled, isTrue, reason: setting.code);
            expect(setting.severity, 'error', reason: setting.code);
          }
        }
      },
    );
  }

  test(
    'unrecognized inspection settings fail without discarding accepted ones',
    () {
      final preferences = SqlLanguagePreferences();
      preferences.setInspections(rpc.Engine.POSTGRESQL, 'chosen', [
        rpc.InspectionSetting(
          code: 'type.invalid-boolean',
          enabled: false,
          severity: 'warning',
        ),
      ]);
      final before = jsonDecode(jsonEncode(preferences.toJson()));
      expect(
        () => preferences.setInspections(rpc.Engine.POSTGRESQL, 'chosen', [
          rpc.InspectionSetting(
            code: 'future.new-inspection',
            enabled: true,
            severity: 'error',
          ),
        ]),
        throwsFormatException,
      );
      expect(preferences.toJson(), before);
      final unsupported = {
        'version': 1,
        'formats': <String, Object?>{},
        'inspections': {
          'POSTGRESQL': [
            {
              'code': 'future.new-inspection',
              'enabled': true,
              'severity': 'error',
            },
          ],
        },
      };
      final original = jsonEncode(unsupported);
      expect(
        () => SqlLanguagePreferences.fromJson(unsupported),
        throwsFormatException,
      );
      expect(jsonEncode(unsupported), original);
    },
  );

  for (final locale in ['en', 'fr', 'ar']) {
    testWidgets('$locale gives semantic failures specific localized labels', (
      tester,
    ) async {
      late Map<String, String> labels;
      late String unavailable;
      late String dialect;
      late List<String> syntax;
      await tester.pumpWidget(
        Localizations(
          locale: Locale(locale),
          delegates: AppLocalizations.localizationsDelegates,
          child: Builder(
            builder: (context) {
              expect(
                Directionality.of(context),
                locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              );
              labels = {
                for (final code in semanticInspections.keys)
                  code: sqlInspectionLabel(context, code),
              };
              unavailable = sqlInspectionLabel(context, 'analysis.unavailable');
              dialect = sqlInspectionLabel(context, 'dialect.full-join');
              syntax = [
                for (final code in [
                  'syntax.expected-alias',
                  'syntax.expected-using-columns',
                  'syntax.using-column',
                ])
                  sqlInspectionLabel(context, code),
              ];
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(labels.values, isNot(contains(unavailable)));
      expect(labels.values.toSet(), hasLength(semanticInspections.length));
      expect(dialect, isNot(unavailable));
      expect(syntax, everyElement(isNot(unavailable)));
      expect(syntax.toSet(), hasLength(1));
      if (locale == 'en') {
        expect(labels, semanticInspections);
      } else {
        expect(
          labels['routine.ambiguous-overload'],
          locale == 'fr'
              ? 'Surcharge de routine ambiguë'
              : 'تحميل زائد ملتبس للروتين',
        );
        expect(
          labels['type.invalid-boolean'],
          isNot(semanticInspections['type.invalid-boolean']),
        );
      }
    });
  }
}
