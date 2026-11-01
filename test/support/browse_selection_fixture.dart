import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'fake_backend.dart';

/// Opt-in fixtures supply actual test identities. The shared metadata envelope
/// never invents ids, revision evidence, or semantic completeness.
class PreparedBrowseFixture {
  PreparedBrowseFixture({
    required rpc.SchemaObject relation,
    required Iterable<rpc.SchemaObject> columns,
    this.configuration = 2,
    this.sourceIdentity = fixtureMetadataSourceIdentity,
    this.namesSnapshot = 10,
    this.structureSnapshot = 11,
  }) : relation = relation.deepCopy(),
       columns = columns.map((column) => column.deepCopy()).toList() {
    if (this.relation.stableIdentity.isEmpty ||
        configuration < 1 ||
        this.columns.isEmpty ||
        this.columns.any(
          (column) =>
              column.stableIdentity.isEmpty ||
              column.parentIdentity != this.relation.stableIdentity,
        )) {
      throw ArgumentError(
        'Prepared test metadata must supply exact identities',
      );
    }
  }
  final String sourceIdentity;
  final rpc.SchemaObject relation;
  final List<rpc.SchemaObject> columns;
  final int configuration, namesSnapshot, structureSnapshot;
  bool acquired = false;
  int phase = 0;

  bool matches(rpc.ExploreRequest request) =>
      request.catalog == relation.catalog &&
      request.schema == relation.schema &&
      ((request.kind == relation.kind &&
              request.exactName &&
              request.search == relation.name) ||
          (request.kind == rpc.ObjectKind.COLUMN &&
              request.table == relation.name));

  rpc.SchemaObjects reply(
    WorkbenchModel model,
    TestBackend backend,
    rpc.ExploreRequest request,
  ) {
    // Explorer's subtype query filter is only for FUNCTION/PROCEDURE routine
    // scopes. Returned relation descriptors retain their own native subtype.
    if (request.subtype != rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED) {
      throw GrpcError.invalidArgument(
        'Relation scopes do not support routine subtype filters',
      );
    }
    final session = model.sessions[request.sessionId]!;
    final children = request.kind == rpc.ObjectKind.COLUMN;
    final level = children
        ? 2
        : request.introspectionLevel == 0
        ? 1
        : request.introspectionLevel;
    if (children) acquired = true;
    final revision = Int64(acquired ? structureSnapshot : namesSnapshot);
    final values = children ? columns : [relation];
    final limit = request.limit == 0 ? 128 : request.limit;
    final projected = values
        .take(limit)
        .map(
          (object) => object.deepCopy()
            ..metadataSnapshotRevision = revision
            ..introspectionLevel = level
            ..metadataState = 'AVAILABLE',
        );
    phase++;
    return rpc.SchemaObjects(
      instanceId: backend.instanceId,
      profileId: session.profile.id,
      sessionId: session.sessionId,
      contextRevision: session.contextRevision,
      sessionRevision: session.sessionRevision,
      catalog: request.catalog,
      schema: request.schema,
      parent: request.table,
      kind: request.kind,
      subtype: request.subtype,
      objects: projected,
      complete: values.length <= limit,
      continuation: values.length <= limit ? '' : 'prepared-next-column',
      availability: 'available',
      metadataState: 'AVAILABLE',
      introspectionLevel: level,
      metadataSnapshotRevision: revision,
      metadataConfigurationRevision: Int64(configuration),
      metadataSourceIdentity: sourceIdentity,
      countAvailability: rpc.MetadataCount.AUTHORITATIVE_TOTAL,
      totalCount: Int64(values.length),
    );
  }

  void install(WorkbenchModel model, TestBackend backend) {
    final previous = backend.client.metadataAction;
    backend.client.metadataAction = (request) async => matches(request)
        ? reply(model, backend, request)
        : previous == null
        ? rpc.SchemaObjects(complete: true)
        : await previous(request);
  }
}
