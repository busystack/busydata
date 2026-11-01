import 'package:busydata/src/backend/connection_failure.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'test_localized_app.dart';

void main() {
  testWidgets(
    'metadata scope and limits use the active locale including combined limits',
    (tester) async {
      const live =
          'Persistent objects in the live context; busy/idle-manual console-local objects require a session refresh after execution';
      const search =
          'Persistent objects in the current database context; temporary/session-local objects remain in console navigation';
      const limit =
          'limited: catalog byte/row budget reached; narrow the object scope';
      for (final locale in ['en', 'fr', 'ar', 'ja']) {
        late BuildContext context;
        await tester.pumpWidget(
          localizedTestApp(
            locale: Locale(locale),
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        final l = strings(context);
        expect(
          workbenchMetadataAvailability(context, live),
          l.metadataSessionScope,
        );
        expect(
          workbenchMetadataAvailability(context, search),
          l.metadataPersistentScope,
        );
        expect(
          workbenchMetadataAvailability(context, limit),
          l.metadataLimitScope,
        );
        expect(
          workbenchMetadataAvailability(context, '$limit; $live'),
          '${l.metadataLimitScope} ${l.metadataSessionScope}',
        );
        expect(
          operationFailureSummary(
            StateError('Local Explorer objects exceed their storage budget'),
            locale: l,
          ),
          l.limitReached,
        );
        expect(
          operationFailureSummary(
            StateError(
              'Move contained sources and folders before removing this folder',
            ),
            locale: l,
          ),
          l.folderMustBeEmpty,
        );
        expect(
          operationFailureSummary(
            StateError('The local definition needs an explicit source binding'),
            locale: l,
          ),
          l.unboundVirtualView,
        );
      }
    },
  );
  test(
    'metadata status distinguishes stale enumeration, permission, timeout and cancellation without server messages',
    () {
      const secret = 'private server text';
      final failures = <GrpcError, ConnectionFailureReason>{
        const GrpcError.custom(
          StatusCode.failedPrecondition,
          secret,
          null,
          null,
          {'busydata-metadata-reason': 'restart-enumeration'},
        ): ConnectionFailureReason.metadataStale,
        const GrpcError.permissionDenied(secret):
            ConnectionFailureReason.access,
        const GrpcError.deadlineExceeded(secret):
            ConnectionFailureReason.timeout,
        const GrpcError.cancelled(secret): ConnectionFailureReason.cancelled,
        const GrpcError.unimplemented(secret):
            ConnectionFailureReason.unsupported,
      };
      for (final entry in failures.entries) {
        final failure = ConnectionFailure.from(entry.key);
        expect(failure.reason, entry.value);
        expect(failure.summary, isNot(contains(secret)));
        expect(failure.details, isNot(contains(secret)));
      }
    },
  );
}
