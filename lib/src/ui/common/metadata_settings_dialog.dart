import 'dart:async';
import 'dart:convert';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart';
import 'package:grpc/grpc.dart' show ResponseFuture;
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';

String _cacheStateLabel(BuildContext context, String state) {
  final l = strings(context);
  return switch (state) {
    'AVAILABLE' => l.available,
    'UNAVAILABLE' => l.unavailable,
    'PARTIAL_OR_STALE' => l.partial,
    'REBUILT_VERSION' => l.metadataCacheRebuiltVersion,
    'REBUILT_CORRUPT' => l.metadataCacheRebuiltCorrupt,
    'WRITE_UNAVAILABLE' => l.failed,
    'WRITE_PENDING' => l.loading,
    _ => l.unknownState,
  };
}

String _configurationKey(rpc.MetadataIntrospectionConfiguration value) {
  List<String> names(Iterable<String> values) => values.toList()..sort();
  final scopes = value.scopeLevels.toList()
    ..sort((a, b) {
      final catalog = a.catalog.compareTo(b.catalog);
      return catalog != 0 ? catalog : a.schema.compareTo(b.schema);
    });
  return jsonEncode([
    names(value.includedCatalogs),
    names(value.excludedCatalogs),
    names(value.includedSchemas),
    names(value.excludedSchemas),
    value.systemObjects,
    value.kinds.map((kind) => kind.value).toList()..sort(),
    value.includePatterns,
    value.excludePatterns,
    value.defaultLevel,
    [
      for (final scope in scopes) [scope.catalog, scope.schema, scope.level],
    ],
  ]);
}

Future<void> showMetadataSettings(
  BuildContext context,
  DesktopControls controls,
  WorkbenchModel model,
  String sessionId,
) async {
  final captured = model.captureSessionTarget(sessionId);
  await controls.dialog<void>(
    context,
    strings(context).metadataSettings,
    _MetadataSettings(controls: controls, model: model, target: captured),
    [
      controls.button(
        strings(context).close,
        () => Navigator.of(context).pop(),
      ),
    ],
    bodyScrolls: true,
  );
}

class _MetadataNames {
  _MetadataNames(Iterable<String> names, VoidCallback changed)
    : values = [
        for (final name in names)
          TextEditingController(text: name)..addListener(changed),
      ];
  final List<TextEditingController> values;
  List<String> read() => [
    for (final field in values)
      if (field.text.isNotEmpty) field.text,
  ];
  void dispose() {
    for (final field in values) {
      field.dispose();
    }
  }
}

class _MetadataLevel {
  _MetadataLevel(
    String catalog,
    String schema,
    this.level,
    VoidCallback changed,
  ) : catalog = TextEditingController(text: catalog)..addListener(changed),
      schema = TextEditingController(text: schema)..addListener(changed);
  final TextEditingController catalog, schema;
  int level;
  void dispose() {
    catalog.dispose();
    schema.dispose();
  }
}

class _MetadataSettings extends StatefulWidget {
  const _MetadataSettings({
    required this.controls,
    required this.model,
    required this.target,
  });
  final DesktopControls controls;
  final WorkbenchModel model;
  final CapturedWorkbenchTarget target;
  @override
  State<_MetadataSettings> createState() => _MetadataSettingsState();
}

class _MetadataSettingsState extends State<_MetadataSettings> {
  rpc.MetadataSettingsReply? reply;
  ResponseFuture<rpc.MetadataSettingsReply>? pending;
  final names = <String, _MetadataNames>{};
  final scopeLevels = <_MetadataLevel>[];
  final kinds = <rpc.ObjectKind>{};
  final previousPages = <int>[];
  final editorFocus = FocusNode(debugLabel: 'Metadata configuration');
  String section = 'configuration', category = 'includedCatalogs';
  String? error;
  bool busy = false, systemObjects = false;
  int level = 2, epoch = 0, offset = 0;
  static const maxNames = 2048;
  @override
  void initState() {
    super.initState();
    unawaited(request(rpc.MetadataSettingsAction.READ_METADATA_SETTINGS));
  }

  @override
  void dispose() {
    epoch++;
    final call = pending;
    if (call != null) unawaited(call.cancel());
    for (final group in names.values) {
      group.dispose();
    }
    for (final scope in scopeLevels) {
      scope.dispose();
    }
    editorFocus.dispose();
    super.dispose();
  }

  void changed() {
    if (mounted && !busy) setState(() {});
  }

  void initialize(rpc.MetadataIntrospectionConfiguration config) {
    for (final group in names.values) {
      group.dispose();
    }
    names.clear();
    names.addAll({
      'includedCatalogs': _MetadataNames(config.includedCatalogs, changed),
      'excludedCatalogs': _MetadataNames(config.excludedCatalogs, changed),
      'includedSchemas': _MetadataNames(config.includedSchemas, changed),
      'excludedSchemas': _MetadataNames(config.excludedSchemas, changed),
      'includePatterns': _MetadataNames(config.includePatterns, changed),
      'excludePatterns': _MetadataNames(config.excludePatterns, changed),
    });
    for (final scope in scopeLevels) {
      scope.dispose();
    }
    scopeLevels.clear();
    scopeLevels.addAll(
      config.scopeLevels.map(
        (s) => _MetadataLevel(s.catalog, s.schema, s.level, changed),
      ),
    );
    kinds
      ..clear()
      ..addAll(config.kinds);
    systemObjects = config.systemObjects;
    level = config.defaultLevel;
  }

  rpc.MetadataIntrospectionConfiguration configuration() {
    final result = rpc.MetadataIntrospectionConfiguration(
      includedCatalogs: names['includedCatalogs']!.read(),
      excludedCatalogs: names['excludedCatalogs']!.read(),
      includedSchemas: names['includedSchemas']!.read(),
      excludedSchemas: names['excludedSchemas']!.read(),
      includePatterns: names['includePatterns']!.read(),
      excludePatterns: names['excludePatterns']!.read(),
      systemObjects: systemObjects,
      defaultLevel: level,
      kinds: kinds.toList()..sort((a, b) => a.value.compareTo(b.value)),
      scopeLevels: scopeLevels.map(
        (s) => rpc.MetadataScopeLevel(
          catalog: s.catalog.text,
          schema: s.schema.text,
          level: s.level,
        ),
      ),
    );
    if (result.writeToBuffer().length > 120000 ||
        result.includedCatalogs.length +
                result.excludedCatalogs.length +
                result.includedSchemas.length +
                result.excludedSchemas.length +
                result.scopeLevels.length >
            maxNames ||
        result.includePatterns.length + result.excludePatterns.length > 64 ||
        names.values
            .expand((g) => g.values)
            .any((v) => v.text.length > 512 || v.text.contains('\u0000')) ||
        scopeLevels.any(
          (s) =>
              s.catalog.text.length > 256 ||
              s.schema.text.length > 256 ||
              s.catalog.text.contains('\u0000') ||
              s.schema.text.contains('\u0000'),
        )) {
      throw const FormatException('METADATA_CONFIGURATION_LIMIT');
    }
    return result;
  }

  bool get dirty {
    if (reply == null) return false;
    try {
      return _configurationKey(configuration()) !=
          _configurationKey(reply!.configuration);
    } catch (_) {
      return true;
    }
  }

  Future<void> request(
    rpc.MetadataSettingsAction action, {
    int page = 0,
  }) async {
    if (busy) return;
    final generation = ++epoch, previous = reply;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      widget.model.requireTarget(widget.target);
      final request = rpc.MetadataSettingsRequest(
        context: widget.target.backend.context(),
        sessionId: widget.target.sessionId,
        contextRevision: widget.target.contextRevision,
        sessionRevision: widget.target.sessionRevision,
        action: action,
        expectedConfigurationRevision:
            previous?.configurationRevision ?? Int64.ZERO,
        expectedSnapshotRevision: page == 0
            ? Int64.ZERO
            : previous?.snapshotRevision,
        offset: page,
        limit: 64,
        configuration:
            action == rpc.MetadataSettingsAction.SAVE_METADATA_SETTINGS
            ? configuration()
            : null,
      );
      final call = widget.target.backend.client.metadataSettings(request);
      pending = call;
      final result = await call;
      if (!mounted || generation != epoch) return;
      widget.model.requireTarget(widget.target);
      if (result.backendInstance != widget.target.backend.instanceId ||
          result.sessionId != widget.target.sessionId ||
          result.profileId != widget.target.profileId ||
          result.contextRevision != widget.target.contextRevision ||
          result.sessionRevision != widget.target.sessionRevision ||
          result.scopes.length > 64 ||
          result.writeToBuffer().length > 131072 ||
          result.configuration.defaultLevel < 1 ||
          result.configuration.defaultLevel > 3) {
        throw StateError('METADATA_OWNER_CHANGED');
      }
      if (!widget.model.acceptMetadataSnapshotRevision(
        result.sessionId,
        result.snapshotRevision.toInt(),
        result.configurationRevision.toInt(),
        sourceIdentity: result.metadataSourceIdentity,
      )) {
        throw StateError('METADATA_OWNER_CHANGED');
      }
      if (reply == null ||
          action == rpc.MetadataSettingsAction.SAVE_METADATA_SETTINGS) {
        initialize(result.configuration);
      }
      setState(() {
        reply = result;
        offset = page;
        busy = false;
        pending = null;
      });
    } catch (_) {
      if (mounted && generation == epoch) {
        setState(() {
          error = strings(context).metadataConfigurationChanged;
          busy = false;
          pending = null;
        });
      }
    }
  }

  void cancel() {
    epoch++;
    final call = pending;
    if (call != null) unawaited(call.cancel());
    setState(() {
      busy = false;
      pending = null;
      error = strings(context).cancelled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = strings(context), ui = widget.controls;
    final categories = {
      'includedCatalogs': l.metadataIncludeCatalogs,
      'excludedCatalogs': l.metadataExcludeCatalogs,
      'includedSchemas': l.metadataIncludeSchemas,
      'excludedSchemas': l.metadataExcludeSchemas,
      'includePatterns': l.metadataIncludePatterns,
      'excludePatterns': l.metadataExcludePatterns,
      'kinds': l.metadataObjectKinds,
      'levels': l.metadataScopeLevels,
    };
    final levels = {
      1: l.metadataLevelNames,
      2: l.metadataLevelStructure,
      3: l.metadataLevelSource,
    };
    return WorkbenchDialogBody(
      maxHeight: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.target.profile?.name ?? ''),
          ui.choice(section, {
            'configuration': l.metadataSettings,
            'status': l.metadataCacheState,
          }, (v) => setState(() => section = v)),
          if (error != null) ui.status(error!, error: true),
          if (busy)
            Row(
              children: [
                Expanded(child: ui.status(l.loading)),
                ui.textButton(l.cancel, cancel),
              ],
            ),
          if (reply == null)
            Expanded(
              child: Center(
                child: ui.textButton(
                  l.refresh,
                  busy
                      ? null
                      : () => request(
                          rpc.MetadataSettingsAction.READ_METADATA_SETTINGS,
                        ),
                ),
              ),
            )
          else if (section == 'configuration') ...[
            ui.choice(
              level,
              levels,
              (v) => setState(() => level = v),
              label: l.metadataDefaultLevel,
              enabled: !busy,
            ),
            ui.checkbox(
              l.metadataSystemObjects,
              systemObjects,
              busy ? null : (v) => setState(() => systemObjects = v),
            ),
            ui.choice(
              category,
              categories,
              (v) => setState(() => category = v),
            ),
            if (category == 'kinds')
              Expanded(
                child: ListView(
                  children: [
                    for (final kind in rpc.ObjectKind.values)
                      ui.checkbox(
                        workbenchObjectType(context, kind),
                        kinds.contains(kind),
                        busy
                            ? null
                            : (v) => setState(
                                () => v ? kinds.add(kind) : kinds.remove(kind),
                              ),
                      ),
                  ],
                ),
              )
            else if (category == 'levels')
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: scopeLevels.length,
                        itemBuilder: (context, index) {
                          final item = scopeLevels[index];
                          return Column(
                            children: [
                              ui.field(
                                item.catalog,
                                l.databases,
                                enabled: !busy,
                              ),
                              ui.field(item.schema, l.schema, enabled: !busy),
                              Row(
                                children: [
                                  Expanded(
                                    child: ui.choice(
                                      item.level,
                                      levels,
                                      (v) => setState(() => item.level = v),
                                      enabled: !busy,
                                    ),
                                  ),
                                  ui.iconButton(
                                    DesktopIcon.close,
                                    l.close,
                                    busy
                                        ? null
                                        : () => setState(() {
                                            scopeLevels
                                                .removeAt(index)
                                                .dispose();
                                          }),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    ui.textButton(
                      l.metadataAddScope,
                      busy || scopeLevels.length >= maxNames
                          ? null
                          : () => setState(
                              () => scopeLevels.add(
                                _MetadataLevel('', '', level, changed),
                              ),
                            ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    if (category.endsWith('Patterns'))
                      Text(l.metadataPatternsNote),
                    Expanded(
                      child: ListView.builder(
                        itemCount: names[category]!.values.length,
                        itemBuilder: (context, index) => Row(
                          children: [
                            Expanded(
                              child: ui.field(
                                names[category]!.values[index],
                                categories[category]!,
                                enabled: !busy,
                              ),
                            ),
                            ui.iconButton(
                              DesktopIcon.close,
                              l.close,
                              busy
                                  ? null
                                  : () => setState(
                                      () => names[category]!.values
                                          .removeAt(index)
                                          .dispose(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ui.textButton(
                      l.metadataAddName,
                      busy ||
                              names.values.fold<int>(
                                    0,
                                    (n, g) => n + g.values.length,
                                  ) >=
                                  maxNames
                          ? null
                          : () => setState(
                              () => names[category]!.values.add(
                                TextEditingController()..addListener(changed),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ui.button(
                  l.saveProfile,
                  busy
                      ? null
                      : () => request(
                          rpc.MetadataSettingsAction.SAVE_METADATA_SETTINGS,
                        ),
                  primary: true,
                ),
                ui.textButton(
                  l.metadataFullRefresh,
                  busy || dirty
                      ? null
                      : () => request(
                          rpc.MetadataSettingsAction.FULL_METADATA_REFRESH,
                        ),
                ),
                ui.textButton(
                  l.metadataIncrementalRefresh,
                  busy || dirty
                      ? null
                      : () => request(
                          rpc
                              .MetadataSettingsAction
                              .INCREMENTAL_METADATA_REFRESH,
                        ),
                ),
              ],
            ),
          ] else ...[
            Text(
              '${l.metadataCacheState}: ${_cacheStateLabel(context, reply!.cacheState)} · ${reply!.configurationRevision} / ${reply!.snapshotRevision}',
            ),
            if (reply!.cacheState == 'WRITE_UNAVAILABLE')
              ui.status(l.metadataCacheWriteUnavailable, error: true),
            Text(
              '${reply!.refreshStrategy} · ${reply!.scannedScopes} / ${reply!.fetchedScopes} / ${reply!.fetchedObjects} · ${reply!.refreshDurationMs} ms',
            ),
            Expanded(
              child: ListView.builder(
                itemCount: reply!.scopes.length,
                itemBuilder: (context, index) {
                  final scope = reply!.scopes[index];
                  return ui.recordContent(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${scope.catalog} / ${scope.schema} / ${scope.parent} · ${workbenchObjectType(context, scope.kind)}',
                        ),
                        Text(
                          '${levels[scope.level]} · ${scope.state} · ${scope.objectCount}',
                        ),
                        if (scope.lastSuccessfulRefreshUnixMs != Int64.ZERO)
                          Text(
                            '${l.metadataLastRefresh}: ${DateTime.fromMillisecondsSinceEpoch(scope.lastSuccessfulRefreshUnixMs.toInt()).toLocal()}',
                          ),
                        if (scope.limitation.isNotEmpty) Text(scope.limitation),
                      ],
                    ),
                  );
                },
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                ui.textButton(
                  l.previousPage,
                  busy || previousPages.isEmpty
                      ? null
                      : () {
                          final page = previousPages.removeLast();
                          unawaited(
                            request(
                              rpc.MetadataSettingsAction.READ_METADATA_SETTINGS,
                              page: page,
                            ),
                          );
                        },
                ),
                ui.textButton(
                  l.nextRows,
                  busy || reply!.complete
                      ? null
                      : () {
                          previousPages.add(offset);
                          unawaited(
                            request(
                              rpc.MetadataSettingsAction.READ_METADATA_SETTINGS,
                              page: reply!.nextOffset,
                            ),
                          );
                        },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
