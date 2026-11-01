import 'dart:convert';
import 'package:fixnum/fixnum.dart';
import '../../backend/generated/busydata.pb.dart';

/// Pure ownership/shape validation shared by full enumeration and narrow
/// acquisition acknowledgements. This makes no completeness/identity claims.
void validateMetadataPage(
  SchemaObjects reply,
  ExploreRequest request,
  SessionInfo session,
  String instanceId,
) {
  if (reply.metadataSourceIdentity.length != 64 ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(reply.metadataSourceIdentity) ||
      reply.metadataSnapshotRevision.isNegative ||
      reply.metadataConfigurationRevision <= Int64.ZERO ||
      reply.instanceId != instanceId ||
      reply.profileId != session.profile.id ||
      reply.sessionId != session.sessionId ||
      reply.contextRevision != session.contextRevision ||
      reply.sessionRevision != session.sessionRevision ||
      reply.catalog != request.catalog ||
      reply.schema != request.schema ||
      reply.parent != request.table ||
      reply.kind != request.kind ||
      reply.subtype != request.subtype ||
      reply.objects.length > request.limit ||
      reply.writeToBuffer().length > 1048576 ||
      reply.continuation.length > 24576 ||
      reply.objects.any(
        (o) =>
            o.writeToBuffer().length > 65536 ||
            utf8.encode(o.identifier).length > 8192 ||
            [
              o.name,
              o.catalog,
              o.schema,
              o.table,
            ].any((v) => v.length > 256 || v.contains('\u0000')) ||
            o.kind != request.kind ||
            (request.kind == ObjectKind.CATALOG
                ? o.catalog != o.name
                : o.catalog != request.catalog) ||
            ![ObjectKind.CATALOG, ObjectKind.SCHEMA].contains(request.kind) &&
                o.schema != request.schema ||
            ([
                  ObjectKind.COLUMN,
                  ObjectKind.INDEX,
                  ObjectKind.CONSTRAINT,
                  ObjectKind.FOREIGN_KEY,
                  ObjectKind.TRIGGER,
                ].contains(request.kind)
                ? request.table.isNotEmpty && o.table != request.table
                : o.table.isNotEmpty) ||
            request.exactName && o.name != request.search ||
            request.identifier.isNotEmpty && o.identifier != request.identifier,
      )) {
    throw StateError(
      'Metadata reply belongs to another object or inspection context',
    );
  }
}

/// Bind the existing explicit namespace/context policy once for all metadata
/// consumers. No client identifier folding or database-semantic inference.
ExploreRequest bindMetadataRequest(
  ExploreRequest scope,
  Context context,
  SessionInfo session,
) {
  final request = scope.deepCopy()
    ..context = context
    ..sessionId = session.sessionId
    ..expectedSessionRevision = session.sessionRevision
    ..expectedContextRevision = session.contextRevision;
  if (request.catalog.isEmpty) {
    request.catalog =
        session.profile.engine != Engine.POSTGRESQL && request.schema.isNotEmpty
        ? request.schema
        : session.currentCatalog;
  }
  if (request.schema.isEmpty &&
      ![ObjectKind.CATALOG, ObjectKind.SCHEMA].contains(request.kind)) {
    request.schema = session.currentSchema;
  }
  return request;
}
