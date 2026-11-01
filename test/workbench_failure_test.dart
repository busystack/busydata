import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/backend/connection_failure.dart';
import 'package:busydata/l10n/generated/app_localizations_en.dart';
import 'package:busydata/l10n/generated/app_localizations_de.dart';
import 'package:busydata/l10n/generated/app_localizations_ar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

void main() {
  test('typed workbench failures require exact reason and matching status', () {
    for (final reason in WorkbenchFailureReason.values) {
      final error = GrpcError.custom(
        reason.statusCode,
        'untrusted SQL and secrets',
        null,
        null,
        {'busydata-workbench-reason': reason.wire},
      );
      expect(WorkbenchFailureReason.fromError(error), reason);
      expect(
        WorkbenchFailureReason.fromError(
          GrpcError.custom(StatusCode.internal, reason.wire, null, null, {
            'busydata-workbench-reason': reason.wire,
          }),
        ),
        isNull,
      );
    }
  });
  test(
    'machine editability reasons share localized operation explanations',
    () {
      final l = AppLocalizationsEn();
      for (final reason in WorkbenchFailureReason.values) {
        expect(WorkbenchFailureReason.fromWire(reason.wire), reason);
        final error = GrpcError.custom(
          reason.statusCode,
          'secret SQL',
          null,
          null,
          {'busydata-workbench-reason': reason.wire},
        );
        expect(operationFailureSummary(error, locale: l), reason.localized(l));
        expect(reason.localized(l), isNot(contains('secret SQL')));
      }
      expect(
        WorkbenchFailureReason.incompleteMetadata.localized(l),
        l.columnMetadataUnavailable,
      );
      expect(
        WorkbenchFailureReason.backendRestarted.localized(l),
        l.retainedUnavailable,
      );
      expect(
        WorkbenchFailureReason.readOnlyPolicy.localized(l),
        l.readonlyChanges,
      );
      expect(
        WorkbenchFailureReason.sessionBusy.localized(l),
        l.editSessionBusy,
      );
      expect(
        WorkbenchFailureReason.editIdentityRequired.localized(l),
        l.editIdentityRequired,
      );
      expect(
        WorkbenchFailureReason.editColumnsReadOnly.localized(l),
        l.editColumnsReadOnly,
      );
      expect(
        WorkbenchFailureReason.editResultNotReady.localized(l),
        l.editResultNotReady,
      );
      expect(
        WorkbenchFailureReason.editProjectionUnsupported.localized(l),
        l.editProjectionUnsupported,
      );
      for (final locale in [AppLocalizationsDe(), AppLocalizationsAr()]) {
        for (final reason in [
          WorkbenchFailureReason.readOnlyPolicy,
          WorkbenchFailureReason.sessionBusy,
          WorkbenchFailureReason.editIdentityRequired,
          WorkbenchFailureReason.editColumnsReadOnly,
          WorkbenchFailureReason.editResultNotReady,
          WorkbenchFailureReason.editProjectionUnsupported,
        ]) {
          expect(reason.localized(locale), isNotEmpty);
          expect(reason.localized(locale), isNot(reason.localized(l)));
        }
      }
      for (final wire in [
        '',
        'INCOMPLETE_METADATA',
        'stale: secret',
        'unknown',
      ]) {
        expect(WorkbenchFailureReason.fromWire(wire), isNull);
      }
    },
  );
  test(
    'messages transport codes unknown and malformed trailers never imply a cause',
    () {
      for (final value in [
        '',
        'INVALID_OWNER',
        'invalid-owner',
        'unknown',
        'denied: password',
        'transaction_unknown\nsecret',
      ]) {
        expect(
          WorkbenchFailureReason.fromError(
            GrpcError.custom(
              StatusCode.failedPrecondition,
              'invalid_owner',
              null,
              null,
              {'busydata-workbench-reason': value},
            ),
          ),
          isNull,
        );
      }
      expect(
        WorkbenchFailureReason.fromError(
          const GrpcError.failedPrecondition('transaction_unknown'),
        ),
        isNull,
      );
      expect(
        WorkbenchFailureReason.fromError(StateError('invalid_owner')),
        isNull,
      );
      expect(
        WorkbenchFailureReason.fromError(
          const GrpcError.unavailable('backend_restarted'),
        ),
        isNull,
      );
    },
  );
}
