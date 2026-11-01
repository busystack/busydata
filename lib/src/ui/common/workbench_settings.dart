import 'dart:convert';

import 'package:flutter/widgets.dart';
import '../../l10n/locale_resolution.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../backend/connection_failure.dart';
import '../../features/workspace/workbench_model.dart';
import 'sql_language_settings.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'modal_command_boundary.dart';
import 'workbench_shortcut_capture.dart';
import 'workbench_presentation.dart';

Map<String, String> workbenchSettingsCategories(BuildContext context) {
  final l = strings(context);
  return {
    'appearance': l.appearance,
    'execution': l.executionOptions,
    'sqlLanguage': l.sqlLanguage,
    'recovery': l.privateRecoveryCategory,
    'shortcuts': l.keyboardShortcutsHeading,
  };
}

/// The window sidebar owns category navigation on Linux. Explorer remains
/// mounted offstage with its previous expansion, selection and scroll.
class WorkbenchSettingsNavigation extends StatelessWidget {
  const WorkbenchSettingsNavigation({
    super.key,
    required this.controls,
    required this.category,
  });
  final DesktopControls controls;
  final ValueNotifier<String> category;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: category,
    builder: (context, selected, _) => KeyedSubtree(
      key: const ValueKey('settings-sidebar'),
      child: controls.sidebarNavigation([
        for (final entry in workbenchSettingsCategories(context).entries)
          KeyedSubtree(
            key: ValueKey('settings-navigation-${entry.key}'),
            child: controls.sidebarNavigationTile(
              selected: selected == entry.key,
              leading: controls.icon(switch (entry.key) {
                'recovery' => DesktopIcon.privacy,
                'shortcuts' => DesktopIcon.keyboard,
                'appearance' => DesktopIcon.appearance,
                _ => DesktopIcon.settings,
              }),
              title: entry.value,
              onPressed: () => category.value = entry.key,
            ),
          ),
      ]),
    ),
  );
}

/// Execution and recovery drafts have an explicit save boundary. Appearance
/// and accepted shortcut dialogs use the same authoritative durable writer.
class WorkbenchSettings extends StatefulWidget {
  const WorkbenchSettings({
    super.key,
    required this.model,
    required this.controls,
    required this.close,
    required this.confirmRecovery,
    this.categoryController,
    this.usesWindowSidebar = false,
    this.windowSidebarVisible = false,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  final VoidCallback close;
  final Future<bool> Function() confirmRecovery;
  final ValueNotifier<String>? categoryController;
  final bool usesWindowSidebar, windowSidebarVisible;
  @override
  State<WorkbenchSettings> createState() => WorkbenchSettingsState();
}

class WorkbenchSettingsState extends State<WorkbenchSettings> {
  late final rows = TextEditingController(
    text: '${widget.model.defaultRowLimit}',
  );
  Map<String, String> get keys => widget.model.shortcuts;
  late String savedRows = rows.text;
  late bool savedContinue = continueErrors, savedRecovery = recovery;
  late SqlLanguagePreferences sqlLanguage = widget.model.sqlLanguagePreferences
      .deepCopy();
  late String savedSqlLanguage = jsonEncode(sqlLanguage.toJson());
  bool reviewingDeparture = false;
  bool get dirty =>
      rows.text != savedRows ||
      continueErrors != savedContinue ||
      recovery != savedRecovery ||
      jsonEncode(sqlLanguage.toJson()) != savedSqlLanguage;
  late bool continueErrors =
      widget.model.defaultErrorPolicy == rpc.ErrorPolicy.CONTINUE_ON_ERROR;
  late bool recovery = widget.model.draftRecovery;
  bool saving = false;
  String _category = 'appearance', feedback = '', rowError = '';
  String get category => widget.categoryController?.value ?? _category;
  void selectCategory(String value) {
    final controller = widget.categoryController;
    if (controller != null) {
      controller.value = value;
    } else {
      setState(() => _category = value);
    }
  }

  void categoryChanged() => setState(() {});
  DesktopControls get ui => widget.controls;
  WorkbenchModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    widget.categoryController?.addListener(categoryChanged);
    rows.addListener(categoryChanged);
    model.reviewSettingsDeparture = mayLeave;
  }

  @override
  void didUpdateWidget(covariant WorkbenchSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryController != widget.categoryController) {
      oldWidget.categoryController?.removeListener(categoryChanged);
      widget.categoryController?.addListener(categoryChanged);
    }
  }

  @override
  void dispose() {
    widget.categoryController?.removeListener(categoryChanged);
    if (model.reviewSettingsDeparture == mayLeave) {
      model.reviewSettingsDeparture = null;
    }
    rows.dispose();
    super.dispose();
  }

  String label(String key) =>
      model.commands!.commands
          .where((command) => command.shortcutKey == key)
          .firstOrNull
          ?.label ??
      key;

  Future<void> assign(String key) async {
    final l = strings(context);
    final captureOwner = Object();
    final captureFocus = FocusNode(
      debugLabel: 'Shortcut recording',
      skipTraversal: true,
    );
    final assignFocus = FocusNode(debugLabel: 'Assign shortcut');
    var proposed = keys[key]!,
        validationError = '',
        persistenceError = '',
        recording = false,
        open = true,
        assigning = false;
    StateSetter? repaint;
    void refresh(VoidCallback change) {
      if (open && mounted) repaint?.call(change);
    }

    void cancelRecording() {
      WorkbenchShortcutCapture.end(captureOwner);
      refresh(() => recording = false);
    }

    String validation(String candidate) {
      try {
        validateWorkbenchShortcuts({...keys, key: candidate});
        return '';
      } on ArgumentError {
        final conflicts = keys.entries
            .where((entry) => entry.key != key && entry.value == candidate)
            .map((entry) => label(entry.key));
        return [l.shortcutInvalid, ...conflicts].join(' · ');
      }
    }

    void record() {
      if (assigning) return;
      captureFocus.requestFocus();
      refresh(() {
        recording = true;
        validationError = '';
        persistenceError = '';
      });
      WorkbenchShortcutCapture.begin(
        captureOwner,
        onCandidate: (candidate) {
          WorkbenchShortcutCapture.end(captureOwner);
          refresh(() {
            proposed = candidate;
            recording = false;
            validationError = validation(candidate);
            persistenceError = '';
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (open && mounted) assignFocus.requestFocus();
          });
        },
        onCancel: cancelRecording,
      );
    }

    captureFocus.addListener(() {
      if (!captureFocus.hasFocus && recording) cancelRecording();
    });
    try {
      await ui.formDialog<void>(
        context,
        (context) => StatefulBuilder(
          builder: (context, set) {
            repaint = set;
            return PopScope(
              canPop: !assigning,
              child: ui.editorShell(
                title: label(key),
                cancelLabel: l.cancel,
                saveLabel: l.applyView,
                saveFocus: assignFocus,
                saving: assigning,
                cancelEnabled: !assigning,
                onCancel: () {
                  if (assigning) return;
                  cancelRecording();
                  Navigator.of(context).pop();
                },
                onSave: assigning || recording || validationError.isNotEmpty
                    ? null
                    : () async {
                        final problem = validation(proposed);
                        if (problem.isNotEmpty) {
                          refresh(() => validationError = problem);
                          return;
                        }
                        final assignment = canonicalWorkbenchShortcut(proposed);
                        refresh(() {
                          assigning = true;
                          persistenceError = '';
                        });
                        try {
                          await model.saveShortcut(key, assignment);
                          if (mounted) setState(() {});
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (failure) {
                          refresh(
                            () => persistenceError = operationFailureSummary(
                              failure,
                              locale: l,
                            ),
                          );
                        } finally {
                          refresh(() => assigning = false);
                        }
                      },
                body: WorkbenchLocalInputBoundary(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ui.groupedList(
                        children: [
                          ui.propertyRow(
                            l.shortcutField(label(key)),
                            ui.shortcutBadge(proposed.replaceAll('Slash', '/')),
                          ),
                          ui.actionRow(
                            title: recording
                                ? l.shortcutRecordHelp
                                : l.shortcutRecordAction,
                            subtitle: recording ? null : l.shortcutRecordHelp,
                            onPressed: assigning
                                ? null
                                : recording
                                ? cancelRecording
                                : record,
                            trailing: Focus(
                              focusNode: captureFocus,
                              skipTraversal: true,
                              includeSemantics: false,
                              child: const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
                      if (validationError.isNotEmpty)
                        ui.status(validationError, error: true),
                      if (persistenceError.isNotEmpty)
                        ui.status(persistenceError, error: true),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      open = false;
      WorkbenchShortcutCapture.end(captureOwner);
      captureFocus.dispose();
      assignFocus.dispose();
    }
  }

  Future<bool> save() async {
    if (saving) return false;
    final l = strings(context), limit = int.tryParse(rows.text);
    if (limit == null || limit < 1 || limit > 1000000) {
      selectCategory('execution');
      setState(() {
        rowError = l.rowLimitInvalid;
      });
      return false;
    }
    final proposedRecovery = recovery;
    if (model.draftRecovery &&
        !proposedRecovery &&
        !await widget.confirmRecovery()) {
      return false;
    }
    if (!mounted) return false;
    setState(() {
      saving = true;
      feedback = '';
      rowError = '';
    });
    bool accepted = false;
    await model.command(() async {
      try {
        if (model.draftRecovery &&
            !proposedRecovery &&
            (model.editBatches.values.any(
                  (batch) => batch.applying || batch.outcomeUnknown,
                ) ||
                model.editDrafts.any(
                  (draft) =>
                      draft.state == 'APPLYING' ||
                      draft.state == 'UNKNOWN_OUTCOME',
                ))) {
          throw StateError(l.recoveryReconcileFirst);
        }
        await model.saveExecutionPreferences(
          limit,
          continueErrors
              ? rpc.ErrorPolicy.CONTINUE_ON_ERROR
              : rpc.ErrorPolicy.STOP_ON_ERROR,
          recovery: proposedRecovery,
          sqlLanguage: sqlLanguage,
        );
        model.updateStatus(l.preferencesSaved);
        accepted = true;
        savedRows = rows.text;
        savedContinue = continueErrors;
        savedRecovery = recovery;
        savedSqlLanguage = jsonEncode(sqlLanguage.toJson());
      } catch (error) {
        if (mounted) {
          setState(() => feedback = operationFailureSummary(error, locale: l));
        }
        rethrow;
      } finally {
        if (mounted) setState(() => saving = false);
      }
    }, ownerId: 'application');
    return accepted;
  }

  void discard() => setState(() {
    rows.text = savedRows;
    continueErrors = savedContinue;
    recovery = savedRecovery;
    sqlLanguage = SqlLanguagePreferences.fromJson(jsonDecode(savedSqlLanguage));
    rowError = '';
    feedback = '';
  });
  Future<bool> mayLeave() async {
    if (saving || reviewingDeparture) return false;
    if (!dirty) return true;
    reviewingDeparture = true;
    try {
      final l = strings(context);
      final decision = await ui
          .dialog<String>(context, l.settings, Text(l.settingsDraftNotice), [
            ui.button(l.stay, () => Navigator.of(context).pop('stay')),
            ui.button(
              l.discardChanges,
              () => Navigator.of(context).pop('discard'),
            ),
            ui.button(
              l.saveProfile,
              () => Navigator.of(context).pop('save'),
              primary: true,
            ),
          ]);
      if (!mounted) return false;
      if (decision == 'discard') {
        discard();
        return true;
      }
      if (decision == 'save') return await save();
      return false;
    } finally {
      reviewingDeparture = false;
    }
  }

  Future<void> appearance(String theme, String? locale) async {
    setState(() {
      saving = true;
      feedback = '';
    });
    try {
      await model.saveAppearance(theme, locale);
    } catch (failure) {
      if (mounted) {
        setState(
          () => feedback = operationFailureSummary(
            failure,
            locale: strings(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = strings(context);
    final categories = workbenchSettingsCategories(context);
    final shortcutGroups = <String, List<MapEntry<String, String>>>{};
    for (final entry in keys.entries) {
      final command = model.commands!.commands
          .where((command) => command.shortcutKey == entry.key)
          .firstOrNull;
      (shortcutGroups[command?.category ?? l.keyboardShortcutsHeading] ??= [])
          .add(entry);
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ui.settingsTransition(
            category,
            ui.formList([
              if (category == 'appearance') ...[
                WorkbenchFormHeading(controls: ui, label: l.appearance),
                ui.preferenceRow(
                  l.appLanguage,
                  DesktopIcon.language,
                  normalizeBusyDataLocaleTag(
                        model.appearancePreference.value.$2,
                      ) ??
                      'system',
                  {
                    'system': l.systemLanguage,
                    for (final locale in busyDataSupportedLocales)
                      locale.toLanguageTag(): busyDataLocaleLabel(locale),
                  },
                  (value) => appearance(
                    model.appearancePreference.value.$1,
                    value == 'system' ? null : value,
                  ),
                  enabled: !saving,
                ),
                ui.preferenceRow(
                  l.theme,
                  DesktopIcon.appearance,
                  model.appearancePreference.value.$1,
                  {
                    'system': l.systemTheme,
                    'light': l.lightTheme,
                    'dark': l.darkTheme,
                  },
                  (value) =>
                      appearance(value, model.appearancePreference.value.$2),
                  enabled: !saving,
                ),
              ],
              if (category == 'execution') ...[
                WorkbenchFormHeading(controls: ui, label: l.executionOptions),
                ui.field(rows, l.resultRowLimit, enabled: !saving),
                if (rowError.isNotEmpty) ui.status(rowError, error: true),
                ui.comboRow(
                  l.errorPolicy,
                  continueErrors,
                  {false: l.stopOnError, true: l.continueOnError},
                  (v) => setState(() => continueErrors = v),
                  enabled: !saving,
                ),
              ],
              if (category == 'sqlLanguage')
                SqlLanguageSettingsFields(
                  controls: ui,
                  value: sqlLanguage,
                  profiles: model.profiles,
                  changed: (value) => setState(() => sqlLanguage = value),
                  enabled: !saving,
                ),
              if (category == 'recovery')
                ui.switchRow(
                  l.savePrivateDrafts,
                  recovery,
                  saving ? null : (v) => setState(() => recovery = v),
                  subtitle: l.disableRecoveryReview,
                ),
              if (category == 'shortcuts') ...[
                for (final group in shortcutGroups.entries) ...[
                  WorkbenchFormHeading(controls: ui, label: group.key),
                  for (final entry in group.value)
                    ui.actionRow(
                      title: label(entry.key),
                      semanticValue: entry.value.replaceAll('Slash', '/'),
                      trailing: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: ui.shortcutBadge(
                          entry.value.replaceAll('Slash', '/'),
                        ),
                      ),
                      onPressed: saving ? null : () => assign(entry.key),
                    ),
                ],
              ],
            ], ui.settingsPagePadding),
          ),
        ),
        if (feedback.isNotEmpty) ui.status(feedback, error: true),
        if (dirty) ui.status(l.settingsDraftNotice),
        if (!ui.hasWindowHeader ||
            category == 'execution' ||
            category == 'recovery' ||
            category == 'sqlLanguage' ||
            dirty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                ui.button(l.close, saving ? null : widget.close),
                if (category == 'execution' ||
                    category == 'recovery' ||
                    category == 'sqlLanguage') ...[
                  ui.button(
                    l.discardChanges,
                    saving || !dirty ? null : discard,
                  ),
                  ui.button(
                    l.saveProfile,
                    saving || !dirty ? null : save,
                    primary: true,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
    return WorkbenchLocalInputBoundary(
      child: FocusScope(
        autofocus: true,
        child: ColoredBox(
          color: ui.appearance(context).view,
          child: LayoutBuilder(
            builder: (context, bounds) => widget.usesWindowSidebar
                ? Column(
                    children: [
                      Offstage(
                        offstage: widget.windowSidebarVisible,
                        child: ExcludeFocus(
                          excluding: widget.windowSidebarVisible,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                            child: KeyedSubtree(
                              key: const ValueKey('settings-page-selector'),
                              child: ui.choice(
                                category,
                                categories,
                                selectCategory,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  )
                : bounds.maxWidth < ui.settingsSidebarBreakpoint
                ? Column(
                    children: [
                      ui.choice(category, categories, selectCategory),
                      Expanded(child: content),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 240,
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            for (final entry in categories.entries)
                              WorkbenchRecord(
                                controls: ui,
                                label: entry.value,
                                selected: category == entry.key,
                                onPressed: () => selectCategory(entry.key),
                                child: Text(entry.value),
                              ),
                          ],
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
