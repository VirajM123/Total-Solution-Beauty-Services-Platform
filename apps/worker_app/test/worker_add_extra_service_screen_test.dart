import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_add_extra_service_screen.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('extra-service catalog supports search, filters, and selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const order = WorkerDashboardOrder(
      id: 'preview-extra-service',
      customer: 'Sneha Patil',
      service: 'Gold Facial',
      time: '10:30 AM',
      location: 'Mangalwar Peth, Latur',
      customerPayable: 1200,
      status: 'In Progress',
    );

    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerAddExtraServiceScreen(
            key: ValueKey(width),
            order: order,
            demoMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Extra Service'), findsOneWidget);
      expect(
        find.text('Enhance your client’s beauty experience'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('extra-service-search')), findsOneWidget);
      expect(
        find.byKey(const Key('extra-service-category-Hair')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('extra-service-grid')), findsOneWidget);
      expect(find.text('Extra total'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('extra-service-search')),
        'Hair Spa',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('extra-service-hair-spa')), findsOneWidget);
      expect(find.byKey(const Key('extra-service-manicure')), findsNothing);
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('extra-service-hair-spa')))
            .onTap,
        isNotNull,
      );

      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('extra-service-hair-spa')),
      );
      await tester.tap(find.text('Hair Spa').last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('extra-service-total'))).data,
        '₹800',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('submit-extra-services')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
