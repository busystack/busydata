import 'dart:convert';

import '../../backend/generated/busydata.pb.dart' as rpc;

/// Flutter owns preference selection. Java applies all dialect and inspection rules.
class SqlLanguagePreferences {
  SqlLanguagePreferences();

  static const engines = [
    rpc.Engine.POSTGRESQL,
    rpc.Engine.MYSQL,
    rpc.Engine.MARIADB,
  ];
  static const inspectionCodes = [
    'inspection.unrestricted-update',
    'inspection.unrestricted-delete',
    'binding.unresolved-relation',
    'binding.unresolved-column',
    'binding.ambiguous-column',
    'binding.invalid-derived-reference',
    'binding.duplicate-alias',
    'binding.duplicate-cte',
    'binding.duplicate-insert-column',
    'binding.unknown-target-column',
    'binding.unknown-update-column',
    'binding.duplicate-using-column',
    'binding.unresolved-using-column',
    'binding.ambiguous-using-column',
    'binding.output-column-count',
    'routine.argument-count',
    'routine.no-matching-overload',
    'routine.ambiguous-overload',
    'routine.unknown',
    'expression.invalid-aggregate',
    'type.incompatible-comparison',
    'type.incompatible-assignment',
    'type.invalid-boolean',
    'type.incompatible-operator',
    'type.incompatible-array',
    'type.invalid-case-condition',
    'type.incompatible-case',
    'type.incompatible-coalesce',
    'type.set-column-count',
    'type.incompatible-set',
    'type.recursive-cte-mismatch',
  ];

  final _formats = <String, rpc.FormatSettings>{};
  final _inspections = <String, List<rpc.InspectionSetting>>{};

  static rpc.FormatSettings defaults(rpc.Engine engine) => rpc.FormatSettings(
    keywordCase: 'preserve',
    indentationWidth: 4,
    continuationIndent: 4,
    clauseLineBreaks: true,
    joinLayout: 'new-line',
    commaPlacement: 'trailing',
    logicalOperatorPlacement: 'same-line',
    wrapLists: false,
    wrapArguments: false,
    indentSubqueries: true,
    cteLineBreaks: true,
    parenthesisSpacing: false,
    operatorSpacing: true,
    alignment: false,
    maxLineLength: 100,
    preserveBlankLines: true,
  );

  static String _scope(rpc.Engine engine, String? profileId) =>
      profileId == null ? engine.name : '${engine.name}:$profileId';

  rpc.FormatSettings formatFor(rpc.Engine engine, String? profileId) =>
      (_formats[_scope(engine, profileId)] ??
              _formats[engine.name] ??
              defaults(engine))
          .deepCopy();

  List<rpc.InspectionSetting> inspectionsFor(
    rpc.Engine engine,
    String? profileId,
  ) {
    final values = <String, rpc.InspectionSetting>{};
    for (final code in inspectionCodes) {
      values[code] = rpc.InspectionSetting(
        code: code,
        enabled: true,
        severity: code.startsWith('inspection.') ? 'warning' : 'error',
      );
    }
    for (final scope in [
      engine.name,
      if (profileId != null) _scope(engine, profileId),
    ]) {
      for (final setting in _inspections[scope] ?? <rpc.InspectionSetting>[]) {
        values[setting.code] = setting.deepCopy();
      }
    }
    return values.values.toList(growable: false);
  }

  bool hasOverride(rpc.Engine engine, String profileId) =>
      _formats.containsKey(_scope(engine, profileId)) ||
      _inspections.containsKey(_scope(engine, profileId));

  void setFormat(
    rpc.Engine engine,
    String? profileId,
    rpc.FormatSettings settings,
  ) {
    final scope = _scope(engine, profileId),
        previous = _formats[_scope(engine, profileId)];
    _formats[scope] = settings.deepCopy()..freeze();
    try {
      validate();
    } catch (_) {
      if (previous == null) {
        _formats.remove(scope);
      } else {
        _formats[scope] = previous;
      }
      rethrow;
    }
  }

  void setInspections(
    rpc.Engine engine,
    String? profileId,
    List<rpc.InspectionSetting> settings,
  ) {
    final scope = _scope(engine, profileId),
        previous = _inspections[_scope(engine, profileId)];
    _inspections[scope] = settings
        .map((value) => value.deepCopy()..freeze())
        .toList(growable: false);
    try {
      validate();
    } catch (_) {
      if (previous == null) {
        _inspections.remove(scope);
      } else {
        _inspections[scope] = previous;
      }
      rethrow;
    }
  }

  void removeOverride(rpc.Engine engine, String profileId) {
    _formats.remove(_scope(engine, profileId));
    _inspections.remove(_scope(engine, profileId));
  }

  SqlLanguagePreferences deepCopy() =>
      SqlLanguagePreferences.fromJson(toJson());

  Map<String, Object?> toJson() => {
    'version': 1,
    'formats': {
      for (final entry in _formats.entries)
        entry.key: entry.value.toProto3Json(),
    },
    'inspections': {
      for (final entry in _inspections.entries)
        entry.key: entry.value.map((value) => value.toProto3Json()).toList(),
    },
  };

  factory SqlLanguagePreferences.fromJson(Object? value) {
    final preferences = SqlLanguagePreferences();
    if (value == null) return preferences;
    if (value is! Map || value['version'] != 1) {
      throw const FormatException('Invalid SQL preferences version');
    }
    final formats = value['formats'], inspections = value['inspections'];
    if (formats is! Map || inspections is! Map) {
      throw const FormatException('Invalid SQL preferences');
    }
    for (final entry in formats.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('Invalid SQL formatting preferences');
      }
      preferences._formats[entry.key as String] = rpc.FormatSettings()
        ..mergeFromProto3Json(entry.value)
        ..freeze();
    }
    for (final entry in inspections.entries) {
      if (entry.key is! String || entry.value is! List) {
        throw const FormatException('Invalid SQL inspection preferences');
      }
      preferences._inspections[entry.key as String] = (entry.value as List)
          .map(
            (raw) => rpc.InspectionSetting()
              ..mergeFromProto3Json(raw)
              ..freeze(),
          )
          .toList(growable: false);
    }
    preferences.validate();
    return preferences;
  }

  void validate() {
    if ({..._formats.keys, ..._inspections.keys}.length > 128 ||
        utf8.encode(jsonEncode(toJson())).length > 16384) {
      throw const FormatException(
        'SQL preferences exceed their storage budget',
      );
    }
    for (final scope in {..._formats.keys, ..._inspections.keys}) {
      final separator = scope.indexOf(':');
      final engine = separator < 0 ? scope : scope.substring(0, separator);
      if (!engines.any((value) => value.name == engine) ||
          scope.length > 256 ||
          scope.contains('\u0000') ||
          separator == scope.length - 1) {
        throw const FormatException('Invalid SQL preferences owner');
      }
    }
    for (final settings in _formats.values) {
      if (!['preserve', 'upper', 'lower'].contains(settings.keywordCase) ||
          settings.indentationWidth < 1 ||
          settings.indentationWidth > 16 ||
          settings.continuationIndent > 32 ||
          settings.maxLineLength < 20 ||
          settings.maxLineLength > 1000 ||
          !['new-line', 'same-line'].contains(settings.joinLayout) ||
          !['leading', 'trailing'].contains(settings.commaPlacement) ||
          ![
            'leading',
            'trailing',
            'same-line',
          ].contains(settings.logicalOperatorPlacement) ||
          settings.startUtf16 != 0 ||
          settings.endUtf16 != 0) {
        throw const FormatException('Invalid SQL formatting options');
      }
    }
    for (final settings in _inspections.values) {
      final seen = <String>{};
      for (final setting in settings) {
        if (!inspectionCodes.contains(setting.code) ||
            !seen.add(setting.code) ||
            ![
              'error',
              'warning',
              'hint',
              'information',
            ].contains(setting.severity)) {
          throw const FormatException('Invalid SQL inspection options');
        }
      }
    }
  }
}
