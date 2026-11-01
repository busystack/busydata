import 'dart:async';
import 'dart:io';
import 'package:busydata/l10n/generated/app_localizations_en.dart';
import 'package:busydata/src/backend/connection_failure.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'fake_backend.dart';

class RelatedRevisionClient extends TestClient {
  final pending = Completer<rpc.RelatedRowsReply>();
  final requests = <rpc.RelatedRowsRequest>[];
  final additionalPending = <Completer<rpc.RelatedRowsReply>>[];

  @override
  ResponseFuture<rpc.RelatedRowsReply> relatedRows(
    rpc.RelatedRowsRequest request, {
    CallOptions? options,
  }) {
    requests.add(request.deepCopy());
    if (requests.length == 1) return response(pending.future);
    final next = Completer<rpc.RelatedRowsReply>();
    additionalPending.add(next);
    return response(next.future);
  }
}

WorkbenchModel relatedWorkspace(
  RelatedRevisionClient client, {
  bool observedMetadata = true,
}) {
  final profile = rpc.Profile(id: 'p', engine: rpc.Engine.POSTGRESQL);
  final model = WorkbenchModel(Directory('/unused'))
    ..draftRecovery = false
    ..backend = TestBackend(client: client)
    ..profiles.add(profile)
    ..newDocument(text: 'SELECT untouched');
  model.document
    ..profileId = 'p'
    ..sessionId = 's';
  model.sessions['s'] = rpc.SessionInfo(
    metadataSourceIdentity: fixtureMetadataSourceIdentity,
    sessionId: 's',
    profile: profile,
    currentCatalog: 'db',
    currentSchema: 'public',
    contextRevision: Int64.ONE,
    sessionRevision: Int64(7),
    transaction: rpc.TransactionState.IDLE,
    autoCommit: true,
  );
  if (observedMetadata) {
    model.acceptMetadataSnapshotRevision(
      's',
      10,
      2,
      sourceIdentity: fixtureMetadataSourceIdentity,
    );
  }
  return model;
}

rpc.RelatedRowsRequest relatedRequest({
  int snapshot = 0,
  String sessionId = 's',
  String resultId = 'source',
}) => rpc.RelatedRowsRequest(
  sessionId: sessionId,
  documentId: 'source-document',
  resultId: resultId,
  sourceRow: Int64.ONE,
  snapshotRevision: Int64(snapshot),
);

rpc.RelatedRowsReply relatedReply({
  int snapshot = 10,
  int configuration = 2,
  String sourceIdentity = fixtureMetadataSourceIdentity,
  String sessionId = 's',
  int sessionRevision = 7,
  int contextRevision = 1,
  String backendInstance = 'test-instance',
  String profileId = 'p',
  String resultId = 'source',
}) => rpc.RelatedRowsReply(
  resultId: resultId,
  sourceRow: Int64.ONE,
  backendInstance: backendInstance,
  profileId: profileId,
  metadataSourceIdentity: sourceIdentity,
  sessionId: sessionId,
  sessionRevision: Int64(sessionRevision),
  contextRevision: Int64(contextRevision),
  metadataConfigurationRevision: Int64(configuration),
  snapshotRevision: Int64(snapshot),
  availability: 'available',
  relationships: [
    rpc.RelatedRelationship(
      identity: 'fk-identity',
      name: 'fk_fixture',
      availability: 'available',
      browse: rpc.BrowseRequest(
        sessionId: sessionId,
        catalog: 'db',
        schema: 'public',
        table: 'target',
        metadataSnapshotRevision: Int64(snapshot),
        metadataObjectIdentity: 'target-identity',
        originRelationshipIdentity: 'fk-identity',
        originResultId: resultId,
        originSourceRow: Int64.ONE,
      ),
    ),
  ],
);

Matcher relatedFailure(WorkbenchFailureReason reason) =>
    isA<LocalWorkbenchFailure>()
        .having((failure) => failure.reason, 'typed reason', reason)
        .having(
          (failure) => operationFailureSummary(failure),
          'existing localized summary',
          reason.localized(AppLocalizationsEn()),
        );
