import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/schedule/worker_leave_repository.dart';
import 'package:worker_app/features/schedule/worker_schedule_leave_screen.dart';

void main() {
  testWidgets(
    'compact schedule shows selected-day appointments and leave tab',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeBackendLeaveRepository();
      addTearDown(repository.dispose);
      final today = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: WorkerScheduleLeaveScreen(
            demoMode: false,
            leaveRepository: repository,
            appointments: [
              WorkerScheduleAppointment(
                day: today,
                booking: WorkerDashboardOrder(
                  id: 'today',
                  customer: 'Scheduled Customer',
                  service: 'Hair Spa',
                  time: '10:00 AM',
                  location: 'Latur',
                  customerPayable: 999,
                  status: 'Scheduled',
                  appointmentDate: today,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hair Spa'), findsOneWidget);
      expect(find.textContaining('Scheduled Customer'), findsOneWidget);
      expect(find.text('₹999'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Schedule Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Leave Requests'), findsOneWidget);
      expect(find.text('No leave requests submitted yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('schedule has no overflow on a compact phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeBackendLeaveRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkerScheduleLeaveScreen(
          demoMode: false,
          leaveRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Schedule & Leave'), findsOneWidget);
    expect(find.text('My Schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production leave action submits through the repository', (
    tester,
  ) async {
    final repository = _FakeBackendLeaveRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkerScheduleLeaveScreen(
          demoMode: false,
          leaveRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply for Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Submit Leave Request'), findsOneWidget);
    await tester.tap(find.text('Submit Leave Request'));
    await tester.pumpAndSettle();

    expect(repository.submitted, 1);
    expect(tester.takeException(), isNull);
  });
}

class _FakeBackendLeaveRepository extends WorkerBackendLeaveRepository {
  int submitted = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<WorkerLeaveRequest> saveDraft({
    required DateTime from,
    required DateTime to,
    required String reason,
  }) async {
    submitted++;
    return WorkerLeaveRequest(
      id: 'test-leave',
      from: from,
      to: to,
      reason: reason,
      createdAt: DateTime.now(),
      status: WorkerLeaveStatus.pending,
    );
  }
}
