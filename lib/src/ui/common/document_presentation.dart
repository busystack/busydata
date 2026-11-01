import 'package:flutter/widgets.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import '../../features/workspace/documents.dart';
import '../../l10n/workbench_strings.dart';

/// Current/prospective execution target, independent of selected output history.
rpc.Profile? documentTargetProfile(
  WorkbenchModel model,
  WorkbenchDocument owner,
) =>
    model.sessions[owner.sessionId]?.profile ??
    model.profiles.where((p) => p.id == owner.profileId).firstOrNull;

rpc.Profile? documentProfile(WorkbenchModel model, WorkbenchDocument owner) =>
    owner.sql != null
    ? documentTargetProfile(model, owner)
    : owner.retained?.target ??
          model
              .retainedResults[model.resultForOwner(owner)?.resultId]
              ?.target ??
          model.sessions[owner.sessionId]?.profile ??
          owner.evidenceProfile ??
          documentTargetProfile(model, owner);

/// The same name is used by headers, tabs, editor names and accessibility.
String sqlDocumentName(BuildContext context, SqlDocument sql) =>
    sql.path == null && sql.untitledNumber != null
    ? strings(context).queryTitle(sql.untitledNumber!)
    : sql.title;

String documentName(
  BuildContext context,
  WorkbenchModel model,
  WorkbenchDocument owner,
) {
  final sql = owner.sql;
  if (sql != null) {
    return sqlDocumentName(context, sql);
  }
  final object = owner.object;
  if (object == null) return owner.displayTitle;
  final name = object.displayNameFor(documentProfile(model, owner)?.engine);
  return owner.purpose == 'design'
      ? '$name — ${strings(context).objectDesigner}'
      : name;
}

/// Short qualifiers are painted separately from the ellipsized name. All full
/// context stays available in the accessible label/tooltip. Labels never own
/// or select a session, and retained results always use their captured target.
({String name, String qualifier, String instance, String context})
documentTabLabel(
  BuildContext context,
  WorkbenchModel model,
  WorkbenchDocument owner,
) {
  final name = documentName(context, model, owner);
  final peers = model.workbenchDocuments
      .where((d) => documentName(context, model, d) == name)
      .toList();
  final profile = documentProfile(model, owner);
  String scope(WorkbenchDocument d) {
    final object = d.object;
    return object == null
        ? ''
        : [
            object.catalog,
            object.schema,
            object.parent,
          ].where((s) => s.isNotEmpty).toSet().join('.');
  }

  String connection(WorkbenchDocument d) {
    final p = documentProfile(model, d);
    final sameName = peers
        .map((peer) => documentProfile(model, peer))
        .where((profile) => profile?.name == p?.name);
    if (p != null &&
        sameName.map((profile) => profile?.host).toSet().length > 1) {
      return p.host;
    }
    if (p != null &&
        sameName.map((profile) => profile?.port).toSet().length > 1) {
      return '${p.host}:${p.port}';
    }
    return p?.name.isNotEmpty == true ? p!.name : p?.host ?? '';
  }

  String qualifier = '';
  String instance = '';
  if (peers.length > 1) {
    // Prefer the nearest differing namespace, then connection; only identical
    // scopes need both. The instance number is independent of tab ordering.
    final schemas = peers.map((d) => d.object?.schema ?? '').toSet();
    if (schemas.length > 1) qualifier = owner.object?.schema ?? '';
    if (peers.any(
      (d) =>
          d != owner &&
          (qualifier.isEmpty || d.object?.schema == owner.object?.schema),
    )) {
      if (peers.map(connection).toSet().length > 1) {
        qualifier = [
          qualifier,
          connection(owner),
        ].where((s) => s.isNotEmpty).join(' · ');
      } else if (peers.map(scope).toSet().length > 1) {
        qualifier = scope(owner);
      }
    }
    final same =
        peers
            .where(
              (d) =>
                  scope(d) == scope(owner) &&
                  connection(d) == connection(owner),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (same.length > 1) {
      instance = '${same.indexOf(owner) + 1}';
    }
    if (qualifier.isNotEmpty) {
      // Every qualifier can elide as text scale or allocation changes. Reserve
      // an independently painted, untruncated differentiator for the peer set.
      final instances = List<WorkbenchDocument>.of(peers)
        ..sort((a, b) => a.id.compareTo(b.id));
      instance = '${instances.indexOf(owner) + 1}';
    }
  }
  return (
    name: name,
    qualifier: qualifier,
    instance: instance,
    context: [
      if (profile != null) ...[
        profile.name,
        '${profile.host}:${profile.port}/${profile.database}',
      ],
      if (owner.object != null) owner.object!.displayPath(profile?.engine),
      if (owner.sessionId != null) owner.sessionId!,
      if (owner.kind == WorkbenchDocumentKind.table)
        owner.view.subview == 'data'
            ? strings(context).data
            : strings(context).structure,
    ].where((s) => s.isNotEmpty).join(' · '),
  );
}
