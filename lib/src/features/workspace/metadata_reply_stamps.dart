import '../../backend/generated/busydata.pb.dart' as rpc;
import 'metadata_revisions.dart';

MetadataRevisionStamp relatedRowsMetadataStamp(rpc.RelatedRowsReply reply) =>
    MetadataRevisionStamp(
      backendInstance: reply.backendInstance,
      profileId: reply.profileId,
      sourceIdentity: reply.metadataSourceIdentity,
      sessionId: reply.sessionId,
      sessionRevision: reply.sessionRevision.toInt(),
      contextRevision: reply.contextRevision.toInt(),
      configuration: reply.metadataConfigurationRevision.toInt(),
      snapshot: reply.snapshotRevision.toInt(),
    );

MetadataRevisionStamp schemaMetadataStamp(rpc.SchemaObjects reply) =>
    MetadataRevisionStamp(
      backendInstance: reply.instanceId,
      profileId: reply.profileId,
      sourceIdentity: reply.metadataSourceIdentity,
      sessionId: reply.sessionId,
      sessionRevision: reply.sessionRevision.toInt(),
      contextRevision: reply.contextRevision.toInt(),
      configuration: reply.metadataConfigurationRevision.toInt(),
      snapshot: reply.metadataSnapshotRevision.toInt(),
    );

MetadataRevisionStamp analysisMetadataStamp(
  rpc.Analysis reply, {
  required String profileId,
}) => MetadataRevisionStamp(
  backendInstance: reply.backendInstance,
  profileId: profileId,
  sourceIdentity: reply.metadataSourceIdentity,
  sessionId: reply.sessionId,
  sessionRevision: reply.sessionRevision.toInt(),
  contextRevision: reply.contextRevision.toInt(),
  configuration: reply.metadataConfigurationRevision.toInt(),
  snapshot: reply.metadataSnapshotRevision.toInt(),
);
