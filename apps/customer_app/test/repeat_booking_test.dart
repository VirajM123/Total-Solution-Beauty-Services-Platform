import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> confirmGoldFacial(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-Gold Facial')));
    await tester.tap(find.text('My Cart').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('proceed-to-booking')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('checkout-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('checkout-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continue-to-payment-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-booking')));
    await tester.pumpAndSettle();
  }

  testWidgets('a second booking starts with only the newly selected service', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await confirmGoldFacial(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('booking-back-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-back-home')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-Hair Spa')));
    await tester.tap(find.text('My Cart').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cart-item-hair spa::hair spa')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cart-item-facial::gold facial')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('proceed-to-booking')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a completed service can be followed by a new cart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await confirmGoldFacial(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('track-professional')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('verify-service-otp-open')));
    await tester.pumpAndSettle();
    final serviceOtp = tester
        .widget<Text>(find.byKey(const ValueKey('demo-service-otp')))
        .data!;
    await tester.enterText(
      find.byKey(const ValueKey('service-start-otp')),
      serviceOtp,
    );
    await tester.tap(find.byKey(const ValueKey('verify-service-otp')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('complete-service')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rate-service')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('experience-rating-5')));
    await tester.tap(find.byKey(const ValueKey('submit-experience-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to home'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-Hair Spa')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cart-item-hair spa::hair spa')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cart-item-facial::gold facial')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('proceed-to-booking')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
