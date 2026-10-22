import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/integration/worker_api.dart';
import 'package:worker_app/integration/worker_environment.dart';

void main() {
  const api = PendingWorkerApi();
  test('local preview is opt-in', () {
    expect(
      WorkerEnvironment.developmentPreview,
      const bool.fromEnvironment('WORKER_DEVELOPMENT_PREVIEW'),
    );
  });
  test('only approved server identity may work', () {
    for (final status in WorkerApproval.values) {
      expect(
        WorkerIdentity(workerId: 'server-id', approval: status).mayWork,
        status == WorkerApproval.approved,
      );
    }
  });
  test('auth pending never fabricates identity or OTP delivery', () async {
    for (final operation in [
      () => api.requestOtp('9876543210'),
      () => api.verifyOtp('9876543210', '123456'),
      () => api.currentIdentity(),
      () => api.logout(),
    ]) {
      await expectLater(operation(), throwsA(isA<WorkerIntegrationPending>()));
    }
  });
  test('operations fail closed without local fixture fallback', () async {
    await expectLater(
      api.assignments(),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    await expectLater(
      api.updateAvailability(true),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    await expectLater(
      api.availability(),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    for (final action in WorkerJobAction.values) {
      await expectLater(
        api.transition(
          assignmentId: 'server-id',
          action: action,
          idempotencyKey: 'retry-key',
          arrivalOtp: '123456',
          rejectionReason: 'Busy',
        ),
        throwsA(isA<WorkerIntegrationPending>()),
      );
    }
    await expectLater(
      api.collection('server-booking'),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    await expectLater(
      api.recordCash(bookingId: 'server-booking', idempotencyKey: 'cash-key'),
      throwsA(isA<WorkerIntegrationPending>()),
    );
    await expectLater(
      api.settlements(),
      throwsA(isA<WorkerIntegrationPending>()),
    );
  });
  test('settlement money remains integer paise and pages immutable', () {
    final row = WorkerSettlementRecord(
      id: 's1',
      settlementDate: DateTime.utc(2026),
      bookingCount: 2,
      earningsPaise: 10001,
      adjustmentsPaise: -1,
      netPaise: 10000,
      status: 'pending',
    );
    final page = WorkerPage(items: [row], page: 1, hasMore: false);
    expect(page.items.single.netPaise, 10000);
    expect(() => page.items.clear(), throwsUnsupportedError);
  });
}
