import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_extra_service_item.dart';
import 'package:worker_app/features/home/worker_finish_service_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('finish review matches the compact customer bill layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [320.0, 390.0]) {
      final order = WorkerDashboardOrder(
        id: 'finish-layout-${width.toInt()}',
        customer: 'Sneha Patil',
        service: 'Gold Facial',
        time: '10:30 AM',
        location: 'Mangalwar Peth, Latur',
        customerPayable: 1200,
        status: 'In Progress',
        duration: '60 min',
        customerPhone: '+91 98765 43210',
        customerNote: 'Use gentle products. I have sensitive skin.',
        paymentMethod: 'cash',
      );
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerFinishServiceScreen(
            key: ValueKey(width),
            order: order,
            extraServices: const [
              WorkerExtraServiceItem(
                id: 'head-massage',
                name: 'Head Massage',
                customerPrice: 400,
                durationMinutes: 15,
              ),
            ],
            demoStartedAt: DateTime.now().subtract(const Duration(minutes: 75)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Finish Service'), findsOneWidget);
      expect(find.text('Services provided'), findsOneWidget);
      expect(find.text('Gold Facial'), findsOneWidget);
      expect(find.text('Head Massage'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Customer notes'), 300);
      expect(find.text('Customer notes'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Payment method'), 300);
      expect(find.text('Payment method'), findsOneWidget);
      expect(find.text('Cash on Service'), findsOneWidget);
      expect(find.text('₹1,600'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('finish-service-continue')),
            )
            .onPressed,
        isNull,
      );

      expect(
        find.byKey(const Key('finish-review-confirmation')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('finish-review-confirmation')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('finish-service-continue')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
