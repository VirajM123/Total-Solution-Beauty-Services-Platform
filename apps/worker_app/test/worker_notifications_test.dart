import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_notifications_screen.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';

void main() {
  testWidgets('shows derived preview alerts and filters unread items', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: WorkerNotificationsScreen(orders: previewWorkerOrders)),
    );
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Service completed'), findsOneWidget);
    expect(find.text('3 unread'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    expect(find.text('0 unread'), findsOneWidget);
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications here'), findsOneWidget);
  });

  testWidgets('handles empty booking data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: WorkerNotificationsScreen(orders: [])),
    );
    expect(find.text('No notifications here'), findsOneWidget);
  });

  testWidgets('notification layout fits supported phone widths', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerNotificationsScreen(
            orders: previewWorkerOrders,
            demoMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('3 unread'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
