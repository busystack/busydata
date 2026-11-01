import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';

Map<int, String> structureSections(
  BuildContext context,
  WorkbenchDocument owner,
) {
  final object = owner.object!, l = strings(context);
  final relation = ![
    rpc.ObjectKind.ROUTINE,
    rpc.ObjectKind.SEQUENCE,
  ].contains(object.kind);
  return {
    if (object.parent.isNotEmpty)
      object.kind.value: workbenchObjectType(context, object.kind),
    if (object.parent.isEmpty && relation)
      rpc.ObjectKind.COLUMN.value: l.columns,
    if (object.parent.isEmpty &&
        relation &&
        object.kind != rpc.ObjectKind.VIEW) ...{
      rpc.ObjectKind.INDEX.value: l.indexes,
      rpc.ObjectKind.CONSTRAINT.value: l.constraints,
      rpc.ObjectKind.FOREIGN_KEY.value: l.foreignKeys,
      rpc.ObjectKind.TRIGGER.value: l.triggers,
    },
    rpc.ObjectKind.TABLE.value: l.openDefinition,
    if (object.parent.isEmpty && object.kind != rpc.ObjectKind.SEQUENCE)
      10: l.dependencies,
  };
}

int structureSection(BuildContext context, WorkbenchDocument owner) {
  final sections = structureSections(context, owner);
  return sections.containsKey(owner.view.structureSection)
      ? owner.view.structureSection
      : sections.keys.first;
}

String? structureInspectionSessionId(
  WorkbenchModel model,
  WorkbenchDocument owner,
) {
  for (final id in [
    owner.sessionId,
    owner.view.metadataSessionId,
    model.explorerSessions[owner.object!.profileId],
  ]) {
    final session = model.sessions[id];
    if (session != null &&
        session.profile.id == owner.object!.profileId &&
        session.transaction != rpc.TransactionState.DISCONNECTED &&
        session.transaction != rpc.TransactionState.UNKNOWN_TRANSACTION) {
      return id;
    }
  }
  return null;
}

class StructureControls extends StatelessWidget {
  const StructureControls({
    super.key,
    required this.model,
    required this.owner,
    required this.controls,
  });
  final WorkbenchModel model;
  final WorkbenchDocument owner;
  final DesktopControls controls;
  @override
  Widget build(BuildContext context) {
    final backend = model.backend,
        revision = owner.version,
        ownerSession = owner.sessionId;
    final sessionId = structureInspectionSessionId(model, owner);
    final inspection = model.sessions[sessionId]?.deepCopy();
    final changedContext = strings(context).metadataContextChanged;
    final selectedSection = structureSection(context, owner);
    void select(int value) {
      if (model.isDisposed) return;
      final current = model.sessions[sessionId];
      if (!identical(model.backend, backend) ||
          !model.taskDocuments.contains(owner) ||
          owner.version != revision ||
          owner.sessionId != ownerSession ||
          structureInspectionSessionId(model, owner) != sessionId ||
          inspection != null &&
              (current == null ||
                  current.contextRevision != inspection.contextRevision ||
                  !WorkbenchModel.sameConnectionTarget(
                    current.profile,
                    inspection.profile,
                  ))) {
        model.updateStatus(changedContext);
        return;
      }
      // Navigation captures the physical inspection context. The inspector's
      // request still captures/adopts its current metadata revision separately.
      model.inspectStructureSection(owner, value);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: controls.modeSwitcher<int>(
            structureSection(context, owner),
            structureSections(context, owner),
            select,
            label: strings(context).structure,
          ),
        ),
        controls.iconButton(
          DesktopIcon.refresh,
          strings(context).refresh,
          () => select(selectedSection),
        ),
      ],
    );
  }
}

/// Identity is independent of order, position and mutable properties. A captured
/// dependency's direction identifies its edge when the same object points back.
/// The enclosing DocumentViewState supplies the document/section scope.
String schemaObjectSelection(rpc.SchemaObject object) => [
  object.kind.value,
  object.subtype.value,
  object.catalog,
  object.schema,
  object.table,
  object.name,
  object.identifier,
  if (object.properties.containsKey('Relationship'))
    object.properties['Relationship']!,
].map((v) => '${v.toString().length}:$v').join();

class SchemaObjectDetails extends StatelessWidget {
  const SchemaObjectDetails({
    super.key,
    required this.controls,
    required this.object,
    this.nativeDefinition = false,
    this.showName = true,
  });
  final DesktopControls controls;
  final rpc.SchemaObject object;
  final bool nativeDefinition, showName;
  // Publication/provenance evidence belongs to the Java metadata model. These
  // implementation markers are not database properties or translated labels.
  static const _implementationProperties = {
    'catalogFingerprint',
    'nativeId',
    'parentNativeId',
    'nativeGeneration',
    'nativeGenerationAvailability',
    'nativeTableId',
    'nativeColumnEpoch',
    'nativeTypeId',
    'editabilitySignature',
    'baseTableVerified',
  };
  @override
  Widget build(BuildContext context) {
    final entries = object.properties.entries
        .where((entry) => !_implementationProperties.contains(entry.key))
        .toList(growable: false);
    final properties = [
      for (final property in entries)
        workbenchMetadataProperty(
          context,
          object.kind,
          property.key,
          property.value,
          nativeDefinition: nativeDefinition,
        ),
    ];
    final width = WorkbenchMetrics.labelWidth(
      context,
      controls,
      properties.map((p) => p.label),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showName)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                object.name,
                style: controls.appearance(context).heading,
              ),
            ),
          ),
        if (nativeDefinition && object.definition.isNotEmpty)
          WorkbenchCodeEvidence(controls: controls, text: object.definition),
        if (properties.isNotEmpty)
          controls.groupedList(
            children: [
              for (final (index, property) in properties.indexed)
                WorkbenchReadOnlyProperty(
                  key: ValueKey(
                    '${schemaObjectSelection(object)}:${entries[index].key}',
                  ),
                  controls: controls,
                  label: property.label,
                  labelWidth: width,
                  value: property.value,
                  keyboardTraversal: true,
                ),
            ],
          ),
        if (!nativeDefinition && object.definition.isNotEmpty)
          WorkbenchCodeEvidence(controls: controls, text: object.definition),
      ],
    );
  }
}

/// Metadata-only, virtualized rows. No execution/result/editing ownership enters
/// this viewport. Full captured values are selectable in SchemaObjectDetails.
class SchemaOverview extends StatefulWidget {
  const SchemaOverview({
    super.key,
    required this.controls,
    required this.objects,
    required this.kind,
    required this.selected,
    required this.select,
  });
  final DesktopControls controls;
  final List<rpc.SchemaObject> objects;
  final rpc.ObjectKind kind;
  final String? selected;
  final ValueChanged<rpc.SchemaObject> select;
  @override
  State<SchemaOverview> createState() => _SchemaOverviewState();
}

class _SchemaOverviewState extends State<SchemaOverview> {
  final horizontal = ScrollController(), vertical = ScrollController();
  @override
  void dispose() {
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = strings(context),
        controls = widget.controls,
        look = controls.appearance(context);
    final fields = switch (widget.kind) {
      rpc.ObjectKind.COLUMN => [
        ('name', l.connectionName, 145.0),
        ('type', l.columnType, 155.0),
        ('nullable', l.nullable, 90.0),
        ('default', l.defaultExpression, 180.0),
        ('attributes', l.metadataAttributes, 250.0),
      ],
      rpc.ObjectKind.INDEX => [
        ('name', l.connectionName, 200.0),
        ('nonUnique', l.metadataUnique, 100.0),
        ('column', l.columns, 360.0),
      ],
      rpc.ObjectKind.CONSTRAINT => [
        ('name', l.connectionName, 240.0),
        ('type', l.metadataType, 180.0),
        ('column', l.columns, 300.0),
      ],
      rpc.ObjectKind.FOREIGN_KEY => [
        ('name', l.connectionName, 230.0),
        ('column', l.columns, 160.0),
        ('referencedTable', l.referencedTable, 190.0),
        ('referencedColumn', l.metadataReferencedColumn, 220.0),
      ],
      rpc.ObjectKind.TRIGGER => [
        ('name', l.connectionName, 240.0),
        ('event', l.metadataEvent, 240.0),
      ],
      _ => [
        ('name', l.connectionName, 300.0),
        ('Relationship', l.details, 440.0),
      ],
    };
    final scale = math.max(1.0, look.lineHeight(context) / 20);
    final widths = [
      for (final (_, label, width) in fields)
        math.max(
          width * scale,
          WorkbenchMetrics.labelWidth(context, controls, [label]),
        ),
    ];
    final rowHeight = math.max(36.0, look.rowHeight(context) + 4);
    String value(rpc.SchemaObject object, String key) {
      if (key == 'name') return object.name;
      if (key == 'attributes') {
        return [
          for (final attribute in [
            'autoIncrement',
            'generated',
            'special',
            'generation_kind',
          ])
            if (object.properties.containsKey(attribute))
              '${workbenchMetadataProperty(context, object.kind, attribute, object.properties[attribute]!).label}: ${workbenchMetadataProperty(context, object.kind, attribute, object.properties[attribute]!).value}',
        ].join(' · ');
      }
      if (!object.properties.containsKey(key)) return '—';
      return workbenchMetadataProperty(
        context,
        object.kind,
        key,
        object.properties[key]!,
      ).value;
    }

    Widget cells(List<String> values, {bool header = false}) => Row(
      children: [
        for (var i = 0; i < values.length; i++)
          SizedBox(
            width: widths[i],
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Text(
                values[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: header
                    ? look.body.copyWith(fontWeight: FontWeight.w600)
                    : null,
              ),
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, bounds) => controls.scrollbar(
        controller: horizontal,
        alwaysVisible: true,
        child: SingleChildScrollView(
          controller: horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(
              bounds.maxWidth,
              widths.fold(16.0, (a, b) => a + b),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: rowHeight,
                  color: look.header,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: cells(
                      fields.map((f) => f.$2).toList(),
                      header: true,
                    ),
                  ),
                ),
                Expanded(
                  child: controls.scrollbar(
                    controller: vertical,
                    child: ListView.builder(
                      key: const ValueKey('schema-overview-rows'),
                      controller: vertical,
                      itemExtent: rowHeight,
                      itemCount: widget.objects.length,
                      itemBuilder: (context, index) {
                        final object = widget.objects[index],
                            values = [
                              for (final field in fields)
                                value(widget.objects[index], field.$1),
                            ];
                        return WorkbenchRecord(
                          key: ValueKey(schemaObjectSelection(object)),
                          controls: controls,
                          label: [
                            for (var i = 0; i < fields.length; i++)
                              '${fields[i].$2}: ${values[i]}',
                          ].join(' · '),
                          selected:
                              schemaObjectSelection(object) == widget.selected,
                          onPressed: () => widget.select(object),
                          child: cells(values),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
