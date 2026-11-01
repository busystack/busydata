import '../../backend/workbench_failure.dart';

/// Opaque, server-issued ownership only. This contains no database objects,
/// identifier rules, JDBC state or independently inferred source identity.
class MetadataRevisionStamp {
  const MetadataRevisionStamp({
    required this.backendInstance,
    required this.profileId,
    required this.sourceIdentity,
    required this.sessionId,
    required this.sessionRevision,
    required this.contextRevision,
    required this.configuration,
    required this.snapshot,
  });
  final String backendInstance, profileId, sourceIdentity, sessionId;
  final int sessionRevision, contextRevision, configuration, snapshot;
  static final _source = RegExp(r'^[0-9a-f]{64}$');

  bool get wellFormed =>
      [backendInstance, sessionId].every(
        (value) =>
            value.isNotEmpty &&
            value.length <= 128 &&
            !value.contains('\u0000'),
      ) &&
      profileId.length <= 8192 &&
      !profileId.contains('\u0000') &&
      sourceIdentity.length == 64 &&
      _source.hasMatch(sourceIdentity) &&
      sessionRevision >= 0 &&
      contextRevision >= 0 &&
      configuration > 0 &&
      snapshot >= 0;

  bool sameSource(MetadataRevisionStamp other) =>
      backendInstance == other.backendInstance &&
      sourceIdentity == other.sourceIdentity;
  bool samePhysicalOwner(MetadataRevisionStamp other) =>
      sameSource(other) &&
      profileId == other.profileId &&
      sessionId == other.sessionId;
  bool sameEpoch(MetadataRevisionStamp other) =>
      samePhysicalOwner(other) &&
      sessionRevision == other.sessionRevision &&
      contextRevision == other.contextRevision;
  bool sameValue(MetadataRevisionStamp other) =>
      sameEpoch(other) &&
      configuration == other.configuration &&
      snapshot == other.snapshot;

  MetadataRevisionStamp withDomain({
    int? sessionRevision,
    int? contextRevision,
    int? configuration,
    int? snapshot,
  }) => MetadataRevisionStamp(
    backendInstance: backendInstance,
    profileId: profileId,
    sourceIdentity: sourceIdentity,
    sessionId: sessionId,
    sessionRevision: sessionRevision ?? this.sessionRevision,
    contextRevision: contextRevision ?? this.contextRevision,
    configuration: configuration ?? this.configuration,
    snapshot: snapshot ?? this.snapshot,
  );
}

/// Java-issued physical ownership. Configuration is never inferred here.
class MetadataPhysicalOwner {
  const MetadataPhysicalOwner({
    required this.backendInstance,
    required this.profileId,
    required this.sourceIdentity,
    required this.sessionId,
    required this.sessionRevision,
    required this.contextRevision,
  });
  final String backendInstance, profileId, sourceIdentity, sessionId;
  final int sessionRevision, contextRevision;
  bool get wellFormed =>
      [backendInstance, sessionId].every(
        (value) =>
            value.isNotEmpty &&
            value.length <= 128 &&
            !value.contains('\u0000'),
      ) &&
      profileId.length <= 8192 &&
      !profileId.contains('\u0000') &&
      sourceIdentity.length == 64 &&
      MetadataRevisionStamp._source.hasMatch(sourceIdentity) &&
      sessionRevision >= 0 &&
      contextRevision >= 0;
  bool owns(MetadataRevisionStamp stamp) =>
      backendInstance == stamp.backendInstance &&
      profileId == stamp.profileId &&
      sourceIdentity == stamp.sourceIdentity &&
      sessionId == stamp.sessionId;
  bool sameEpoch(MetadataRevisionStamp stamp) =>
      owns(stamp) &&
      sessionRevision == stamp.sessionRevision &&
      contextRevision == stamp.contextRevision;
  MetadataRevisionStamp observation({
    required int configuration,
    required int snapshot,
  }) => MetadataRevisionStamp(
    backendInstance: backendInstance,
    profileId: profileId,
    sourceIdentity: sourceIdentity,
    sessionId: sessionId,
    sessionRevision: sessionRevision,
    contextRevision: contextRevision,
    configuration: configuration,
    snapshot: snapshot,
  );
}

/// One prepared scalar publication. No observable state changes during admission.
class PreparedMetadataRevision {
  PreparedMetadataRevision._(
    this._owner,
    this._generation,
    this._next,
    this.changed,
  );
  final MetadataRevisionRegistry _owner;
  final int _generation;
  final Map<String, MetadataRevisionStamp> _next;
  final bool changed;
  bool _consumed = false;
}

/// The backend admits at most eight physical sessions. This bounded registry is
/// the UI's one ownership fence, never a second semantic metadata model.
class MetadataRevisionRegistry {
  static const maxSessions = 8;
  Map<String, MetadataRevisionStamp> _published = const {};
  int _generation = 0;

  MetadataRevisionStamp? current({
    required String backendInstance,
    required String profileId,
    required String sessionId,
    required String sourceIdentity,
    required int sessionRevision,
    required int contextRevision,
  }) {
    final owner = MetadataPhysicalOwner(
      backendInstance: backendInstance,
      profileId: profileId,
      sourceIdentity: sourceIdentity,
      sessionId: sessionId,
      sessionRevision: sessionRevision,
      contextRevision: contextRevision,
    );
    final observed = _published[sessionId];
    if (!owner.wellFormed ||
        observed == null ||
        !owner.owns(observed) ||
        sessionRevision < observed.sessionRevision ||
        contextRevision < observed.contextRevision) {
      return null;
    }
    if (observed.sessionRevision == sessionRevision &&
        observed.contextRevision == contextRevision) {
      return observed;
    }
    // The source configuration remains known; this epoch has no snapshot yet.
    return observed.withDomain(
      sessionRevision: sessionRevision,
      contextRevision: contextRevision,
      snapshot: 0,
    );
  }

  bool isCurrent(MetadataRevisionStamp stamp) {
    if (!stamp.wellFormed) return false;
    final observed = _published[stamp.sessionId];
    return observed != null &&
        observed.sameEpoch(stamp) &&
        observed.configuration == stamp.configuration &&
        stamp.snapshot >= observed.snapshot;
  }

  PreparedMetadataRevision prepare(
    MetadataRevisionStamp stamp, {
    required String backendInstance,
    required Iterable<MetadataPhysicalOwner> liveOwners,
  }) {
    if (!stamp.wellFormed) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.malformedRequest,
      );
    }
    final owners = <String, MetadataPhysicalOwner>{};
    for (final owner in liveOwners) {
      if (!owner.wellFormed) {
        throw const LocalWorkbenchFailure(
          WorkbenchFailureReason.malformedRequest,
        );
      }
      if (owner.backendInstance != backendInstance ||
          owners.containsKey(owner.sessionId)) {
        throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
      }
      if (owners.length >= maxSessions) {
        throw const LocalWorkbenchFailure(WorkbenchFailureReason.unavailable);
      }
      owners[owner.sessionId] = owner;
    }
    final responding = owners[stamp.sessionId];
    if (stamp.backendInstance != backendInstance ||
        responding == null ||
        !responding.owns(stamp)) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (!responding.sameEpoch(stamp)) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidRevision);
    }
    final next = <String, MetadataRevisionStamp>{};
    for (final entry in _published.entries) {
      final owner = owners[entry.key];
      if (entry.value.backendInstance != backendInstance || owner == null) {
        continue;
      }
      if (!owner.owns(entry.value)) {
        throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
      }
      if (owner.sessionRevision < entry.value.sessionRevision ||
          owner.contextRevision < entry.value.contextRevision) {
        throw const LocalWorkbenchFailure(
          WorkbenchFailureReason.invalidRevision,
        );
      }
      next[entry.key] = owner.sameEpoch(entry.value)
          ? entry.value
          : owner.observation(
              configuration: entry.value.configuration,
              snapshot: 0,
            );
    }
    var configuration = 0;
    for (final observed in next.values) {
      if (observed.sameSource(stamp) &&
          observed.configuration > configuration) {
        configuration = observed.configuration;
      }
    }
    if (stamp.configuration < configuration) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.stale);
    }
    // The actual observed policy belongs to every live physical owner of this
    // Java-issued source, including a console with no previous metadata reply.
    // Floor-only records preserve it when the observing console disconnects.
    for (final owner in owners.values) {
      if (owner.sourceIdentity != stamp.sourceIdentity) continue;
      final previous = next[owner.sessionId];
      if (previous == null || previous.configuration < stamp.configuration) {
        next[owner.sessionId] = owner.observation(
          configuration: stamp.configuration,
          snapshot: 0,
        );
      }
    }
    final current = next[stamp.sessionId];
    if (current != null &&
        current.sameEpoch(stamp) &&
        current.configuration == stamp.configuration &&
        stamp.snapshot < current.snapshot) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.stale);
    }
    next[stamp.sessionId] = stamp;
    final changed =
        next.length != _published.length ||
        next.entries.any(
          (entry) => _published[entry.key]?.sameValue(entry.value) != true,
        );
    return PreparedMetadataRevision._(
      this,
      _generation,
      Map.unmodifiable(next),
      changed,
    );
  }

  bool publish(PreparedMetadataRevision prepared) {
    if (!identical(prepared._owner, this) ||
        prepared._consumed ||
        prepared._generation != _generation) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.stale);
    }
    prepared._consumed = true;
    _published = prepared._next;
    _generation++;
    return prepared.changed;
  }
}
