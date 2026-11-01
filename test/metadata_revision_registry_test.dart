import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/features/workspace/metadata_revisions.dart';
import 'package:flutter_test/flutter_test.dart';

const sourceA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sourceB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
MetadataRevisionStamp stamp({
  String backend = 'backend',
  String profile = 'p',
  String source = sourceA,
  String session = 'a',
  int revision = 7,
  int context = 1,
  int configuration = 2,
  int snapshot = 10,
}) => MetadataRevisionStamp(
  backendInstance: backend,
  profileId: profile,
  sourceIdentity: source,
  sessionId: session,
  sessionRevision: revision,
  contextRevision: context,
  configuration: configuration,
  snapshot: snapshot,
);
Matcher reason(WorkbenchFailureReason value) => isA<LocalWorkbenchFailure>()
    .having((failure) => failure.reason, 'structured reason', value);
List<MetadataPhysicalOwner> owners(
  MetadataRevisionStamp observation,
  Set<String> live, {
  Map<String, String> sources = const {},
}) => [
  for (final id in live)
    MetadataPhysicalOwner(
      backendInstance: observation.backendInstance,
      profileId: id == observation.sessionId ? observation.profileId : 'p',
      sourceIdentity:
          sources[id] ??
          (id == observation.sessionId ? observation.sourceIdentity : sourceA),
      sessionId: id,
      sessionRevision: id == observation.sessionId
          ? observation.sessionRevision
          : 7,
      contextRevision: id == observation.sessionId
          ? observation.contextRevision
          : 1,
    ),
];
void accept(
  MetadataRevisionRegistry registry,
  MetadataRevisionStamp observation, {
  Set<String>? live,
  Map<String, String> sources = const {},
}) => registry.publish(
  registry.prepare(
    observation,
    backendInstance: observation.backendInstance,
    liveOwners: owners(
      observation,
      live ?? {observation.sessionId},
      sources: sources,
    ),
  ),
);
MetadataRevisionStamp? current(
  MetadataRevisionRegistry registry, {
  String backend = 'backend',
  String session = 'a',
  String profile = 'p',
  String source = sourceA,
  int revision = 7,
  int context = 1,
}) => registry.current(
  backendInstance: backend,
  profileId: profile,
  sourceIdentity: source,
  sessionId: session,
  sessionRevision: revision,
  contextRevision: context,
);

void main() {
  test(
    'same epoch/configuration rejects lower snapshots and admits equal/newer',
    () {
      final registry = MetadataRevisionRegistry();
      accept(registry, stamp());
      expect(
        () => accept(registry, stamp(snapshot: 9)),
        throwsA(reason(WorkbenchFailureReason.stale)),
      );
      expect(current(registry)!.snapshot, 10);
      accept(registry, stamp());
      accept(registry, stamp(snapshot: 11));
      expect(current(registry)!.snapshot, 11);
    },
  );
  test(
    'rollback can return to a lower durable snapshot in a new session epoch',
    () {
      final registry = MetadataRevisionRegistry();
      accept(registry, stamp(snapshot: 20));
      expect(current(registry, revision: 8)!.snapshot, 0);
      expect(current(registry, revision: 8)!.configuration, 2);
      accept(registry, stamp(revision: 8, snapshot: 5));
      expect(current(registry, revision: 8)!.snapshot, 5);
      expect(
        () => accept(registry, stamp(snapshot: 100)),
        throwsA(reason(WorkbenchFailureReason.invalidRevision)),
      );
    },
  );
  test(
    'context changes create a new snapshot domain under the same physical owner',
    () {
      final registry = MetadataRevisionRegistry();
      accept(registry, stamp(snapshot: 20));
      accept(registry, stamp(context: 2, snapshot: 5));
      expect(current(registry, context: 2)!.snapshot, 5);
      expect(
        () => accept(registry, stamp(snapshot: 100)),
        throwsA(reason(WorkbenchFailureReason.invalidRevision)),
      );
    },
  );
  test(
    'higher actual configuration permits a lower snapshot and fences every console',
    () {
      final registry = MetadataRevisionRegistry();
      const live = {'a', 'b'};
      accept(registry, stamp(snapshot: 20), live: live);
      accept(registry, stamp(session: 'b', snapshot: 30), live: live);
      accept(registry, stamp(configuration: 3, snapshot: 4), live: live);
      expect(current(registry)!.snapshot, 4);
      expect(current(registry, session: 'b')!.configuration, 3);
      expect(current(registry, session: 'b')!.snapshot, 0);
      expect(registry.isCurrent(stamp(session: 'b', snapshot: 30)), isFalse);
      expect(
        () => accept(registry, stamp(session: 'b', snapshot: 1000), live: live),
        throwsA(reason(WorkbenchFailureReason.stale)),
      );
      accept(
        registry,
        stamp(session: 'b', configuration: 3, snapshot: 2),
        live: live,
      );
      expect(current(registry, session: 'b')!.snapshot, 2);
    },
  );
  test(
    'source configuration does not invalidate a different opaque source',
    () {
      final registry = MetadataRevisionRegistry();
      const live = {'a', 'b'}, sources = {'b': sourceB};
      accept(registry, stamp(), live: live, sources: sources);
      expect(current(registry, session: 'b', source: sourceB), isNull);
      accept(
        registry,
        stamp(session: 'b', source: sourceB, snapshot: 30),
        live: live,
        sources: sources,
      );
      accept(
        registry,
        stamp(configuration: 3, snapshot: 2),
        live: live,
        sources: sources,
      );
      expect(
        current(registry, session: 'b', source: sourceB)!.configuration,
        2,
      );
      expect(current(registry, session: 'b', source: sourceB)!.snapshot, 30);
    },
  );
  for (final change in ['source', 'profile']) {
    test('a $change mismatch cannot replace the same physical session', () {
      final registry = MetadataRevisionRegistry();
      accept(registry, stamp());
      expect(
        () => accept(
          registry,
          stamp(
            source: change == 'source' ? sourceB : sourceA,
            profile: change == 'profile' ? 'other' : 'p',
            configuration: 3,
            snapshot: 100,
          ),
        ),
        throwsA(reason(WorkbenchFailureReason.invalidOwner)),
      );
      expect(current(registry)!.configuration, 2);
      expect(current(registry)!.snapshot, 10);
    });
  }
  test('a new backend instance starts an independent registry owner', () {
    final registry = MetadataRevisionRegistry();
    accept(registry, stamp(configuration: 9, snapshot: 100));
    accept(
      registry,
      stamp(backend: 'restarted', configuration: 1, revision: 0, snapshot: 1),
    );
    expect(current(registry), isNull);
    expect(
      current(registry, backend: 'restarted', revision: 0)!.configuration,
      1,
    );
  });
  test('present initial session revision0 is a real owner', () {
    final registry = MetadataRevisionRegistry();
    accept(registry, stamp(revision: 0));
    expect(current(registry, revision: 0)!.snapshot, 10);
  });
  test(
    'an unsaved captured profile is still owned through source and physical identity',
    () {
      final registry = MetadataRevisionRegistry();
      accept(registry, stamp(profile: ''));
      expect(current(registry, profile: '')!.sourceIdentity, sourceA);
      expect(current(registry), isNull);
    },
  );
  for (final malformed in [
    'source missing',
    'source size',
    'source syntax',
    'negative snapshot',
    'negative configuration',
    'zero configuration',
    'negative session',
    'negative context',
    'backend missing',
    'session missing',
    'profile nul',
  ]) {
    test('malformed $malformed cannot change the published minimum', () {
      final registry = MetadataRevisionRegistry();
      accept(registry, stamp());
      final invalid = stamp(
        source: switch (malformed) {
          'source missing' => '',
          'source size' => '${sourceA}a',
          'source syntax' => 'x' * 64,
          _ => sourceA,
        },
        snapshot: malformed == 'negative snapshot' ? -1 : 11,
        configuration: malformed == 'negative configuration'
            ? -1
            : malformed == 'zero configuration'
            ? 0
            : 2,
        revision: malformed == 'negative session' ? -1 : 7,
        context: malformed == 'negative context' ? -1 : 1,
        backend: malformed == 'backend missing' ? '' : 'backend',
        session: malformed == 'session missing' ? '' : 'a',
        profile: malformed == 'profile nul' ? String.fromCharCode(0) : 'p',
      );
      expect(
        () => registry.prepare(
          invalid,
          backendInstance: 'backend',
          liveOwners: owners(stamp(), {'a'}),
        ),
        throwsA(reason(WorkbenchFailureReason.malformedRequest)),
      );
      expect(current(registry)!.snapshot, 10);
    });
  }
  test(
    'unavailable snapshot0 retains its actual configuration without object authority',
    () {
      final registry = MetadataRevisionRegistry();
      accept(registry, stamp(configuration: 3, snapshot: 0));
      expect(current(registry)!.configuration, 3);
      expect(current(registry)!.snapshot, 0);
      accept(registry, stamp(configuration: 3, snapshot: 10));
      expect(
        () => accept(registry, stamp(configuration: 3, snapshot: 0)),
        throwsA(reason(WorkbenchFailureReason.stale)),
      );
    },
  );
  test('admission alone or a superseded admission never publishes', () {
    final registry = MetadataRevisionRegistry();
    final cancelled = registry.prepare(
      stamp(snapshot: 11),
      backendInstance: 'backend',
      liveOwners: owners(stamp(), {'a'}),
    );
    expect(current(registry), isNull);
    accept(registry, stamp(snapshot: 12));
    expect(
      () => registry.publish(cancelled),
      throwsA(reason(WorkbenchFailureReason.stale)),
    );
    expect(current(registry)!.snapshot, 12);
  });
  test('a prepared publication is single use', () {
    final registry = MetadataRevisionRegistry();
    final prepared = registry.prepare(
      stamp(),
      backendInstance: 'backend',
      liveOwners: owners(stamp(), {'a'}),
    );
    registry.publish(prepared);
    expect(
      () => registry.publish(prepared),
      throwsA(reason(WorkbenchFailureReason.stale)),
    );
  });
  test(
    'eight validated physical descriptors bound admission and ended owners are reclaimed',
    () {
      final registry = MetadataRevisionRegistry();
      final live = {for (var i = 0; i < 8; i++) 's$i'};
      accept(registry, stamp(session: 's0'), live: live);
      expect(current(registry, session: 's7')!.snapshot, 0);
      expect(
        () => accept(registry, stamp(session: 's8'), live: {...live, 's8'}),
        throwsA(reason(WorkbenchFailureReason.unavailable)),
      );
      accept(registry, stamp(session: 's8'), live: {'s8'});
      expect(current(registry, session: 's0'), isNull);
      expect(current(registry, session: 's8')!.snapshot, 10);
    },
  );
  test(
    'an unobserved same-source console keeps the policy floor after its observer disconnects and unrelated pruning',
    () {
      final registry = MetadataRevisionRegistry();
      const live = {'a', 'h', 'u'}, sources = {'u': sourceB};
      accept(
        registry,
        stamp(configuration: 3, snapshot: 4),
        live: live,
        sources: sources,
      );
      expect(current(registry, session: 'h')!.configuration, 3);
      expect(current(registry, session: 'h')!.snapshot, 0);
      accept(
        registry,
        stamp(session: 'u', source: sourceB, configuration: 1, snapshot: 7),
        live: {'h', 'u'},
        sources: sources,
      );
      accept(
        registry,
        stamp(session: 'u', source: sourceB, configuration: 1, snapshot: 8),
        live: {'h', 'u'},
        sources: sources,
      );
      expect(current(registry), isNull);
      expect(
        () => accept(
          registry,
          stamp(session: 'h', configuration: 2, snapshot: 100),
          live: {'h', 'u'},
          sources: sources,
        ),
        throwsA(reason(WorkbenchFailureReason.stale)),
      );
      expect(current(registry, session: 'h')!.configuration, 3);
      expect(current(registry, session: 'h', revision: 8)!.snapshot, 0);
      expect(
        () => accept(
          registry,
          stamp(session: 'h', revision: 8, configuration: 2, snapshot: 100),
          live: {'h', 'u'},
          sources: sources,
        ),
        throwsA(reason(WorkbenchFailureReason.stale)),
      );
      accept(
        registry,
        stamp(session: 'h', revision: 8, configuration: 3, snapshot: 2),
        live: {'h', 'u'},
        sources: sources,
      );
      expect(current(registry, session: 'h', revision: 8)!.snapshot, 2);
      expect(
        current(registry, session: 'u', source: sourceB)!.configuration,
        1,
      );
    },
  );
  test(
    'descriptor source, duplicate owner and negative epoch are rejected before publication',
    () {
      final registry = MetadataRevisionRegistry();
      accept(registry, stamp());
      for (final bad in [
        owners(stamp(source: sourceB), {'a'}),
        [
          ...owners(stamp(), {'a'}),
          ...owners(stamp(), {'a'}),
        ],
        owners(stamp(revision: -1), {'a'}),
      ]) {
        expect(
          () => registry.prepare(
            stamp(),
            backendInstance: 'backend',
            liveOwners: bad,
          ),
          throwsA(isA<LocalWorkbenchFailure>()),
        );
        expect(current(registry)!.snapshot, 10);
      }
    },
  );
}
