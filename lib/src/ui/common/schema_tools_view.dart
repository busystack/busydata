import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'er_diagram_export.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show SelectableText;
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import '../../features/workspace/documents.dart';
import '../../platform/common/output_commit.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'result_grid.dart';
import 'plan_view.dart';
import '../../l10n/workbench_strings.dart';
import 'workbench_document_view.dart';
import 'package:fixnum/fixnum.dart';

Future<OutputDestination?> reviewOutputDestination(
  BuildContext context,
  DesktopControls ui,
  String path,
) async {
  final destination = await OutputDestination.capture(File(path));
  if (!context.mounted) return null;
  if (destination.exists) {
    final approved = await ui.dialog<bool>(
      context,
      strings(context).replaceText,
      SelectableText(strings(context).replaceFileReview(destination.file.path)),
      [
        ui.button(
          strings(context).cancel,
          () => Navigator.of(context).pop(false),
        ),
        ui.button(
          strings(context).replaceText,
          () => Navigator.of(context).pop(true),
          primary: true,
        ),
      ],
    );
    if (approved != true || !context.mounted) return null;
  }
  return destination;
}

class SchemaToolsView {
  const SchemaToolsView(
    this.model,
    this.ui, {
    this.owner,
    this.object,
    this.creationScope,
  });
  final WorkbenchDocument? owner;
  final DatabaseObjectIdentity? object;
  final DatabaseCreationScope? creationScope;
  WorkbenchDocument get targetOwner => owner ?? model.activeOwner;
  String get targetSchema =>
      object?.schema ??
      creationScope?.schema ??
      targetOwner.object?.schema ??
      (targetOwner.referenceSchema.isNotEmpty
          ? targetOwner.referenceSchema
          : model.sessions[targetOwner.sessionId]?.currentSchema ?? '');
  String get targetTable => object?.parent.isNotEmpty == true
      ? object!.parent
      : object != null &&
            [
              rpc.ObjectKind.TABLE,
              rpc.ObjectKind.VIEW,
              rpc.ObjectKind.ROUTINE,
            ].contains(object!.kind)
      ? object!.name
      : targetOwner.object?.name ?? '';
  final WorkbenchModel model;
  final DesktopControls ui;
  rpc.SchemaToolRequest request(rpc.SchemaToolAction action) =>
      rpc.SchemaToolRequest(
        context: model.context,
        sessionId: targetOwner.sessionId,
        action: action,
        schema: targetSchema,
        table: targetTable,
      );
  Future<void> snapshot(BuildContext context) async {
    final l = strings(context);
    final capturedTarget = model.captureTarget(owner: targetOwner);
    final command = request(rpc.SchemaToolAction.CAPTURE_SCHEMA);
    final data = await model.ownedRequest(
      capturedTarget,
      () => capturedTarget.backend.client.schemaTool(command),
    );
    model.requireTarget(capturedTarget);
    final target = await getSaveLocation(suggestedName: 'schema.busydata.json');
    if (target == null || !context.mounted) return;
    final destination = await reviewOutputDestination(context, ui, target.path);
    if (destination == null) return;
    model.requireTarget(capturedTarget);
    await atomicWrite(
      File(target.path),
      utf8.encode(data.snapshot),
      destination: destination,
    );
    model.updateStatus('${l.saveSnapshot} · ${l.completed}: ${target.path}');
  }

  Future<void> compare(BuildContext context) async {
    final profile = targetOwner.profileId;
    final owner = model.openTask(
      WorkbenchDocumentKind.comparison,
      strings(context).schemaComparison,
      profileId: profile,
      reuse: false,
    );
    owner.payload = ComparisonData(schema: targetSchema, profileId: profile);
    owner.reopenCommandId = 'schema.compare';
    owner.referenceSchema = targetSchema;
    model.updateStatus(owner.displayTitle);
  }

  Future<void> designer(BuildContext context) async {
    final initiatingActiveId = model.activeOwner.id;
    final schema = targetSchema, table = targetTable;
    final object = this.object ?? targetOwner.object;
    final requestedProfile =
        model.sessions[targetOwner.sessionId]?.profile ??
        targetOwner.evidenceProfile;
    final title = '${strings(context).objectDesigner} · $schema.$table';
    final existing = model.taskDocuments
        .where(
          (d) =>
              d.kind == WorkbenchDocumentKind.structure &&
              d.purpose == 'design' &&
              d.profileId == targetOwner.profileId &&
              (identical(d, targetOwner) ||
                  (requestedProfile != null &&
                      model.documentMatchesProfile(d, requestedProfile))) &&
              (object != null ? d.object == object : d.title == title),
        )
        .firstOrNull;
    if (existing != null &&
        (existing.sessionId == null ||
            !model.sessions.containsKey(existing.sessionId))) {
      throw StateError(
        'Connect this design document explicitly before inspecting fresh metadata',
      );
    }
    final capturedTarget = model.captureTarget(owner: existing ?? targetOwner);
    final target = rpc.SchemaToolRequest(
      context: capturedTarget.backend.context(),
      sessionId: capturedTarget.sessionId,
      action: rpc.SchemaToolAction.INSPECT_OBJECT,
      schema: schema,
      table: table,
    );
    final backend = model.backend!;
    final sessionId = capturedTarget.sessionId,
        profileId = targetOwner.profileId;
    bool valid() {
      try {
        model.requireTarget(capturedTarget);
        return true;
      } catch (_) {
        return false;
      }
    }

    final inspected = await model.ownedRequest(
      capturedTarget,
      () => backend.client.schemaTool(target),
    );
    if (!context.mounted || !valid()) return;
    final units =
        inspected.snapshot.length * 4 + inspected.definition.length * 2;
    if (existing == null) {
      model.documentBudget.requireAdditional(
        0,
        units + ObjectDesignerDraft().bytes * 2,
      );
    }
    final owner = model.openTask(
      WorkbenchDocumentKind.structure,
      title,
      purpose: 'design',
      object: table.isEmpty ? null : object,
      creationScope: table.isEmpty
          ? DatabaseCreationScope(
              profileId: profileId ?? '',
              catalog: model.sessions[sessionId]?.currentCatalog ?? '',
              schema: schema,
            )
          : null,
      profileId: profileId,
      evidenceProfile: capturedTarget.profile,
      activate: model.activeOwner.id == initiatingActiveId,
    );
    model.reserveDocumentEvidence(owner, units);
    owner.referenceSchema = schema;
    owner.sessionId ??= sessionId;
    owner.evidenceProfile = capturedTarget.profile?.deepCopy();
    owner.payload = DesignerData(
      model.captureTarget(owner: owner),
      target,
      inspected,
      owner.designDraft,
    );
    model.updateStatus(owner.displayTitle);
  }

  Future<void> plan(BuildContext context, {bool openDocument = false}) async {
    final result = model.resultForOwner(targetOwner);
    if (result == null || !result.plan) {
      throw StateError('Select a retained Explain execution');
    }
    final initiatingActiveId = model.activeOwner.id;
    final cached = targetOwner.view.results[result.resultId]?.planEvidence;
    if (cached is PlanData) {
      showPlan(
        context,
        result,
        cached,
        openDocument: openDocument,
        activate: model.activeOwner.id == initiatingActiveId,
      );
      return;
    }
    final existing = model.taskDocuments
        .where(
          (d) =>
              d.kind == WorkbenchDocumentKind.plan &&
              d.retained?.result.resultId == result.resultId,
        )
        .firstOrNull;
    if (existing != null && openDocument) {
      model.activateOwner(existing.id);
      return;
    }
    final backend = model.backend!;
    final rows = <rpc.Row>[];
    int offset = 0, bytes = 0;
    while (true) {
      final page = await backend.client.resultPage(
        rpc.PageRequest(
          context: backend.context(),
          resultId: result.resultId,
          offset: Int64(offset),
          limit: 100,
          maxBytes: 262144,
        ),
      );
      if (!identical(model.backend, backend)) {
        throw StateError('Backend changed; retained plan handle is stale');
      }
      bytes += page.writeToBuffer().length;
      if (bytes > 1048576 || rows.length + page.rows.length > 4096) {
        throw StateError(
          'Plan inspector limit reached; inspect or export the retained cells',
        );
      }
      rows.addAll(page.rows);
      if (page.state == rpc.PageState.PAGE_END) break;
      if (page.nextOffset.toInt() <= offset) {
        throw StateError(
          'Plan is still fetching or unavailable; retry after fetching completes',
        );
      }
      offset = page.nextOffset.toInt();
    }
    final raw = StringBuffer();
    for (final row in rows) {
      if (row.values.isEmpty) continue;
      final value = row.values.first;
      if (value.valueId.isNotEmpty) {
        int position = 0;
        final decoded = const Utf8Decoder().startChunkedConversion(
          StringConversionSink.fromStringSink(raw),
        );
        while (true) {
          final chunk = await backend.client.resultValue(
            rpc.ValueRequest(
              context: backend.context(),
              resultId: result.resultId,
              valueId: value.valueId,
              offset: Int64(position),
              maxBytes: 65536,
            ),
          );
          decoded.add(chunk.data);
          position += chunk.data.length;
          if (raw.length > 1048576) {
            throw StateError(
              'Plan exceeds the 1MiB inspector limit; export the retained value',
            );
          }
          if (chunk.complete) {
            decoded.close();
            break;
          }
          if (chunk.data.isEmpty) {
            throw StateError('Plan value retrieval made no progress');
          }
        }
      } else {
        raw.write(valueText(value));
      }
      raw.writeln();
    }
    final data = PlanData.parse(raw.toString());
    if (!context.mounted) return;
    if (!identical(model.backend, backend) ||
        !model.workbenchDocuments.contains(targetOwner) ||
        model.disposedResults.contains(result.resultId)) {
      throw StateError('Retained plan became unavailable; no SQL was rerun');
    }
    final units =
        data.raw.length +
        data.entries.fold<int>(0, (n, e) => n + e.label.length + 32);
    model.reserveResultEvidence(targetOwner, result.resultId, units);
    model.resultView(result.resultId, owner: targetOwner).planEvidence = data;
    showPlan(
      context,
      result,
      data,
      openDocument: openDocument,
      activate: model.activeOwner.id == initiatingActiveId,
    );
  }

  void showPlan(
    BuildContext context,
    rpc.StatementResult result,
    PlanData data, {
    required bool openDocument,
    required bool activate,
  }) {
    if (!openDocument) {
      if (model.resultForOwner(targetOwner)?.resultId == result.resultId) {
        targetOwner.view.output = 'plan';
      }
      model.updateStatus(strings(context).planReady);
      return;
    }
    final units =
        data.raw.length +
        data.entries.fold<int>(0, (n, e) => n + e.label.length + 32);
    final existing = model.taskDocuments
        .where(
          (d) =>
              d.kind == WorkbenchDocumentKind.plan &&
              d.retained?.result.resultId == result.resultId,
        )
        .firstOrNull;
    if (existing == null) {
      model.documentBudget.requireAdditional(
        0,
        units + ObjectDesignerDraft().bytes * 2,
      );
    }
    final owner = model.openTask(
      WorkbenchDocumentKind.plan,
      '${strings(context).executionPlan} · ${model.retainedResults[result.resultId]?.target.name ?? result.resultId}',
      payload: existing?.payload ?? PlanData(data.raw, data.entries),
      retained: model.retainedResults[result.resultId],
      profileId: model.retainedResults[result.resultId]?.target.id,
      activate: activate,
    );
    model.reserveDocumentEvidence(owner, units);
  }

  Future<void> diagram(BuildContext context) async {
    final initiatingActiveId = model.activeOwner.id;
    final captured = model.captureTarget(owner: targetOwner);
    final schema = targetSchema, selectedTable = targetTable;
    final scope = DatabaseObjectIdentity(
      profileId: captured.profile?.id ?? targetOwner.profileId ?? '',
      catalog: captured.session?.currentCatalog ?? '',
      schema: schema,
      kind: selectedTable.isEmpty
          ? rpc.ObjectKind.SCHEMA
          : rpc.ObjectKind.TABLE,
      name: selectedTable.isEmpty ? schema : selectedTable,
    );
    final existing = model.taskDocuments
        .where(
          (d) =>
              d.kind == WorkbenchDocumentKind.diagram &&
              d.object == scope &&
              captured.profile != null &&
              model.documentMatchesProfile(d, captured.profile!),
        )
        .firstOrNull;
    if (existing != null) {
      model.activateOwner(existing.id);
      return;
    }
    final tableReply = await model.readMetadata(
      captured,
      rpc.ExploreRequest(
        context: captured.backend.context(),
        sessionId: captured.sessionId,
        kind: rpc.ObjectKind.TABLE,
        schema: schema,
        table: selectedTable,
      ),
      maxObjects: 101,
    );
    model.requireTarget(captured);
    final tables = tableReply.objects
        .where((t) => selectedTable.isEmpty || t.name == selectedTable)
        .toList();
    if (tableReply.availability.startsWith('limited') || !tableReply.complete) {
      throw StateError(
        'Diagram metadata is incomplete; narrow the schema/table selection or search for the exact object',
      );
    }
    if (tables.length > 100) {
      throw StateError(
        'ER view supports at most 100 tables; select a narrower scope',
      );
    }
    final edges = <rpc.SchemaObject>[];
    for (final table in tables) {
      final response = await model.readMetadata(
        captured,
        rpc.ExploreRequest(
          context: captured.backend.context(),
          sessionId: captured.sessionId,
          kind: rpc.ObjectKind.FOREIGN_KEY,
          schema: schema,
          table: table.name,
        ),
        maxObjects: 10000 - edges.length,
      );
      model.requireTarget(captured);
      if (response.availability.startsWith('limited') || !response.complete) {
        throw StateError(
          'Diagram relationships are incomplete; narrow the schema/table selection',
        );
      }
      if (edges.length + response.objects.length > 10000) {
        throw StateError(
          'Diagram relationship budget reached; narrow the selection',
        );
      }
      edges.addAll(response.objects);
      model.documentBudget.requireAdditional(
        0,
        edges.fold<int>(0, (n, e) => n + e.writeToBuffer().length * 4),
      );
    }
    if (!context.mounted) return;
    final units =
        tables.fold<int>(0, (n, t) => n + t.writeToBuffer().length) * 4 +
        edges.fold<int>(0, (n, e) => n + e.writeToBuffer().length) * 4;
    model.documentBudget.requireAdditional(
      0,
      units + ObjectDesignerDraft().bytes * 2,
    );
    final diagramOwner = model.openTask(
      WorkbenchDocumentKind.diagram,
      'ER · $schema',
      object: scope,
      evidenceProfile: captured.profile,
      profileId: model.sessions[captured.sessionId]?.profile.id,
      activate: model.activeOwner.id == initiatingActiveId,
      payload: DiagramDocumentData(
        tables,
        edges,
        profileId: targetOwner.profileId,
        catalog: model.sessions[captured.sessionId]?.currentCatalog ?? '',
        schema: schema,
      ),
    );
    model.reserveDocumentEvidence(diagramOwner, units);
    diagramOwner.evidenceProfile = captured.profile?.deepCopy();
    diagramOwner.reopenCommandId = 'schema.diagram';
    diagramOwner.referenceSchema = schema;
  }
}

class DiagramDocumentData {
  DiagramDocumentData(
    this.tables,
    this.edges, {
    this.profileId = '',
    this.catalog = '',
    this.schema = '',
  });
  final List<rpc.SchemaObject> tables, edges;
  final String? profileId;
  final String catalog, schema;
  String search = '', notes = '', focused = '';
  List<double>? transform;
  Size viewport = Size.zero;
}

Future<void> saveMigrationSql(
  BuildContext context,
  DesktopControls ui,
  String sql,
) async {
  final selected = await getSaveLocation(suggestedName: 'migration.sql');
  if (selected == null || !context.mounted) return;
  final destination = await reviewOutputDestination(context, ui, selected.path);
  if (destination == null) return;
  await atomicWrite(
    File(selected.path),
    utf8.encode(sql),
    destination: destination,
  );
}

class DiagramDocumentView extends StatefulWidget {
  const DiagramDocumentView({
    super.key,
    required this.model,
    required this.tables,
    required this.edges,
    required this.ui,
    this.state,
  });
  final DiagramDocumentData? state;
  final WorkbenchModel model;
  final List<rpc.SchemaObject> tables, edges;
  final DesktopControls ui;
  @override
  State<DiagramDocumentView> createState() => _DiagramState();
}

class _DiagramState extends State<DiagramDocumentView> {
  final search = TextEditingController(), notes = TextEditingController();
  String focused = '';
  final transform = TransformationController();
  final canvasFocus = FocusNode(debugLabel: 'Diagram canvas');
  Size viewport = Size.zero;
  Size nodeSize = const Size(180, 60);
  double get graphWidth => (nodeSize.width + 30) * 4 + 20;
  double get graphHeight =>
      (widget.tables.length / 4).ceil() * (nodeSize.height + 50) + 20;
  Offset viewPosition(String name) {
    final i = widget.tables.indexWhere((table) => table.name == name);
    return Offset(
      (i % 4) * (nodeSize.width + 30) + 15,
      (i ~/ 4) * (nodeSize.height + 50) + 15,
    );
  }

  Size appliedViewport = Size.zero;
  bool resizePending = false;
  void resizeViewport(Size size) {
    if (viewport == size) return;
    viewport = size;
    if (resizePending) return;
    resizePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      resizePending = false;
      if (!mounted) return;
      final previous = appliedViewport;
      appliedViewport = viewport;
      if (previous.isEmpty || viewport.isEmpty || previous == viewport) return;
      final matrix = transform.value.clone();
      matrix.setEntry(
        0,
        3,
        matrix.entry(0, 3) + (viewport.width - previous.width) / 2,
      );
      matrix.setEntry(
        1,
        3,
        matrix.entry(1, 3) + (viewport.height - previous.height) / 2,
      );
      transform.value = matrix;
    });
  }

  void zoom(double factor) {
    final scale = transform.value.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(0.2, 3.0);
    transform.value = transform.value.clone()
      ..scaleByDouble(next / scale, next / scale, 1, 1);
  }

  void focusTable() {
    if (!widget.tables.any((t) => t.name == search.text)) {
      widget.model.updateStatus(strings(context).empty);
      return;
    }
    setState(() => focused = search.text);
    canvasFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final point = viewPosition(focused),
          scale = transform.value.getMaxScaleOnAxis();
      appliedViewport = viewport;
      transform.value = transform.value.clone()
        ..setEntry(
          0,
          3,
          viewport.width / 2 - (point.dx + nodeSize.width / 2) * scale,
        )
        ..setEntry(
          1,
          3,
          viewport.height / 2 - (point.dy + nodeSize.height / 2) * scale,
        );
    });
  }

  KeyEventResult canvasKey(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus ||
        event is! KeyDownEvent ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.home) {
      transform.value = Matrix4.identity();
    } else if (key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.numpadAdd) {
      zoom(1.2);
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      zoom(1 / 1.2);
    } else if ([
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ].contains(key)) {
      final matrix = transform.value.clone();
      matrix.setEntry(
        0,
        3,
        (matrix.entry(0, 3) +
                (key == LogicalKeyboardKey.arrowLeft
                    ? -40
                    : key == LogicalKeyboardKey.arrowRight
                    ? 40
                    : 0))
            .clamp(-10000.0, 10000.0),
      );
      matrix.setEntry(
        1,
        3,
        (matrix.entry(1, 3) +
                (key == LogicalKeyboardKey.arrowUp
                    ? -40
                    : key == LogicalKeyboardKey.arrowDown
                    ? 40
                    : 0))
            .clamp(-10000.0, 10000.0),
      );
      transform.value = matrix;
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    super.initState();
    final saved = widget.state;
    if (saved != null) {
      search.text = saved.search;
      notes.text = saved.notes;
      focused = saved.focused;
      appliedViewport = saved.viewport;
      if (saved.transform case final values?) {
        transform.value = Matrix4.fromList(values);
      }
    }
  }

  Future<void> notesFile(bool opening) async {
    if (opening) {
      final file = await openFile(
        confirmButtonText: strings(context).openNotes,
      );
      if (file == null) return;
      if (await file.length() > 65536) {
        throw StateError('Diagram notes file exceeds 64KiB');
      }
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (data['version'] != 1 ||
          data['notes'] is! String ||
          (data['notes'] as String).length > 10000) {
        throw StateError('Unsupported or invalid diagram notes');
      }
      if (!mounted) return;
      notes.text = data['notes'] as String;
    } else {
      final capturedNotes = notes.text;
      if (capturedNotes.length > 10000) {
        throw StateError('Diagram notes limit is 10,000 characters');
      }
      final target = await getSaveLocation(
        suggestedName: 'schema-er-notes.busydata.json',
      );
      if (target == null || !mounted) return;
      final destination = await reviewOutputDestination(
        context,
        widget.ui,
        target.path,
      );
      if (destination == null || !mounted) return;
      await atomicWrite(
        File(target.path),
        utf8.encode(
          const JsonEncoder.withIndent(
            '  ',
          ).convert({'version': 1, 'notes': capturedNotes}),
        ),
        destination: destination,
      );
    }
  }

  Future<void> exportImage() async {
    final savedNotice = strings(context).diagramPngSaved;
    final capturedNotes = notes.text;
    final target = await getSaveLocation(suggestedName: 'schema-er.png');
    if (target == null || !mounted) return;
    final destination = await reviewOutputDestination(
      context,
      widget.ui,
      target.path,
    );
    if (destination == null || !mounted) return;
    final data = await renderErDiagramPng(
      tables: widget.tables,
      edges: widget.edges,
      notes: capturedNotes,
      foreground: widget.ui.foreground(context),
      background: widget.ui.background(context),
      style: widget.ui.textStyle(context),
      direction: Directionality.of(context),
    );
    await atomicWrite(File(target.path), data, destination: destination);
    widget.model.updateStatus(savedNotice);
  }

  @override
  void dispose() {
    final saved = widget.state;
    if (saved != null) {
      saved.search = search.text;
      saved.notes = notes.text;
      saved.focused = focused;
      saved.transform = transform.value.storage.toList();
      saved.viewport = appliedViewport;
    }
    canvasFocus.dispose();
    transform.dispose();
    search.dispose();
    notes.dispose();
    super.dispose();
  }

  Offset position(String name) {
    final i = widget.tables.indexWhere((t) => t.name == name);
    return Offset((i % 4) * 210.0 + 15, (i ~/ 4) * 110.0 + 15);
  }

  String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('"', '&quot;');
  Future<void> export() async {
    final capturedNotes = notes.text;
    final target = await getSaveLocation(suggestedName: 'schema-er.svg');
    if (target == null || !mounted) return;
    final destination = await reviewOutputDestination(
      context,
      widget.ui,
      target.path,
    );
    if (destination == null || !mounted) return;
    final b = StringBuffer(
      '<svg xmlns="http://www.w3.org/2000/svg" width="850" height="${(widget.tables.length / 4).ceil() * 110 + 80}"><rect width="100%" height="100%" fill="white"/>',
    );
    for (final e in widget.edges) {
      if (!widget.tables.any(
        (t) => t.name == e.properties['referencedTable'],
      )) {
        continue;
      }
      final a = position(e.table),
          c = position(e.properties['referencedTable']!);
      b.write(
        '<path d="M${a.dx + 90},${a.dy + 30} L${c.dx + 90},${c.dy + 30}" stroke="#555" fill="none"/>',
      );
    }
    for (final t in widget.tables) {
      final p = position(t.name);
      b.write(
        '<rect x="${p.dx}" y="${p.dy}" width="180" height="60" rx="5" fill="#eee" stroke="#333"/><text x="${p.dx + 8}" y="${p.dy + 26}" font-family="sans-serif">${escape(t.name)}</text>',
      );
    }
    b.write(
      '<text x="15" y="${(widget.tables.length / 4).ceil() * 110 + 55}" font-family="sans-serif">${escape(capturedNotes)}</text></svg>',
    );
    await atomicWrite(
      File(target.path),
      utf8.encode(b.toString()),
      destination: destination,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => buildDiagram(
      context,
      bounds.maxHeight <
          (MediaQuery.textScalerOf(context).scale(14) > 21 ? 640 : 460),
      bounds.maxHeight < 400,
    ),
  );

  Future<void> inspectRelationships() => widget.ui.dialog<void>(
    context,
    '${strings(context).foreignKeys} · $focused',
    SizedBox(
      height: 240,
      child: ListView(
        children: [
          for (final edge in widget.edges.where(
            (edge) =>
                edge.table == focused ||
                edge.properties['referencedTable'] == focused,
          ))
            SelectableText(
              '${edge.name}: ${edge.table}.${edge.properties['column'] ?? ''} → ${edge.properties['referencedSchema'] ?? ''}.${edge.properties['referencedTable'] ?? ''}.${edge.properties['referencedColumn'] ?? ''}',
            ),
        ],
      ),
    ),
    [
      widget.ui.button(
        strings(context).close,
        () => Navigator.of(context).pop(),
      ),
    ],
  );

  Widget buildDiagram(BuildContext context, bool compact, bool tiny) {
    final look = widget.ui.appearance(context);
    final line = look.lineHeight(context);
    nodeSize = Size(math.max(180, line * 12), math.max(60, line * 2 + 20));
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, bounds) => Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: bounds.maxWidth.clamp(0.0, 320.0),
                child: widget.ui.filterField(
                  search,
                  strings(context).searchTable,
                ),
              ),
              widget.ui.button(strings(context).focusObject, focusTable),
              widget.ui.menu(
                compact ? strings(context).more : strings(context).viewMenu,
                [
                  DesktopMenuAction(
                    strings(context).zoomIn,
                    () => zoom(1.2),
                    shortcut: '+',
                  ),
                  DesktopMenuAction(
                    strings(context).zoomOut,
                    () => zoom(1 / 1.2),
                    shortcut: '-',
                  ),
                  DesktopMenuAction(
                    strings(context).resetView,
                    () => transform.value = Matrix4.identity(),
                    shortcut: 'Home',
                  ),
                  if (compact) ...[
                    DesktopMenuAction(
                      strings(context).foreignKeys,
                      inspectRelationships,
                    ),
                    DesktopMenuAction(
                      strings(context).exportSvg,
                      () => widget.model.command(export),
                    ),
                    DesktopMenuAction(
                      strings(context).exportPng,
                      () => widget.model.command(exportImage),
                    ),
                    DesktopMenuAction(
                      strings(context).diagramNotes,
                      () => widget.ui.dialog<void>(
                        context,
                        strings(context).diagramNotes,
                        widget.ui.field(notes, strings(context).diagramNotes),
                        [
                          widget.ui.button(
                            strings(context).close,
                            () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    DesktopMenuAction(
                      strings(context).openNotes,
                      () => widget.model.command(() => notesFile(true)),
                    ),
                    DesktopMenuAction(
                      strings(context).saveNotes,
                      () => widget.model.command(() => notesFile(false)),
                    ),
                  ],
                ],
              ),
              if (!compact)
                widget.ui.button(
                  strings(context).exportSvg,
                  () => widget.model.command(export),
                ),
              if (!compact)
                widget.ui.button(
                  strings(context).exportPng,
                  () => widget.model.command(exportImage),
                ),
            ],
          ),
        ),
        if (widget.tables.any((t) => t.name == focused)) ...[
          Text(
            '${strings(context).foreignKeys} · $focused',
            maxLines: compact ? 1 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
          ),
          if (!tiny)
            SizedBox(
              height: 80,
              child: Builder(
                builder: (context) {
                  final edges = widget.edges
                      .where(
                        (e) =>
                            e.table == focused ||
                            e.properties['referencedTable'] == focused,
                      )
                      .toList(growable: false);
                  return ListView.builder(
                    itemCount: edges.length,
                    itemBuilder: (context, index) {
                      final edge = edges[index];
                      return SelectableText(
                        '${edge.name}: ${edge.table}.${edge.properties['column'] ?? ''} → ${edge.properties['referencedSchema'] ?? ''}.${edge.properties['referencedTable'] ?? ''}.${edge.properties['referencedColumn'] ?? ''}',
                      );
                    },
                  );
                },
              ),
            ),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, bounds) {
              resizeViewport(bounds.biggest);
              return Semantics(
                label: strings(context).diagram,
                hint: strings(context).diagramKeys,
                focusable: true,
                focused: canvasFocus.hasFocus,
                onFocus: canvasFocus.requestFocus,
                explicitChildNodes: true,
                child: Focus(
                  focusNode: canvasFocus,
                  onKeyEvent: canvasKey,
                  child: InteractiveViewer(
                    transformationController: transform,
                    constrained: false,
                    minScale: 0.2,
                    maxScale: 3,
                    child: SizedBox(
                      width: graphWidth,
                      height: graphHeight,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(graphWidth, graphHeight),
                            painter: _Edges(
                              widget.edges,
                              widget.tables.map((t) => t.name).toSet(),
                              viewPosition,
                              look.secondaryForeground,
                              nodeSize / 2,
                            ),
                          ),
                          for (final t in widget.tables)
                            Positioned(
                              left: viewPosition(t.name).dx,
                              top: viewPosition(t.name).dy,
                              width: nodeSize.width,
                              height: nodeSize.height,
                              child: Semantics(
                                label: '${strings(context).tables}: ${t.name}',
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: widget.ui.rowRadius,
                                    border: Border.all(
                                      color: look.controlBorder,
                                    ),
                                    color: look.view,
                                  ),
                                  child: WorkbenchRecord(
                                    controls: widget.ui,
                                    label: t.name,
                                    selected: focused == t.name,
                                    child: Row(
                                      children: [
                                        widget.ui.icon(DesktopIcon.table),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: widget.ui.tooltip(
                                            t.name,
                                            Text(
                                              t.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    onPressed: () {
                                      final saved = widget.state;
                                      if (saved?.profileId != null &&
                                          widget.model.commands != null) {
                                        widget.model.commands!.invoke(
                                          'object.structure',
                                          WorkbenchCommandContext(
                                            profileId: saved!.profileId,
                                            object: DatabaseObjectIdentity(
                                              profileId: saved.profileId!,
                                              catalog: t.catalog.isEmpty
                                                  ? saved.catalog
                                                  : t.catalog,
                                              schema: t.schema.isEmpty
                                                  ? saved.schema
                                                  : t.schema,
                                              kind: rpc.ObjectKind.TABLE,
                                              name: t.name,
                                            ),
                                          ),
                                        );
                                      }
                                      setState(() => focused = t.name);
                                    },
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (!compact) widget.ui.field(notes, strings(context).diagramNotes),
        if (!compact)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              widget.ui.button(
                strings(context).openNotes,
                () => widget.model.command(() => notesFile(true)),
              ),
              widget.ui.button(
                strings(context).saveNotes,
                () => widget.model.command(() => notesFile(false)),
              ),
            ],
          ),
      ],
    );
  }
}

class _Edges extends CustomPainter {
  _Edges(
    List<rpc.SchemaObject> edges,
    Set<String> names,
    Offset Function(String) position,
    this.color,
    Size center,
  ) : segments = [
        for (final edge in edges)
          if (names.contains(edge.table) &&
              names.contains(edge.properties['referencedTable']))
            (
              position(edge.table) + Offset(center.width, center.height),
              position(edge.properties['referencedTable']!) +
                  Offset(center.width, center.height),
            ),
      ];
  // Snapshot geometry at construction: the source list and node names can be
  // retained or mutated while appearance/layout changes independently.
  final List<(Offset, Offset)> segments;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (final (start, end) in segments) {
      canvas.drawLine(start, end, pen);
    }
  }

  @override
  bool shouldRepaint(_Edges oldDelegate) =>
      oldDelegate.color != color || !listEquals(oldDelegate.segments, segments);
}
