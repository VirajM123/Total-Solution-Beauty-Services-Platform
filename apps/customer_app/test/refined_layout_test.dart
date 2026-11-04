import 'package:customer_app/features/booking/assigned_professional_details.dart';
import 'package:customer_app/features/booking/compact_booking_widgets.dart';
import 'package:customer_app/features/booking/service_start_code.dart';
import 'package:customer_app/features/shared/compact_customer_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/load_customer_fonts.dart';

void main() {
  setUpAll(() async {
    await loadCustomerFonts();
  });
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('booking components fit long content and enlarged text at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: CompactCustomerSurface(
              child: CompactBookingFrame(
                title: 'Professional Assigned',
                contentKey: 'large-content',
                onBack: () {},
                body: Column(
                  children: [
                    const ServiceStartCode(code: '123456'),
                    const SizedBox(height: 12),
                    const AssignedProfessionalDetails(
                      name: 'A professional with a longer full name',
                      worker: {
                        'specialization': 'Facial treatments and bridal makeup',
                      },
                      compact: true,
                    ),
                    const SizedBox(height: 12),
                    const CompactBookingPanel(
                      child: Column(
                        children: [
                          CompactBookingService(
                            name:
                                'Gold facial treatment with extended skin care',
                            amount: '₹12,000',
                            subtitle: 'Quantity: 1',
                          ),
                          CompactBookingFact(
                            icon: Icons.location_on_outlined,
                            text:
                                'Home, Apartment 301, a longer street address in Latur, Maharashtra 413512',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                action: FilledButton(
                  onPressed: () {},
                  child: const Text('Back to Tracking'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Service start code 123456',
        ),
        findsOneWidget,
      );
      final action = find.widgetWithText(FilledButton, 'Back to Tracking');
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(tester.getRect(action).bottom, lessThanOrEqualTo(640));
    });
  }
}
