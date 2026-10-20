import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_bookings_screen.dart';

void main() {
  const orders = [
    WorkerDashboardOrder(
      id: 'B-001',
      customer: 'First Customer',
      service: 'Facial Service',
      time: '10:00 AM',
      location: 'Main Street',
      customerPayable: 1200,
      status: 'Scheduled',
    ),
    WorkerDashboardOrder(
      id: 'B-002',
      customer: 'Second Customer',
      service: 'Hair Styling',
      time: '12:30 PM',
      location: 'Market Road',
      customerPayable: 900,
      status: 'Completed',
    ),
  ];

  testWidgets('compact bookings view keeps filters and search working', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WorkerBookingsScreen(demoMode: false, orders: orders),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage your appointments'), findsOneWidget);
    expect(find.text('Facial Service'), findsOneWidget);
    expect(find.text('Hair Styling'), findsOneWidget);
    expect(find.text('₹2,100'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Facial Service'), findsNothing);
    expect(find.text('Hair Styling'), findsOneWidget);
    expect(find.text('1 booking'), findsOneWidget);
    expect(find.text('₹900'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), 'Second Customer');
    await tester.pumpAndSettle();
    expect(find.text('Hair Styling'), findsOneWidget);
    expect(find.text('1 booking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
