import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:customer_app/features/home/all_services_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'customer_fixture_api.dart';

/// The production home requires backend data. Never rely on implicit demo records.
void registerCustomerCatalogContractCases() {
  for (final category in CustomerFixtureApi.catalog.entries) {
    testWidgets(
      'backend category ${category.key} exposes configured services',
      (tester) async {
        final api = CustomerFixtureApi();
        addTearDown(api.close);
        await tester.pumpWidget(
          MaterialApp(home: DevelopmentHomeScreen(operationsApi: api)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('View All').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Search'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('services-search')),
          category.key,
        );
        await tester.pumpAndSettle();
        final card = find.byKey(ValueKey('service-category-${category.key}'));
        expect(card, findsOneWidget);
        expect(
          tester
              .widget<AllServicesScreen>(find.byType(AllServicesScreen))
              .subservicesByCategory[category.key]
              ?.length,
          category.value.length,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.text(category.value.first), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('backend search adds authoritative service to cart', (
    tester,
  ) async {
    final api = CustomerFixtureApi();
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(home: DevelopmentHomeScreen(operationsApi: api)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('home-search')),
      'Gold Facial',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-Gold Facial')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-Hair Spa')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-Gold Facial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Cart').last);
    await tester.pumpAndSettle();
    expect(find.text('Gold Facial'), findsWidgets);
    expect(find.textContaining('Subtotal ('), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
