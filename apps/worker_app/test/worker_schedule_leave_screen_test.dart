import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/schedule/worker_schedule_leave_screen.dart';

void main() {
  testWidgets(
    'compact schedule shows selected-day appointments and leave tab',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: WorkerScheduleLeaveScreen(
            demoMode: false,
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

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Leave Requests'), findsOneWidget);
      expect(find.text('No demo leave requests yet.'), findsOneWidget);
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

    await tester.pumpWidget(
      const MaterialApp(home: WorkerScheduleLeaveScreen(demoMode: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Schedule / Leave'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
