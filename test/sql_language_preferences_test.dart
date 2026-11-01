import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/sql_language_preferences.dart';

void main() {
  test('dialect defaults and exact per-profile overrides remain isolated', () {
    final preferences = SqlLanguagePreferences();
    final format = preferences.formatFor(rpc.Engine.POSTGRESQL, null)
      ..keywordCase = 'upper'
      ..indentationWidth = 2
      ..maxLineLength = 120;
    preferences.setFormat(rpc.Engine.POSTGRESQL, null, format);
    final override = preferences.formatFor(rpc.Engine.POSTGRESQL, 'profile-a')
      ..keywordCase = 'lower';
    preferences.setFormat(rpc.Engine.POSTGRESQL, 'profile-a', override);
    expect(
      preferences.formatFor(rpc.Engine.POSTGRESQL, 'profile-a').keywordCase,
      'lower',
    );
    expect(
      preferences.formatFor(rpc.Engine.POSTGRESQL, 'profile-b').keywordCase,
      'upper',
    );
    expect(
      preferences.formatFor(rpc.Engine.MYSQL, 'profile-a').keywordCase,
      'preserve',
    );
    expect(preferences.hasOverride(rpc.Engine.POSTGRESQL, 'profile-a'), isTrue);
    preferences.removeOverride(rpc.Engine.POSTGRESQL, 'profile-a');
    expect(
      preferences.formatFor(rpc.Engine.POSTGRESQL, 'profile-a').keywordCase,
      'upper',
    );
  });

  test(
    'all formatter and inspection options survive durable JSON round trip',
    () {
      final preferences = SqlLanguagePreferences();
      final format = rpc.FormatSettings(
        keywordCase: 'lower',
        indentationWidth: 8,
        continuationIndent: 3,
        clauseLineBreaks: false,
        joinLayout: 'same-line',
        commaPlacement: 'leading',
        logicalOperatorPlacement: 'trailing',
        wrapLists: true,
        wrapArguments: true,
        indentSubqueries: false,
        cteLineBreaks: false,
        parenthesisSpacing: true,
        operatorSpacing: false,
        alignment: true,
        maxLineLength: 300,
        preserveBlankLines: false,
      );
      preferences.setFormat(rpc.Engine.MARIADB, 'exact-owner', format);
      final inspections = preferences.inspectionsFor(
        rpc.Engine.MARIADB,
        'exact-owner',
      );
      inspections.first.enabled = false;
      inspections[1].severity = 'error';
      preferences.setInspections(
        rpc.Engine.MARIADB,
        'exact-owner',
        inspections,
      );
      final restored = SqlLanguagePreferences.fromJson(
        jsonDecode(jsonEncode(preferences.toJson())),
      );
      expect(restored.formatFor(rpc.Engine.MARIADB, 'exact-owner'), format);
      expect(
        restored
            .inspectionsFor(rpc.Engine.MARIADB, 'exact-owner')
            .first
            .enabled,
        isFalse,
      );
      expect(
        restored.inspectionsFor(rpc.Engine.MARIADB, 'exact-owner')[1].severity,
        'error',
      );
      expect(
        restored.inspectionsFor(rpc.Engine.POSTGRESQL, null).first.enabled,
        isTrue,
      );
      expect(restored.toJson(), preferences.deepCopy().toJson());
    },
  );

  test('returned protobufs are detached from saved preference state', () {
    final preferences = SqlLanguagePreferences();
    final format = preferences.formatFor(rpc.Engine.POSTGRESQL, null);
    preferences.setFormat(rpc.Engine.POSTGRESQL, null, format);
    format.indentationWidth = 15;
    expect(
      preferences.formatFor(rpc.Engine.POSTGRESQL, null).indentationWidth,
      4,
    );
    final returned = preferences.formatFor(rpc.Engine.POSTGRESQL, null)
      ..indentationWidth = 12;
    expect(returned.indentationWidth, 12);
    expect(
      preferences.formatFor(rpc.Engine.POSTGRESQL, null).indentationWidth,
      4,
    );
  });

  test(
    'invalid owners, versions, ranges and inspection codes fail explicitly',
    () {
      expect(
        () => SqlLanguagePreferences.fromJson({'version': 9}),
        throwsFormatException,
      );
      expect(
        () => SqlLanguagePreferences.fromJson({
          'version': 1,
          'formats': {'SQLITE': {}},
          'inspections': {},
        }),
        throwsFormatException,
      );
      expect(
        () => SqlLanguagePreferences().setFormat(
          rpc.Engine.POSTGRESQL,
          null,
          rpc.FormatSettings(keywordCase: 'upper', indentationWidth: 0),
        ),
        throwsFormatException,
      );
      expect(
        () => SqlLanguagePreferences().setInspections(rpc.Engine.MYSQL, null, [
          rpc.InspectionSetting(
            code: 'invented',
            enabled: true,
            severity: 'error',
          ),
        ]),
        throwsFormatException,
      );
      final range = SqlLanguagePreferences.defaults(rpc.Engine.MYSQL)
        ..startUtf16 = 1;
      expect(
        () => SqlLanguagePreferences().setFormat(rpc.Engine.MYSQL, null, range),
        throwsFormatException,
      );
    },
  );
}
