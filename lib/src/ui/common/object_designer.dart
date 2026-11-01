import 'sql_editor_view.dart';
import '../../features/workspace/editor/sql_editor.dart';
import 'workbench_editor_menu.dart';
import '../../l10n/workbench_strings.dart';

import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../backend/generated/busydata.pb.dart' as rpc;
import 'desktop_controls.dart';
import 'sql_presentation.dart';
import 'workbench_editor_scroll.dart';
import 'workbench_presentation.dart';

import '../../features/workspace/workbench_documents.dart'
    show ObjectDesignerDraft;
export '../../features/workspace/workbench_documents.dart'
    show ObjectDesignerDraft;

class ObjectDesignerReferenceState {
  String? schema;
  Map<String, List<String>> columns = {};
}

class ObjectDesignerForm extends StatefulWidget {
  const ObjectDesignerForm({
    super.key,
    required this.controls,
    required this.inspected,
    required this.target,
    required this.generate,
    required this.openSql,
    this.draft,
    this.onChanged,
    this.admitDraft,
    this.referenceState,
    this.inspectReferenceSchema,
  });
  final ObjectDesignerDraft? draft;
  final VoidCallback? onChanged;
  final bool Function(ObjectDesignerDraft)? admitDraft;
  final ObjectDesignerReferenceState? referenceState;
  final Future<Map<String, List<String>>> Function(String schema)?
  inspectReferenceSchema;
  final DesktopControls controls;
  final rpc.SchemaToolResult inspected;
  final rpc.SchemaToolRequest target;
  final Future<rpc.SchemaToolResult> Function(rpc.SchemaToolRequest) generate;
  final ValueChanged<rpc.SchemaToolResult> openSql;
  @override
  State<ObjectDesignerForm> createState() => _ObjectDesignerFormState();
}

class _ObjectDesignerFormState extends State<ObjectDesignerForm> {
  final newTableName = TextEditingController(),
      columnComment = TextEditingController(),
      columnCollation = TextEditingController();
  final newColumns = <rpc.DesignedColumn>[];
  final name = TextEditingController(),
      type = TextEditingController(text: 'text'),
      value = TextEditingController(),
      columns = TextEditingController(),
      referenceSchema = TextEditingController(),
      referenceTable = TextEditingController(),
      referenceColumns = TextEditingController();
  final definition = SqlEditorController();
  late final Map<String, dynamic> snapshot =
      jsonDecode(widget.inspected.snapshot) as Map<String, dynamic>;
  late final Map<String, dynamic> table =
      (snapshot['tables'] as Map<String, dynamic>)[widget.target.table]
          as Map<String, dynamic>? ??
      {};
  String onDelete = 'NO ACTION', onUpdate = 'NO ACTION';
  bool deferrable = false, initiallyDeferred = false;
  String operation = 'alter', property = 'type', kind = 'unique', picked = '';
  bool nullable = true, unique = false, busy = false;
  bool inspectingReference = false;
  int designRevision = 0;
  late final referenceState =
      widget.referenceState ?? ObjectDesignerReferenceState();
  String get requestedReferenceSchema => referenceSchema.text.isEmpty
      ? widget.target.schema
      : referenceSchema.text;
  bool get referenceReady => referenceState.schema == requestedReferenceSchema;
  String error = '';
  Map<String, TextEditingController> get fields => {
    'newTable': newTableName,
    'comment': columnComment,
    'collation': columnCollation,
    'name': name,
    'type': type,
    'value': value,
    'columns': columns,
    'referenceSchema': referenceSchema,
    'referenceTable': referenceTable,
    'referenceColumns': referenceColumns,
  };
  bool restoringDraft = false;
  void saveDraft() {
    final original = widget.draft;
    if (original == null || restoringDraft) return;
    final draft = ObjectDesignerDraft()..dirty = original.dirty;
    draft.fields
      ..clear()
      ..addAll({
        for (final entry in fields.entries) entry.key: entry.value.text,
        'definition': definition.text,
        'operation': operation,
        'property': property,
        'kind': kind,
        'picked': picked,
        'onDelete': onDelete,
        'onUpdate': onUpdate,
      });
    draft.flags
      ..clear()
      ..addAll({
        'nullable': nullable,
        'unique': unique,
        'deferrable': deferrable,
        'initiallyDeferred': initiallyDeferred,
      });
    draft.columns
      ..clear()
      ..addAll(newColumns.map((c) => c.deepCopy()));
    try {
      draft.validate();
      if (widget.admitDraft?.call(draft) == false) {
        throw StateError('The shared object-design recovery budget is full');
      }
      original.replace(draft);
    } catch (failure) {
      restoringDraft = true;
      for (final entry in fields.entries) {
        entry.value.text = original.fields[entry.key] ?? '';
      }
      definition.text = original.fields['definition'] ?? '';
      newColumns
        ..clear()
        ..addAll(original.columns.map((c) => c.deepCopy()));
      operation = original.fields['operation'] ?? operation;
      property = original.fields['property'] ?? property;
      kind = original.fields['kind'] ?? kind;
      picked = original.fields['picked'] ?? picked;
      onDelete = original.fields['onDelete'] ?? onDelete;
      onUpdate = original.fields['onUpdate'] ?? onUpdate;
      nullable = original.flags['nullable'] ?? nullable;
      unique = original.flags['unique'] ?? unique;
      deferrable = original.flags['deferrable'] ?? deferrable;
      initiallyDeferred =
          original.flags['initiallyDeferred'] ?? initiallyDeferred;
      restoringDraft = false;
      if (mounted) super.setState(() {});
      error = '$failure';
    }
  }

  void changedDraft() {
    if (widget.draft == null || restoringDraft) return;
    final before = jsonEncode(widget.draft!.toJson());
    saveDraft();
    if (before == jsonEncode(widget.draft!.toJson())) return;
    widget.draft!.dirty = true;
    widget.onChanged?.call();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    designRevision++;
    changedDraft();
  }

  @override
  void initState() {
    super.initState();
    if (table.isEmpty) {
      operation = 'table';
      property = 'plain';
    }
    if (widget.draft case final draft?) {
      for (final entry in fields.entries) {
        if (draft.fields.containsKey(entry.key)) {
          entry.value.text = draft.fields[entry.key]!;
        }
      }
      definition.text = draft.fields['definition'] ?? '';
      operation = draft.fields['operation'] ?? operation;
      property = draft.fields['property'] ?? property;
      kind = draft.fields['kind'] ?? kind;
      picked = draft.fields['picked'] ?? picked;
      onDelete = draft.fields['onDelete'] ?? onDelete;
      onUpdate = draft.fields['onUpdate'] ?? onUpdate;
      nullable = draft.flags['nullable'] ?? nullable;
      unique = draft.flags['unique'] ?? unique;
      deferrable = draft.flags['deferrable'] ?? deferrable;
      initiallyDeferred = draft.flags['initiallyDeferred'] ?? initiallyDeferred;
      newColumns.addAll(draft.columns.map((c) => c.deepCopy()));
      saveDraft();
    }
    referenceState.schema ??= widget.target.schema;
    if (referenceState.columns.isEmpty &&
        referenceState.schema == widget.target.schema) {
      referenceState.columns = {
        for (final entry
            in (snapshot['tables'] as Map<String, dynamic>).entries)
          entry.key:
              ((entry.value as Map<String, dynamic>)['columns']
                          as Map<String, dynamic>? ??
                      {})
                  .keys
                  .toList(),
      };
    }
    void edited() {
      designRevision++;
      changedDraft();
    }

    for (final controller in fields.values) {
      controller.addListener(edited);
    }
    definition.addListener(edited);
    referenceSchema.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> inspectReference() async {
    final inspect = widget.inspectReferenceSchema;
    if (inspect == null || inspectingReference) return;
    setState(() {
      inspectingReference = true;
      error = '';
      if (!referenceReady) {
        referenceTable.clear();
        referenceColumns.clear();
      }
    });
    final schema = requestedReferenceSchema, revision = designRevision;
    try {
      final columns = await inspect(schema);
      if (!mounted) return;
      if (schema != requestedReferenceSchema || revision != designRevision) {
        throw StateError(strings(context).metadataContextChanged);
      }
      setState(() {
        referenceState.schema = schema;
        referenceState.columns = columns;
        referenceTable.clear();
        referenceColumns.clear();
      });
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => inspectingReference = false);
    }
  }

  Map<String, dynamic> get columnMap =>
      table['columns'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get objects => switch (operation) {
    'index' => table['indexes'] as Map<String, dynamic>? ?? {},
    'constraint' => table['constraints'] as Map<String, dynamic>? ?? {},
    'view' => snapshot['views'] as Map<String, dynamic>? ?? {},
    'routine' => snapshot['routines'] as Map<String, dynamic>? ?? {},
    'trigger' => table['triggers'] as Map<String, dynamic>? ?? {},
    _ => columnMap,
  };
  void pick(String selected) {
    picked = selected;
    name.text = selected;
    final object = objects[selected];
    if (object is Map) {
      type.text = '${object['type'] ?? 'text'}';
      nullable = object['nullable'] == true;
      value.text =
          '${object[switch (property) {
                'identity' => 'special',
                _ => property,
              }] ?? ''}';
      if (property == 'identity') {
        value.text = switch (value.text) {
          'a' => 'always',
          'd' || 'auto_increment' => 'byDefault',
          _ => 'none',
        };
      }
      if (property == 'generated' && snapshot['engine'] == 'POSTGRESQL') {
        value.text =
            '${object['generated'] == 's' ? object['default'] ?? '' : ''}';
      }
      definition.text = '${object['definition'] ?? ''}';
    } else if (object != null) {
      definition.text = '$object';
    }
  }

  Map<String, String> get properties => switch (operation) {
    'add' || 'table' => {
      'plain': strings(context).ordinaryColumn,
      'default': strings(context).columnWithDefault,
      'identity': strings(context).identityColumn,
      'generated': strings(context).generatedColumn,
    },
    'alter' => {
      'type': strings(context).columnType,
      'nullable': strings(context).nullableNotNull,
      'default': strings(context).defaultExpression,
      'identity': strings(context).identityColumn,
      'generated': strings(context).generatedExpression,
      'comment': strings(context).columnComment,
      'collation': strings(context).columnCollationProperty,
    },
    'property' =>
      widget.target.hasSessionId() && snapshot['engine'] == 'POSTGRESQL'
          ? {
              'persistence': strings(context).loggedUnlogged,
              'comment': strings(context).tableComment,
            }
          : {
              'engine': strings(context).storageEngine,
              'collation': strings(context).tableCollation,
              'rowFormat': strings(context).rowFormat,
              'comment': strings(context).tableComment,
            },
    _ => {
      'add': strings(context).createOrReplace,
      'drop': strings(context).dropSelectedObject,
    },
  };

  Widget orderedColumns(
    TextEditingController controller,
    Iterable<String> available,
    String label,
  ) {
    final ui = widget.controls;
    final selected = controller.text.isEmpty ? <String>[] : names(controller);
    final candidates = available
        .where((name) => !selected.contains(name))
        .toList();
    void write(List<String> updated) =>
        setState(() => controller.text = jsonEncode(updated));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        for (var i = 0; i < selected.length; i++)
          Row(
            children: [
              Expanded(child: Text('${i + 1} · ${selected[i]}')),
              ui.button(
                strings(context).up,
                i == 0
                    ? null
                    : () {
                        final updated = List<String>.of(selected);
                        final previous = updated[i - 1];
                        updated[i - 1] = updated[i];
                        updated[i] = previous;
                        write(updated);
                      },
              ),
              ui.button(
                strings(context).remove,
                () => write(List<String>.of(selected)..removeAt(i)),
              ),
            ],
          ),
        if (candidates.isNotEmpty)
          ui.choice(
            '',
            {
              '': strings(context).addColumn,
              for (final name in candidates) name: name,
            },
            (name) {
              if (name.isNotEmpty) write([...selected, name]);
            },
          ),
        if (available.isEmpty) Text(strings(context).columnMetadataUnavailable),
      ],
    );
  }

  /// JSON arrays preserve exact identifiers containing commas, spaces or quotes.
  List<String> names(TextEditingController controller) {
    final source = controller.text.trim();
    if (source.isEmpty) return [];
    if (source.startsWith('[')) {
      if (source.length > 8192) {
        throw StateError('Column list exceeds 8Ki UTF-16 units');
      }
      final value = jsonDecode(source);
      if (value is! List ||
          value.length > 32 ||
          value.any(
            (name) => name is! String || name.isEmpty || name.length > 128,
          )) {
        throw StateError('Use a JSON array of 1–32 exact column names');
      }
      return value.cast<String>();
    }
    return source
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> generate() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    final revision = designRevision;
    try {
      if (operation == 'constraint' &&
          kind == 'foreign' &&
          property != 'drop' &&
          !referenceReady) {
        throw StateError(strings(context).columnMetadataUnavailable);
      }
      final request = widget.target.deepCopy()
        ..action = rpc.SchemaToolAction.DESIGN_COLUMN
        ..sourceSnapshot = widget.inspected.snapshot
        ..operation = operation
        ..property = property
        ..column = name.text
        ..objectName = operation == 'table' ? newTableName.text : name.text
        ..type = type.text
        ..nullable = nullable
        ..unique = unique
        ..value = operation == 'alter' && property == 'nullable'
            ? '$nullable'
            : value.text
        ..objectKind = kind
        ..expression = value.text
        ..referenceSchema = referenceSchema.text
        ..referenceTable = referenceTable.text
        ..definition = definition.text
        ..onDelete = onDelete
        ..onUpdate = onUpdate
        ..deferrable = deferrable
        ..initiallyDeferred = initiallyDeferred;
      request.objectColumns.addAll(names(columns));
      request.designedColumns.addAll(
        newColumns.map((column) => column.deepCopy()),
      );
      request.referenceColumns.addAll(names(referenceColumns));
      final plan = await widget.generate(request);
      if (!mounted) return;
      if (revision != designRevision) {
        throw StateError(strings(context).expiredChangeReview);
      }
      if (!plan.complete) {
        setState(
          () => error = 'Incomplete plan: ${plan.unsupported.join('\n')}',
        );
        return;
      }
      widget.openSql(plan);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.controls;
    Widget formAction(
      String label,
      VoidCallback? callback, {
      bool primary = false,
    }) => Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: ui.button(label, callback, primary: primary),
    );
    return WorkbenchForm(
      maxWidth: ui.formContentWidth,
      footer: WorkbenchStrip(
        controls: ui,
        topBorder: true,
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            formAction(
              busy
                  ? strings(context).generating
                  : strings(context).generateReviewedDdl,
              busy ? null : generate,
              primary: true,
            ),
            formAction(strings(context).inspectCapturedDefinition, () {
              final capturedDefinition = widget.inspected.definition;
              ui.dialog<void>(
                context,
                strings(context).capturedObject,
                SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    child: WorkbenchCodeEvidence(
                      controls: ui,
                      text: capturedDefinition,
                    ),
                  ),
                ),
                [
                  ui.button(
                    strings(context).close,
                    () => Navigator.of(context).pop(),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
      child: WorkbenchFormList(
        controls: ui,
        padding: const EdgeInsets.all(12),
        children: [
          Text(strings(context).designReviewNote),
          ui.comboRow(
            strings(context).objectDesigner,
            operation,
            {
              if (table.isNotEmpty) ...{
                'add': strings(context).addColumn,
                'drop': strings(context).dropDesignedColumn,
                'alter': strings(context).editColumnProperties,
                'index': strings(context).indexes,
                'constraint': strings(context).constraints,
                'property': strings(context).tableProperties,
                'trigger': strings(context).triggerDefinition,
              },
              'table': strings(context).createTable,
              'view': strings(context).viewDefinition,
              'routine': strings(context).routineDefinition,
            },
            (selected) => setState(() {
              operation = selected;
              property = properties.keys.first;
              picked = '';
              name.clear();
              definition.text = '';
              error = '';
            }),
          ),
          if (operation != 'add' &&
              operation != 'table' &&
              operation != 'property')
            ui.comboRow(strings(context).chooseExistingObject, picked, {
              '': strings(context).chooseExistingObject,
              for (final key in objects.keys) key: key,
            }, (selected) => setState(() => pick(selected))),
          if (operation == 'table')
            ui.field(newTableName, strings(context).newTableName),
          if (operation != 'property')
            ui.field(
              name,
              operation == 'routine'
                  ? strings(context).routineIdentity
                  : strings(context).objectColumnName,
            ),
          if (operation == 'add' ||
              operation == 'table' ||
              operation == 'alter' ||
              operation == 'property' ||
              !['add', 'drop'].contains(operation))
            ui.comboRow(
              strings(context).details,
              property,
              properties,
              (selected) => setState(() {
                property = selected;
                if (picked.isNotEmpty) pick(picked);
              }),
            ),
          if (operation == 'add' || operation == 'table')
            ui.field(type, strings(context).builtInType),
          if (operation == 'add' ||
              operation == 'table' ||
              operation == 'alter' && property == 'nullable')
            ui.switchRow(
              strings(context).nullable,
              nullable,
              (selected) => setState(() => nullable = selected),
            ),
          if ((operation == 'add' || operation == 'table') &&
                  property != 'plain' ||
              operation == 'alter' && property != 'nullable' ||
              operation == 'property') ...[
            if (property == 'identity')
              ui.choice(
                value.text == 'always'
                    ? 'always'
                    : value.text == 'byDefault'
                    ? 'byDefault'
                    : 'none',
                {
                  'none': strings(context).removeIdentity,
                  'always': strings(context).generatedAlways,
                  'byDefault': strings(context).generatedByDefault,
                },
                (selected) => setState(() => value.text = selected),
              )
            else if (property == 'persistence')
              ui.choice(value.text == 'u' ? 'u' : 'p', {
                'p': strings(context).loggedTable,
                'u': strings(context).unloggedTable,
              }, (selected) => setState(() => value.text = selected))
            else
              ui.field(
                value,
                property == 'default' || property == 'generated'
                    ? strings(context).sqlExpression
                    : strings(context).newPropertyValue,
              ),
          ],
          if (operation == 'table') ...[
            ui.field(columnComment, strings(context).columnComment),
            ui.field(columnCollation, strings(context).columnCollation),
            ui.button(strings(context).addDesignedColumn, () {
              if (name.text.isEmpty ||
                  newColumns.any((c) => c.name == name.text) ||
                  newColumns.length >= 128) {
                setState(
                  () => error = strings(context).uniqueDesignedColumnName,
                );
                return;
              }
              setState(() {
                newColumns.add(
                  rpc.DesignedColumn(
                    name: name.text,
                    type: type.text,
                    nullable: nullable,
                    defaultExpression: property == 'default' ? value.text : '',
                    identity: property == 'identity' ? value.text : '',
                    generatedExpression: property == 'generated'
                        ? value.text
                        : '',
                    comment: columnComment.text,
                    collation: columnCollation.text,
                  ),
                );
                name.clear();
                value.clear();
                columnComment.clear();
                columnCollation.clear();
              });
            }),
            for (final column in newColumns)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${column.name} · ${column.type} · ${column.nullable ? "NULL" : "NOT NULL"}',
                    ),
                  ),
                  ui.button(
                    '${strings(context).remove} ${column.name}',
                    () => setState(() => newColumns.remove(column)),
                  ),
                ],
              ),
            orderedColumns(
              columns,
              newColumns.map((c) => c.name),
              strings(context).orderedPrimaryKeyColumns,
            ),
          ],
          if (['index', 'constraint'].contains(operation) &&
              property != 'drop') ...[
            orderedColumns(
              columns,
              columnMap.keys,
              strings(context).orderedColumns,
            ),
            if (operation == 'index')
              ui.choice(unique, {
                false: strings(context).ordinaryIndex,
                true: strings(context).uniqueIndex,
              }, (selected) => setState(() => unique = selected)),
            if (operation == 'constraint') ...[
              ui.choice(kind, {
                'primary': strings(context).primaryKey,
                'unique': strings(context).uniqueConstraint,
                'foreign': strings(context).foreignKey,
                'check': strings(context).checkConstraint,
              }, (selected) => setState(() => kind = selected)),
              if (kind == 'check')
                ui.field(value, strings(context).checkExpression),
              if (kind == 'foreign') ...[
                ui.choice(onDelete, {
                  for (final action in [
                    'NO ACTION',
                    'RESTRICT',
                    'CASCADE',
                    'SET NULL',
                    if (snapshot['engine'] == 'POSTGRESQL') 'SET DEFAULT',
                  ])
                    action: '${strings(context).onDelete}: $action',
                }, (selected) => setState(() => onDelete = selected)),
                ui.choice(onUpdate, {
                  for (final action in [
                    'NO ACTION',
                    'RESTRICT',
                    'CASCADE',
                    'SET NULL',
                    if (snapshot['engine'] == 'POSTGRESQL') 'SET DEFAULT',
                  ])
                    action: '${strings(context).onUpdate}: $action',
                }, (selected) => setState(() => onUpdate = selected)),
                if (snapshot['engine'] == 'POSTGRESQL') ...[
                  ui.choice(
                    deferrable,
                    {
                      false: strings(context).immediateChecking,
                      true: strings(context).deferrableChecking,
                    },
                    (selected) => setState(() {
                      deferrable = selected;
                      if (!selected) initiallyDeferred = false;
                    }),
                  ),
                  if (deferrable)
                    ui.choice(
                      initiallyDeferred,
                      {
                        false: strings(context).initiallyImmediate,
                        true: strings(context).initiallyDeferred,
                      },
                      (selected) =>
                          setState(() => initiallyDeferred = selected),
                    ),
                ],

                ui.field(referenceSchema, strings(context).referencedSchema),
                if (widget.inspectReferenceSchema != null)
                  ui.button(
                    inspectingReference
                        ? strings(context).loading
                        : '${strings(context).inspectStructure} · ${strings(context).referencedSchema}',
                    inspectingReference ? null : inspectReference,
                  ),
                if (!referenceReady)
                  Text(strings(context).columnMetadataUnavailable),
                ui.choice(
                  referenceTable.text,
                  {
                    referenceTable.text: referenceTable.text.isEmpty
                        ? strings(context).referencedTable
                        : referenceTable.text,
                    for (final name
                        in referenceReady
                            ? referenceState.columns.keys
                            : <String>[])
                      name: name,
                  },
                  (name) => setState(() {
                    referenceTable.text = name;
                    referenceColumns.clear();
                  }),
                ),
                orderedColumns(
                  referenceColumns,
                  referenceReady
                      ? referenceState.columns[referenceTable.text] ??
                            <String>[]
                      : <String>[],
                  strings(context).orderedReferencedColumns,
                ),
              ],
            ],
          ],
          if (['view', 'routine', 'trigger'].contains(operation) &&
              property != 'drop')
            SizedBox(
              height: 220,
              child: WorkbenchEditorScroll(
                presentation: (
                  sqlPresentationSignature(context, ui),
                  MediaQuery.textScalerOf(context),
                ),
                builder: (scroll) => WorkbenchEditorMenu(
                  scrollController: scroll,
                  controls: ui,
                  controller: definition,
                  readOnly: busy,
                  builder: (toolbar, menuFocus, shortcuts) =>
                      WorkbenchSqlEditor(
                        semanticLabel: strings(context).objectDefinitionEditor,
                        controls: ui,
                        shortcutsActivatorsBuilder: shortcuts,
                        toolbarController: toolbar,
                        focusNode: menuFocus,
                        controller: definition,
                        readOnly: busy,
                        scrollController: scroll,
                        style: sqlEditorStyle(context, ui),
                        indicatorBuilder:
                            (context, editing, chunks, notifier) =>
                                sqlEditorIndicators(
                                  context,
                                  ui,
                                  editing,
                                  chunks,
                                  notifier,
                                ),
                      ),
                ),
              ),
            ),
          if (error.isNotEmpty)
            Semantics(liveRegion: true, child: ui.status(error, error: true)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    saveDraft();
    for (final controller in [
      newTableName,
      columnComment,
      columnCollation,
      name,
      type,
      value,
      columns,
      referenceSchema,
      referenceTable,
      referenceColumns,
    ]) {
      controller.dispose();
    }
    definition.dispose();
    super.dispose();
  }
}
