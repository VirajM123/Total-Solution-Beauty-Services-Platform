import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_service_in_progress_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('service progress matches the compact running-service layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final order = WorkerDashboardOrder(
      id: 'HB28491',
      customer: 'Sneha Patil',
      service: 'Gold Facial',
      time: '10:30 AM',
      location: '12, Mangalwar Peth, Latur, Maharashtra, 413512',
      customerPayable: 1200,
      status: 'In Progress',
      duration: '60 min',
    );

    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerServiceInProgressScreen(
            order: order,
            demoStartedAt: DateTime.now().subtract(
              const Duration(minutes: 35, seconds: 20),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Service In Progress'), findsOneWidget);
      expect(find.text('Gold Facial'), findsOneWidget);
      expect(
        find.text(width < 360 ? 'Running' : 'Service Running'),
        findsOneWidget,
      );
      expect(find.text('Facial Steps'), findsOneWidget);
      expect(find.text('Cleansing'), findsOneWidget);
      expect(find.text('Massage'), findsOneWidget);
      expect(find.text('Finish Service'), findsOneWidget);
      expect(find.text('Add Extra Service'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('add-extra-service')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('finish-service')))
            .onPressed,
        isNotNull,
      );
      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Viewport width: $width');
    }
  });
}
