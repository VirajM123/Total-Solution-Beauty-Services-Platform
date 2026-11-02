import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/features/home/all_services_screen.dart';

void main() {
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    testWidgets('compact services layout and callbacks at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      String? treatment;
      var wentBack = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AllServicesScreen(
              onBack: () => wentBack = true,
              onCategorySelected: (value) => selected = value,
              onServiceSelected: (value) => treatment = value,
              categoryNames: const [
                'Hair Care & Spa',
                'Manicure & Pedicure',
                'Beauty Packages',
              ],
              categoryStartingPrices: const {'Hair Care & Spa': 699},
              subservicesByCategory: const {
                'Hair Care & Spa': ['Deep nourishment'],
                'Manicure & Pedicure': ['Nail care'],
                'Beauty Packages': ['Glow package'],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.tap(find.byKey(const ValueKey('services-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Starting at ₹699'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('service-category-Hair Care & Spa')),
      );
      expect(selected, 'Hair Care & Spa');
      await tester.enterText(
        find.byKey(const ValueKey('services-search')),
        'Deep',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('search-service-Deep nourishment')),
      );
      expect(treatment, 'Deep nourishment');
      await tester.enterText(find.byKey(const ValueKey('services-search')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Manicure & Pedicure'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('service-category-Hair Care & Spa')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('service-category-Manicure & Pedicure')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('services-filter')));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        find.byKey(const ValueKey('service-category-Manicure & Pedicure')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Back'));
      expect(wentBack, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
