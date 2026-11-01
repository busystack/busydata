import 'package:flutter/widgets.dart';

import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/sql_language_preferences.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'sql_diagnostics.dart';

/// A settings draft only. Java remains the owner of formatting and inspections.
class SqlLanguageSettingsFields extends StatefulWidget {
  const SqlLanguageSettingsFields({
    super.key,
    required this.controls,
    required this.value,
    required this.profiles,
    required this.changed,
    required this.enabled,
  });
  final DesktopControls controls;
  final SqlLanguagePreferences value;
  final List<rpc.Profile> profiles;
  final ValueChanged<SqlLanguagePreferences> changed;
  final bool enabled;

  @override
  State<SqlLanguageSettingsFields> createState() =>
      _SqlLanguageSettingsFieldsState();
}

class _SqlLanguageSettingsFieldsState extends State<SqlLanguageSettingsFields> {
  rpc.Engine engine = rpc.Engine.POSTGRESQL;
  String? profileId;

  void format(void Function(rpc.FormatSettings) change) {
    final draft = widget.value.deepCopy();
    final settings = draft.formatFor(engine, profileId);
    change(settings);
    draft.setFormat(engine, profileId, settings);
    widget.changed(draft);
  }

  void inspection(rpc.InspectionSetting current, String value) {
    final draft = widget.value.deepCopy();
    final settings = draft.inspectionsFor(engine, profileId);
    for (final item in settings) {
      if (item.code == current.code) {
        item.enabled = value != 'disabled';
        if (value != 'disabled') item.severity = value;
      }
    }
    draft.setInspections(engine, profileId, settings);
    widget.changed(draft);
  }

  @override
  Widget build(BuildContext context) {
    final l = strings(context), ui = widget.controls;
    final settings = widget.value.formatFor(engine, profileId);
    final scopeProfiles = widget.profiles.where(
      (profile) => profile.engine == engine,
    );
    String label(String code) => sqlInspectionLabel(context, code);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkbenchFormHeading(controls: ui, label: l.sqlLanguage),
        ui.comboRow(
          l.sqlDialect,
          engine,
          {
            rpc.Engine.POSTGRESQL: l.sqlPostgresql,
            rpc.Engine.MYSQL: l.sqlMysql,
            rpc.Engine.MARIADB: l.sqlMariadb,
          },
          (value) => setState(() {
            engine = value;
            profileId = null;
          }),
          enabled: widget.enabled,
        ),
        ui.comboRow(
          l.sqlPreferenceScope,
          profileId ?? '',
          {
            '': l.sqlDialectDefaults,
            for (final profile in scopeProfiles) profile.id: profile.name,
          },
          (value) => setState(() => profileId = value.isEmpty ? null : value),
          enabled: widget.enabled,
        ),
        ui.status(
          profileId == null
              ? l.sqlDialectDefaultsDescription
              : l.sqlProfileOverrideDescription,
        ),
        if (profileId != null && widget.value.hasOverride(engine, profileId!))
          ui.actionRow(
            title: l.sqlUseDialectDefaults,
            onPressed: widget.enabled
                ? () {
                    final draft = widget.value.deepCopy()
                      ..removeOverride(engine, profileId!);
                    widget.changed(draft);
                  }
                : null,
          ),
        WorkbenchFormHeading(controls: ui, label: l.sqlFormatting),
        ui.comboRow(
          l.sqlKeywordCase,
          settings.keywordCase,
          {
            'preserve': l.sqlPreserveCase,
            'upper': l.sqlUpperCase,
            'lower': l.sqlLowerCase,
          },
          (value) => format((settings) => settings.keywordCase = value),
          enabled: widget.enabled,
        ),
        ui.comboRow(
          l.sqlIndentationWidth,
          settings.indentationWidth,
          {for (var value = 1; value <= 16; value++) value: '$value'},
          (value) => format((settings) => settings.indentationWidth = value),
          enabled: widget.enabled,
        ),
        ui.comboRow(
          l.sqlContinuationIndent,
          settings.continuationIndent,
          {for (var value = 0; value <= 32; value++) value: '$value'},
          (value) => format((settings) => settings.continuationIndent = value),
          enabled: widget.enabled,
        ),
        ui.switchRow(
          l.sqlClauseBreaks,
          settings.clauseLineBreaks,
          widget.enabled
              ? (value) =>
                    format((settings) => settings.clauseLineBreaks = value)
              : null,
        ),
        ui.comboRow(
          l.sqlJoinLayout,
          settings.joinLayout,
          {'new-line': l.sqlNewLine, 'same-line': l.sqlSameLine},
          (value) => format((settings) => settings.joinLayout = value),
          enabled: widget.enabled,
        ),
        ui.comboRow(
          l.sqlCommaPlacement,
          settings.commaPlacement,
          {'leading': l.sqlLeading, 'trailing': l.sqlTrailing},
          (value) => format((settings) => settings.commaPlacement = value),
          enabled: widget.enabled,
        ),
        ui.comboRow(
          l.sqlLogicalPlacement,
          settings.logicalOperatorPlacement,
          {
            'leading': l.sqlLeading,
            'trailing': l.sqlTrailing,
            'same-line': l.sqlSameLine,
          },
          (value) =>
              format((settings) => settings.logicalOperatorPlacement = value),
          enabled: widget.enabled,
        ),
        ui.switchRow(
          l.sqlWrapLists,
          settings.wrapLists,
          widget.enabled
              ? (value) => format((settings) => settings.wrapLists = value)
              : null,
        ),
        ui.switchRow(
          l.sqlWrapArguments,
          settings.wrapArguments,
          widget.enabled
              ? (value) => format((settings) => settings.wrapArguments = value)
              : null,
        ),
        ui.switchRow(
          l.sqlIndentSubqueries,
          settings.indentSubqueries,
          widget.enabled
              ? (value) =>
                    format((settings) => settings.indentSubqueries = value)
              : null,
        ),
        ui.switchRow(
          l.sqlCteBreaks,
          settings.cteLineBreaks,
          widget.enabled
              ? (value) => format((settings) => settings.cteLineBreaks = value)
              : null,
        ),
        ui.switchRow(
          l.sqlParenthesisSpacing,
          settings.parenthesisSpacing,
          widget.enabled
              ? (value) =>
                    format((settings) => settings.parenthesisSpacing = value)
              : null,
        ),
        ui.switchRow(
          l.sqlOperatorSpacing,
          settings.operatorSpacing,
          widget.enabled
              ? (value) =>
                    format((settings) => settings.operatorSpacing = value)
              : null,
        ),
        ui.switchRow(
          l.sqlAlignment,
          settings.alignment,
          widget.enabled
              ? (value) => format((settings) => settings.alignment = value)
              : null,
        ),
        ui.comboRow(
          l.sqlMaximumLine,
          settings.maxLineLength,
          {
            for (final value in ({
              40,
              60,
              80,
              100,
              120,
              160,
              200,
              300,
              500,
              1000,
              settings.maxLineLength,
            }.toList()..sort()))
              value: '$value',
          },
          (value) => format((settings) => settings.maxLineLength = value),
          enabled: widget.enabled,
        ),
        ui.switchRow(
          l.sqlPreserveBlankLines,
          settings.preserveBlankLines,
          widget.enabled
              ? (value) =>
                    format((settings) => settings.preserveBlankLines = value)
              : null,
        ),
        WorkbenchFormHeading(controls: ui, label: l.sqlInspections),
        for (final setting in widget.value.inspectionsFor(engine, profileId))
          ui.comboRow(
            label(setting.code),
            setting.enabled ? setting.severity : 'disabled',
            {
              'disabled': l.sqlInspectionDisabled,
              'error': l.sqlSeverityError,
              'warning': l.sqlSeverityWarning,
              'information': l.sqlSeverityInformation,
              'hint': l.sqlSeverityHint,
            },
            (value) => inspection(setting, value),
            enabled: widget.enabled,
          ),
      ],
    );
  }
}
