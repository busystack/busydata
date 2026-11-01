import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'fake_backend.dart';

/// Declared mock-server ownership/configuration/snapshot domain. This never
/// supplies executable object identities or structural completeness.
WorkbenchModel metadataFixture(
  WorkbenchModel model, {
  String sourceIdentity = fixtureMetadataSourceIdentity,
  int snapshotRevision = 1,
  int configurationRevision = 1,
}) {
  final backend = model.backend;
  if (backend is! TestBackend) return model;
  backend.client.metadataEnvelope = (request, original) {
    final session = model.sessions[request.sessionId];
    if (session == null) return original;
    final reply = original.deepCopy();
    if (!reply.hasMetadataSourceIdentity()) {
      reply.metadataSourceIdentity = sourceIdentity;
    }
    if (!reply.hasMetadataSnapshotRevision()) {
      reply.metadataSnapshotRevision = Int64(snapshotRevision);
    }
    if (!reply.hasMetadataConfigurationRevision()) {
      reply.metadataConfigurationRevision = Int64(configurationRevision);
    }
    if (request.exactName) {
      reply.objects.removeWhere(
        (o) =>
            o.name != request.search ||
            request.identifier.isNotEmpty && o.identifier != request.identifier,
      );
    }
    final catalog = request.catalog.isEmpty
        ? session.currentCatalog
        : request.catalog;
    if (request.kind == rpc.ObjectKind.CATALOG &&
        reply.complete &&
        reply.objects.isEmpty &&
        catalog.isNotEmpty) {
      reply.objects.add(
        rpc.SchemaObject(
          kind: rpc.ObjectKind.CATALOG,
          name: catalog,
          catalog: catalog,
          schema: session.profile.engine == rpc.Engine.POSTGRESQL
              ? ''
              : catalog,
        ),
      );
    }
    if (!reply.hasInstanceId()) reply.instanceId = request.context.instanceId;
    if (!reply.hasProfileId()) reply.profileId = session.profile.id;
    if (!reply.hasSessionId()) reply.sessionId = request.sessionId;
    if (!reply.hasContextRevision()) {
      reply.contextRevision = session.contextRevision;
    }
    if (!reply.hasSessionRevision()) {
      reply.sessionRevision =
          session.sessionRevision + (request.refresh ? Int64.ONE : Int64.ZERO);
    }
    if (!reply.hasCatalog()) reply.catalog = catalog;
    if (!reply.hasSchema()) reply.schema = request.schema;
    if (!reply.hasParent()) reply.parent = request.table;
    if (!reply.hasKind()) reply.kind = request.kind;
    if (!reply.hasSubtype()) reply.subtype = request.subtype;
    for (final object in reply.objects) {
      if (!object.hasKind()) object.kind = request.kind;
      if (object.kind == rpc.ObjectKind.COLUMN) {
        object.properties.putIfAbsent('generated', () => 'NO');
        object.properties.putIfAbsent('autoIncrement', () => 'NO');
      }
      if (object.catalog.isEmpty) {
        object.catalog = request.kind == rpc.ObjectKind.CATALOG
            ? object.name
            : catalog;
      }
      if (object.schema.isEmpty) {
        object.schema = request.kind == rpc.ObjectKind.SCHEMA
            ? object.name
            : request.kind == rpc.ObjectKind.CATALOG
            ? session.profile.engine == rpc.Engine.POSTGRESQL
                  ? ''
                  : object.name
            : request.schema;
      }
      if (object.table.isEmpty &&
          [
            rpc.ObjectKind.COLUMN,
            rpc.ObjectKind.INDEX,
            rpc.ObjectKind.CONSTRAINT,
            rpc.ObjectKind.FOREIGN_KEY,
            rpc.ObjectKind.TRIGGER,
          ].contains(request.kind)) {
        object.table = request.table;
      }
    }
    final offset = request.continuation.startsWith('fixture:')
        ? int.parse(request.continuation.substring(8))
        : 0;
    final limit = request.limit == 0 ? 128 : request.limit;
    if (reply.complete && (reply.objects.length > limit || offset > 0)) {
      final all = reply.objects.toList();
      final end = (offset + limit).clamp(0, all.length);
      reply.objects
        ..clear()
        ..addAll(all.sublist(offset, end));
      reply.totalCount = Int64(all.length);
      reply.countAvailability = rpc.MetadataCount.AUTHORITATIVE_TOTAL;
      reply.complete = end == all.length;
      reply.continuation = reply.complete ? '' : 'fixture:$end';
    }
    return reply;
  };
  return model;
}
