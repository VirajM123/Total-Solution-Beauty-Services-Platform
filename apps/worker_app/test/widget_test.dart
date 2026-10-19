import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_session.dart';
import 'package:worker_app/features/home/worker_booking_state_repository.dart';

class _MemoryStore implements WorkerBookingSessionStorage {
  String? contents;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String value) async {
    contents = value;
  }

  @override
  Future<void> clear() async {
    contents = null;
  }
}

void main() {
  test(
    'started session survives repository recreation and cannot restart',
    () async {
      final store = _MemoryStore();
      final first = WorkerBookingStateRepository(store, demoMode: true);
      await first.initialize();

      final startedAt = DateTime.utc(2026, 10, 17, 9, 0);
      await first.startService(
        bookingId: 'P-002',
        baseCustomerPayable: 1200,
        otpVerifiedInPreview: true,
        at: startedAt,
      );

      final restored = WorkerBookingStateRepository(store, demoMode: true);
      await restored.initialize();
      expect(restored.byId('P-002')?.startedAt, startedAt);
      expect(restored.hasActivePhysicalService, isTrue);

      // startService can throw synchronously before returning a Future.
      expect(
        () => restored.startService(
          bookingId: 'P-002',
          baseCustomerPayable: 1200,
          otpVerifiedInPreview: true,
        ),
        throwsA(isA<WorkerBookingStateException>()),
      );

      first.dispose();
      restored.dispose();
    },
  );

  test(
    'repository owns a stable immutable set of dated demo bookings',
    () async {
      final repo = WorkerBookingStateRepository(_MemoryStore(), demoMode: true);
      await repo.initialize();

      expect(repo.bookings.map((booking) => booking.id), [
        'P-001',
        'P-002',
        'P-003',
      ]);
      expect(repo.bookings.map((booking) => booking.appointmentDate), [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
      ]);
      expect(repo.bookings.first.completedAt, DateTime(2026, 10, 19, 10, 15));
      expect(() => repo.bookings.clear(), throwsUnsupportedError);

      repo.dispose();
    },
  );

  test('extras, finish and demo-paid marker survive restart', () async {
    final store = _MemoryStore();
    final repo = WorkerBookingStateRepository(store, demoMode: true);
    await repo.initialize();

    await repo.startService(
      bookingId: 'P-002',
      baseCustomerPayable: 1200,
      otpVerifiedInPreview: true,
      at: DateTime.utc(2026, 10, 17, 9),
    );
    await repo.updateExtras(
      bookingId: 'P-002',
      extras: const [
        WorkerExtraSnapshot(
          id: 'pedicure',
          name: 'Pedicure',
          customerPrice: 700,
          durationMinutes: 40,
        ),
      ],
    );
    await repo.finishService(
      bookingId: 'P-002',
      at: DateTime.utc(2026, 10, 17, 10),
    );
    await repo.simulatePayment(bookingId: 'P-002');

    final restored = WorkerBookingStateRepository(store, demoMode: true);
    await restored.initialize();
    final saved = restored.byId('P-002')!;
    expect(saved.demoCustomerTotal, 1900);
    expect(saved.serviceStage, WorkerServiceStage.finished);
    expect(saved.paymentStage, WorkerPaymentStage.pending);
    expect(saved.demoPaidAt, isNotNull);
    expect(restored.hasActivePhysicalService, isFalse);

    expect(
      () => restored.startService(
        bookingId: 'P-002',
        baseCustomerPayable: 1200,
        otpVerifiedInPreview: true,
      ),
      throwsA(isA<WorkerBookingStateException>()),
    );

    repo.dispose();
    restored.dispose();
  });

  test(
    'booking session changes notify subscribed dashboard surfaces',
    () async {
      final repo = WorkerBookingStateRepository(_MemoryStore(), demoMode: true);
      var notifications = 0;
      repo.addListener(() => notifications++);
      await repo.initialize();
      await repo.startService(
        bookingId: 'P-002',
        baseCustomerPayable: 1200,
        otpVerifiedInPreview: true,
        at: DateTime(2026, 10, 19, 9),
      );
      await repo.finishService(
        bookingId: 'P-002',
        at: DateTime(2026, 10, 19, 10),
      );

      expect(notifications, 3);
      expect(repo.byId('P-002')?.finishedAt, DateTime(2026, 10, 19, 10));
      repo.dispose();
    },
  );

  test(
    'OTP guard and corrupted storage do not silently reset booking data',
    () async {
      final store = _MemoryStore();
      final repo = WorkerBookingStateRepository(store, demoMode: true);
      await repo.initialize();

      expect(
        () => repo.startService(
          bookingId: 'P-002',
          baseCustomerPayable: 1200,
          otpVerifiedInPreview: false,
        ),
        throwsA(isA<WorkerBookingStateException>()),
      );

      repo.dispose();
      store.contents = '{bad json';
      final broken = WorkerBookingStateRepository(store, demoMode: true);
      await expectLater(broken.initialize(), throwsFormatException);
      expect(broken.isInitialized, isFalse);
      broken.dispose();
    },
  );
}
