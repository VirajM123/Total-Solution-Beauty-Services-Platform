import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/app/route_names.dart';
import 'package:customer_app/core/config/app_config.dart';
import 'package:customer_app/core/config/environment.dart';
import 'package:customer_app/core/constants/app_assets.dart';
import 'package:customer_app/features/login/login_screen.dart';
import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:customer_app/features/otp/development_otp_screen.dart';
import 'package:customer_app/features/register/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const config = AppConfig(Environment.development);

void main() {
  testWidgets('splash renders branding and advances to onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(const CustomerApp(config: config));
    expect(find.byKey(const ValueKey('hi-beauty-logo')), findsOneWidget);
    expect(find.text('Beauty, on your terms.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Hi Beauty'), findsOneWidget);
    expect(find.textContaining('Total Solution'), findsNothing);
  });

  testWidgets('Get Started opens login', (tester) async {
    await tester.pumpWidget(const CustomerApp(config: config));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Hi Beauty'), findsOneWidget);
    expect(find.textContaining('Total Solution'), findsNothing);
  });

  testWidgets('Skip opens login', (tester) async {
    await tester.pumpWidget(const CustomerApp(config: config));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('phone validation and mock OTP flow', (tester) async {
    await tester.pumpWidget(const CustomerApp(config: config));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12345');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.textContaining('valid 10-digit'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Verify mobile number'), findsOneWidget);
    expect(find.text('One step closer'), findsOneWidget);
    expect(find.text('VERIFICATION CODE'), findsOneWidget);
    expect(find.byKey(const ValueKey('otp-input')), findsOneWidget);
    expect(find.textContaining('Total Solution'), findsNothing);
    await tester.enterText(find.byType(TextField), '111111');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pump();
    expect(find.textContaining('Incorrect development code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Glow Beautiful\nat Home'), findsOneWidget);
    expect(find.text('Popular Services'), findsOneWidget);
    expect(find.textContaining('Total Solution'), findsNothing);
  });

  testWidgets('production cannot open development OTP route', (tester) async {
    await tester.pumpWidget(
      const CustomerApp(config: AppConfig(Environment.production)),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(RouteNames.otp, arguments: '9876543210');
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Verify mobile number'), findsNothing);
  });

  testWidgets('production cannot open development checkout preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CustomerApp(config: AppConfig(Environment.production)),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(RouteNames.home);
    await tester.pumpAndSettle();
    expect(find.byType(DevelopmentHomeScreen), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('registration validates fields and reaches distinct mock OTP', (
    tester,
  ) async {
    await tester.pumpWidget(const CustomerApp(config: config));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.textContaining('Create an account', findRichText: true),
    );
    await tester.tap(
      find.textContaining('Create an account', findRichText: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RegistrationScreen), findsOneWidget);
    expect(find.text('Hi Beauty'), findsOneWidget);
    expect(find.textContaining('Total Solution'), findsNothing);

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.textContaining('valid 10-digit'), findsOneWidget);
    expect(find.text('Please agree before continuing.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('registration-name')),
      '  Asha Patil  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-phone')),
      '1234567890',
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.textContaining('valid 10-digit'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('registration-phone')),
      '9876543210',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-consent')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-consent')));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final otp = tester.widget<DevelopmentOtpScreen>(
      find.byType(DevelopmentOtpScreen),
    );
    expect(otp.registration?.name, 'Asha Patil');
    expect(otp.phone, '9876543210');
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Glow Beautiful\nat Home'), findsOneWidget);
  });

  testWidgets('registration back controls return to login', (tester) async {
    await tester.pumpWidget(const CustomerApp(config: config));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(RouteNames.register);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    navigator.pushNamed(RouteNames.register);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Already have an account?'));
    await tester.tap(find.textContaining('Already have an account?'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('abandoning registration OTP clears unverified details', (
    tester,
  ) async {
    await tester.pumpWidget(const CustomerApp(config: config));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(RouteNames.register);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('registration-name')),
      'Asha Patil',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-phone')),
      '9876543210',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-consent')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-consent')));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(DevelopmentOtpScreen), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('registration-name')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('registration-phone')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('production registration cannot reach mock OTP', (tester) async {
    await tester.pumpWidget(
      const CustomerApp(config: AppConfig(Environment.production)),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(RouteNames.register);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('registration-name')),
      'Asha Patil',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-phone')),
      '9876543210',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-consent')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-consent')));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Registration is unavailable in this build.'),
      findsOneWidget,
    );
    expect(find.byType(DevelopmentOtpScreen), findsNothing);
    navigator.pushNamed(
      RouteNames.otp,
      arguments: const DevelopmentRegistration(
        name: 'Asha Patil',
        phone: '9876543210',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DevelopmentOtpScreen), findsNothing);
  });

  testWidgets('optional registration details validate and remain optional', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegistrationScreen(config: config)),
    );
    expect(find.text('Email Address  (Optional)'), findsOneWidget);
    expect(find.text('Gender  (Optional)'), findsOneWidget);
    expect(find.text('Date of Birth  (Optional)'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('registration-consent')),
          )
          .value,
      isFalse,
    );

    await tester.enterText(
      find.byKey(const ValueKey('registration-email')),
      'invalid-email',
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.textContaining('valid email address'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('registration-email')),
      '',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-gender')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-gender')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prefer not to say').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('registration-gender')),
          )
          .initialValue,
      'Prefer not to say',
    );

    await tester.ensureVisible(find.byKey(const ValueKey('registration-dob')));
    await tester.tap(find.byKey(const ValueKey('registration-dob')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.lastDate.isAfter(DateTime.now()), isFalse);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Select date'), findsNothing);
  });

  testWidgets('social sign in remains unavailable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen(config: config)),
    );
    for (final label in ['Continue with Google', 'Continue with Apple']) {
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, label),
      );
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('home search, category, service plan, offers, and tabs work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Popular Services'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('home-search')), 'Hair');
    await tester.pump();
    expect(find.text('Hair Spa'), findsWidgets);
    expect(find.text('Gold Facial'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('home-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-Gold Facial')));
    await tester.pump();
    await tester.tap(find.text('My Cart').last);
    await tester.pumpAndSettle();
    expect(find.text('Gold Facial'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    await tester.tap(find.text('Offers').last);
    await tester.pumpAndSettle();
    final applyOffer = find.byKey(const ValueKey('offers-apply-beauty20'));
    await tester.tap(applyOffer);
    await tester.pumpAndSettle();
    await tester.tap(applyOffer);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();
    expect(find.text('Offers & Packages'), findsOneWidget);
    expect(find.text('Facial Beauty Package'), findsOneWidget);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);
    final cartLayoutException = tester.takeException();
    if (cartLayoutException != null) {
      // ignore: avoid_print
      print(cartLayoutException);
    }
    expect(cartLayoutException, isNull);
  });

  testWidgets('offers add a discounted package and profile actions work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Offers').last);
    await tester.pumpAndSettle();
    expect(find.text('Offers & Packages'), findsOneWidget);
    expect(find.byKey(const ValueKey('offers-category-All')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('offer-service-deal-facial::gold facial')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('offers-category-Hair Care')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('offer-service-deal-hair spa::hair spa')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('offer-service-deal-facial::gold facial')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('offers-category-All')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-offers-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('offers-search')), 'Gold');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('offer-service-deal-facial::gold facial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('offer-service-deal-hair spa::hair spa')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('toggle-offers-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-package-facial')));
    await tester.pumpAndSettle();
    expect(find.text('My Cart (3)'), findsOneWidget);
    expect(find.text('BEAUTY20 applied'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-customer-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-name-input')),
      'Asha Patil',
    );
    await tester.tap(find.byKey(const ValueKey('save-profile-name')));
    await tester.pumpAndSettle();
    expect(find.text('Asha Patil'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-menu-My Bookings')));
    await tester.pumpAndSettle();
    expect(find.text('My Cart (3)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers screen remains usable on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offers').last);
    await tester.pumpAndSettle();
    expect(find.text('Offers & Packages'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('offer-service-deal-facial::gold facial')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart is compact, supports quantity and booking payment choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-Gold Facial')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Cart').last);
    await tester.pumpAndSettle();
    expect(find.text('My Cart (1)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cart-item-facial::gold facial')),
      findsOneWidget,
    );
    expect(find.text('₹1,500'), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('cart-item-facial::gold facial')))
          .width,
      lessThanOrEqualTo(360),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Increase Gold Facial quantity'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('₹2,400'), findsWidgets);
    expect(find.text('Add More Services'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-more-services')));
    await tester.pumpAndSettle();
    expect(find.text('All Services'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('My Cart (1)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('proceed-to-booking')));
    await tester.pumpAndSettle();
    expect(find.text('Select Date & Time'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    final tomorrow = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    final weekStart = tomorrow.subtract(
      Duration(days: tomorrow.weekday - DateTime.monday),
    );
    final bookingDate = weekStart.add(const Duration(days: 10));
    await tester.tap(find.byKey(const ValueKey('booking-week-next')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ValueKey(
          'booking-date-${bookingDate.year}-${bookingDate.month}-${bookingDate.day}',
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('booking-period-Afternoon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-time-1:00 PM')));
    await tester.drag(
      find.byKey(const ValueKey('checkout-step-0')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('booking-preference-Schedule Later')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('checkout-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Select Address'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('saved-address-work')));
    await tester.ensureVisible(find.byKey(const ValueKey('add-new-address')));
    await tester.tap(find.byKey(const ValueKey('add-new-address')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-new-address')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a label'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('address-label-input')),
      'Studio',
    );
    await tester.enterText(
      find.byKey(const ValueKey('address-street-input')),
      'Market Road',
    );
    await tester.enterText(
      find.byKey(const ValueKey('address-city-input')),
      'Latur, Maharashtra',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('address-postal-code-input')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('address-postal-code-input')),
      '413512',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-new-address')));
    await tester.tap(find.byKey(const ValueKey('save-new-address')));
    await tester.pumpAndSettle();
    expect(find.text('Studio'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('checkout-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Booking Summary'), findsOneWidget);
    expect(find.textContaining('1:00 PM'), findsOneWidget);
    expect(find.textContaining('Schedule Later'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('continue-to-payment-method')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('continue-to-payment-method')));
    await tester.pumpAndSettle();
    expect(find.text('Payment Method'), findsOneWidget);
    expect(find.text('UPI (Recommended)'), findsOneWidget);
    expect(find.text('Credit / Debit Card'), findsOneWidget);
    expect(find.text('Cash on Service'), findsOneWidget);
    expect(find.text('₹2,450'), findsOneWidget);
    expect(
      find.textContaining('Online payment is not connected'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('checkout-back')));
    await tester.pumpAndSettle();
    expect(find.text('Booking Summary'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('continue-to-payment-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payment-method-card')));
    await tester.pumpAndSettle();
    expect(find.text('Pay Securely · Preview'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payment-method-upi')));
    await tester.pumpAndSettle();
    expect(find.text('UPI (Recommended)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-booking')));
    await tester.tap(find.byKey(const ValueKey('confirm-booking')));
    await tester.pumpAndSettle();
    expect(find.text('Booking Confirmation'), findsOneWidget);
    expect(find.text('Sample booking · Development preview'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Not issued in preview'), findsOneWidget);
    expect(find.text('₹2,450'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('Paid'), findsNothing);
    expect(find.byKey(const ValueKey('confirm-booking')), findsNothing);
    expect(find.text('Finding your professional next…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Finding Professional'), findsOneWidget);
    expect(find.text('Finding the Best Professional for You'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('continue-to-professional-assigned')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Professional Assigned'), findsWidgets);
    expect(find.text('Priya Shinde'), findsOneWidget);
    expect(find.text('Booking Timeline'), findsOneWidget);
    expect(find.text('On the Way'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('professional-call')));
    await tester.pumpAndSettle();
    expect(
      find.text('Calling is unavailable in this development preview.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('professional-chat')));
    await tester.pumpAndSettle();
    expect(
      find.text('Messaging is unavailable in this development preview.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('professional-assignment-back')),
    );
    await tester.pump();
    expect(find.text('Finding Professional'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Professional Assigned'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('track-professional')));
    await tester.pumpAndSettle();
    expect(find.text('Professional On The Way'), findsOneWidget);
    expect(find.text('En route'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('verify-service-otp-open')));
    await tester.pumpAndSettle();
    expect(find.text('DEMO SERVICE OTP'), findsOneWidget);
    final serviceOtp = tester
        .widget<Text>(find.byKey(const ValueKey('demo-service-otp')))
        .data!;
    await tester.enterText(
      find.byKey(const ValueKey('service-start-otp')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey('verify-service-otp')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 4-digit code shown above.'), findsOneWidget);
    expect(find.text('Verify OTP to Start Service'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('service-start-otp')),
      serviceOtp,
    );
    await tester.tap(find.byKey(const ValueKey('verify-service-otp')));
    await tester.pump();
    expect(find.text('Service In Progress'), findsWidgets);
    expect(find.text('00:00:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('00:00:03'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('complete-service')));
    await tester.pumpAndSettle();
    expect(find.text('Service Completed!'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    final stoppedElapsed = tester
        .widget<Text>(find.byKey(const ValueKey('service-elapsed-time')))
        .data;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('service-elapsed-time')))
          .data,
      stoppedElapsed,
    );
    await tester.tap(find.byKey(const ValueKey('continue-to-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('view-service-bill')));
    await tester.pumpAndSettle();
    expect(find.text('Service Bill · Preview'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rate-service')));
    await tester.pumpAndSettle();
    expect(find.text('Rate Your Experience'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('experience-rating-5')));
    await tester.enterText(
      find.byKey(const ValueKey('experience-review-text')),
      'Excellent service',
    );
    await tester.tap(find.byKey(const ValueKey('submit-experience-review')));
    await tester.pumpAndSettle();
    expect(find.text('My Bookings'), findsOneWidget);
    expect(find.textContaining('Gold Facial'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('booking-history-filter-Upcoming')),
    );
    await tester.pumpAndSettle();
    expect(find.text('No upcoming bookings'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('booking-history-filter-Completed')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-view-details')));
    await tester.pumpAndSettle();
    expect(find.text('Excellent service'), findsNothing);
    expect(find.textContaining('5 stars · Submitted'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-again')));
    await tester.pumpAndSettle();
    expect(find.text('All Services'), findsOneWidget);
    expect(find.text('My Cart (1)'), findsNothing);
    expect(find.text('Gold Facial'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cash after service remains pending in development preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-Gold Facial')));
    await tester.pumpAndSettle();
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
    await tester.tap(
      find.byKey(const ValueKey('payment-method-cashOnService')),
    );
    await tester.tap(find.byKey(const ValueKey('confirm-booking')));
    await tester.pumpAndSettle();
    expect(find.text('Sample booking · Development preview'), findsOneWidget);
    expect(find.text('Cash on Service'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Paid'), findsNothing);
    expect(find.text('₹1,250'), findsOneWidget);
    expect(
      find.text('No real booking was created. No payment was collected.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(360, 800),
    Size(393, 852),
    Size(400, 686),
    Size(412, 915),
  ]) {
    testWidgets('checkout payment fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-Gold Facial')));
      await tester.tap(find.byKey(const ValueKey('add-Hair Spa')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Cart').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('My Cart (2)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('proceed-to-booking')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Gold Facial'), findsOneWidget);
      expect(find.text('Hair Spa'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('continue-to-payment-method')),
      );
      await tester.pumpAndSettle();
      expect(find.text('₹2,149'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('payment-method-upi')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('confirm-booking')));
      await tester.pumpAndSettle();
      expect(find.text('Sample booking · Development preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home location, filters, hero, and professional controls work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latur, Maharashtra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pune, Maharashtra'));
    await tester.pumpAndSettle();
    expect(find.text('Pune, Maharashtra'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter services'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hair Spa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show services'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.text('Gold Facial'), findsNothing);
    expect(find.text('Hair Spa'), findsWidgets);
    await tester.tap(find.text('Hair Spa').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-to-cart')), findsOneWidget);
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
    expect(find.text('My Cart'), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Hair Spa'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Hair Spa'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('home-scroll')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('You are all caught up!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home hero, categories, offers, and professionals open details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book Now'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-to-cart')), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-Facial')));
    await tester.pumpAndSettle();
    expect(find.text('Gold Facial'), findsOneWidget);
    expect(
      find.text('Hair Spa'),
      findsOneWidget,
    ); // Category label remains visible.
    await tester.tap(find.text('View All').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('All Services'), findsOneWidget);
    expect(find.text('Hair Care & Spa'), findsOneWidget);
    expect(find.text('Beauty Packages'), findsOneWidget);
    await tester.tap(find.text('Threading').first);
    await tester.pumpAndSettle();
    expect(find.text('Eyebrow Threading'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('back-to-service-categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beauty Packages').first);
    await tester.pumpAndSettle();
    expect(find.text('Glow Package'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('back-to-service-categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bridal Services').first);
    await tester.pumpAndSettle();
    expect(find.text('Bridal Package'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('back-to-service-categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facial').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('category-services')), findsOneWidget);
    expect(find.text('Popular Services'), findsNothing);
    await tester.tap(find.text('Gold Facial').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-to-cart')), findsOneWidget);
    expect(find.text('Key Benefits'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('service-option-Normal Facial')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('service-option-Normal Facial')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('service-details-title')))
          .data,
      'Normal Facial',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('service-option-Gold Facial')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('service-option-Gold Facial')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next service'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('service-details-title')))
          .data,
      'Gold Prime Facial',
    );
    await tester.tap(find.byTooltip('Previous service'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('service-details-title')))
          .data,
      'Gold Facial',
    );
    await tester.tap(find.byKey(const ValueKey('add-to-cart')));
    await tester.pumpAndSettle();
    expect(find.text('Gold Facial added to your cart.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('My Cart'), findsWidgets);
    expect(find.text('Gold Facial'), findsOneWidget);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Save professional'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save professional'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('1 saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home displays all featured choices on a 360px phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    for (final category in [
      'Facial',
      'Hair Spa',
      'Makeup',
      'Waxing',
      'Manicure',
      'All Services',
    ]) {
      expect(find.byKey(ValueKey('category-$category')), findsOneWidget);
    }
    for (final service in [
      'Gold Facial',
      'Hair Spa',
      'Bridal Makeup',
      'Manicure',
      'Waxing',
    ]) {
      final add = find.byKey(ValueKey('add-$service'));
      expect(add, findsOneWidget);
      expect(
        tester.getTopLeft(add).dy,
        tester.getTopLeft(find.byKey(const ValueKey('add-Gold Facial'))).dy,
      );
    }
    final waxingAdd = find.byKey(const ValueKey('add-Waxing'));
    expect(tester.getRect(waxingAdd).right, greaterThan(360));
    await tester.ensureVisible(waxingAdd);
    expect(tester.getRect(waxingAdd).right, lessThan(360));
    expect(find.text('Offers for You'), findsOneWidget);
    expect(find.text('Top Rated Professionals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('priority service categories use their images and add to cart', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All').first);
    await tester.pumpAndSettle();

    const priorityCategories = <(String, String, String)>[
      ('Body Polish', 'Full Body Polish', AppAssets.bodyPolishMain),
      ('Clean Up', 'Fruit Clean Up', AppAssets.cleanUpMain),
      ('Hair Color', 'Global Hair Color', AppAssets.hairColorMain),
      ('Hair Mehendi', 'Full Hair Mehendi', AppAssets.hairMehendiMain),
      ('Hair Cut', 'Women’s Haircut', AppAssets.hairCutMain),
    ];

    for (final (category, firstService, mainImage) in priorityCategories) {
      final categoryCard = find.byKey(ValueKey('service-category-$category'));
      await tester.scrollUntilVisible(categoryCard, 250);
      await tester.tap(categoryCard);
      await tester.pumpAndSettle();
      expect(find.text(firstService), findsOneWidget);
      final hero = tester.widget<Image>(
        find.byKey(ValueKey('category-hero-$category')),
      );
      expect(
        ((hero.image as ResizeImage).imageProvider as AssetImage).assetName,
        mainImage,
      );
      expect(find.text('Photo coming soon'), findsNothing);
      final servicePhoto = find.byKey(
        ValueKey(
          'category-service-image-${category.toLowerCase()}::${firstService.toLowerCase()}',
        ),
      );
      expect(servicePhoto, findsOneWidget);
      expect(
        find.descendant(of: servicePhoto, matching: find.byType(Image)),
        findsOneWidget,
      );

      if (category == 'Hair Cut') {
        final addButton = find.byKey(ValueKey('add-to-cart-$firstService'));
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pumpAndSettle();
        expect(find.text('My Cart'), findsWidgets);
        expect(find.text(firstService), findsOneWidget);
      } else {
        await tester.tap(
          find.byKey(const ValueKey('back-to-service-categories')),
        );
        await tester.pumpAndSettle();
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('all thirteen catalog categories show their configured counts', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('services-search'));
    const counts = <String, int>{
      'Facial': 3,
      'Hair Care & Spa': 1,
      'Makeup': 3,
      'Waxing': 4,
      'Manicure & Pedicure': 4,
      'Threading': 4,
      'Bridal Services': 4,
      'Beauty Packages': 4,
      'Body Polish': 4,
      'Clean Up': 4,
      'Hair Color': 5,
      'Hair Mehendi': 3,
      'Hair Cut': 5,
    };
    for (final entry in counts.entries) {
      await tester.enterText(search, entry.key);
      await tester.pumpAndSettle();
      final card = find.byKey(ValueKey('service-category-${entry.key}'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.text(
            '${entry.value} ${entry.value == 1 ? 'service' : 'services'}',
          ),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog search finds services and opens the selected record', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('services-search'));
    await tester.enterText(search, 'ROOT TOUCH');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('search-service-Root Touch-Up')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('search-service-Root Touch-Up')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('service-details-title')))
          .data,
      'Root Touch-Up',
    );
    expect(find.text('Photo coming soon'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('close-service-details')));
    await tester.pumpAndSettle();
    await tester.enterText(search, 'no-such-treatment');
    await tester.pumpAndSettle();
    expect(find.text('No services found. Try another search.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('service-category-Facial')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('facial carousel stays in its category at both ends', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('service-category-Facial')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('subservice-Gold Facial')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Previous service'), findsNothing);
    await tester.tap(find.byTooltip('Next service'));
    await tester.tap(find.byTooltip('Next service'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('service-details-title')))
          .data,
      'Normal Facial',
    );
    expect(find.byTooltip('Next service'), findsNothing);
    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.text('45 mins'), findsOneWidget);
    expect(find.text('₹699'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(360, 800),
    Size(393, 852),
    Size(400, 686),
    Size(412, 915),
  ]) {
    testWidgets('all services long labels fit ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const MaterialApp(home: DevelopmentHomeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View All').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      for (final label in [
        'Hair Care & Spa',
        'Manicure & Pedicure',
        'Beauty Packages',
      ]) {
        await tester.enterText(
          find.byKey(const ValueKey('services-search')),
          label,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('service-category-$label')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('registration remains scrollable with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      const MaterialApp(home: RegistrationScreen(config: config)),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-consent')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(360, 800),
    Size(393, 852),
    Size(400, 686),
    Size(412, 915),
  ]) {
    testWidgets('registration fits ${size.width}x${size.height} and keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });
      await tester.pumpWidget(
        const MaterialApp(home: RegistrationScreen(config: config)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'before keyboard');
      await tester.showKeyboard(
        find.byKey(const ValueKey('registration-phone')),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.view.viewInsets.bottom, 250);
      expect(
        tester.getBottomLeft(find.text('Continue')).dy,
        lessThan(size.height - tester.view.viewInsets.bottom),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('intro artwork assets decode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Image.asset(AppAssets.splashPortrait, height: 100),
              Image.asset(AppAssets.onboardingPortrait, height: 100),
              Image.asset(AppAssets.splashScene, height: 100),
              Image.asset(AppAssets.onboardingScene, height: 100),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(360, 800), Size(393, 852), Size(412, 915)]) {
    testWidgets('login background fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen(config: config)),
      );
      await tester.pumpAndSettle();

      final background = tester.widget<Image>(
        find.byKey(const ValueKey('customer-login-background')),
      );
      expect(background.fit, BoxFit.cover);
      expect(tester.getSize(find.byType(TextField)).width, greaterThan(0));
      expect(
        tester.getSize(find.byKey(const ValueKey('customer-login-background'))),
        size,
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('login scrolls when the keyboard reduces available height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen(config: config)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.showKeyboard(find.byType(TextField));
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.text('Continue')).dy, lessThan(852 - 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact phone layout remains usable', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const CustomerApp(config: config));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(360, 800),
    Size(393, 852),
    Size(400, 686),
    Size(412, 915),
  ]) {
    testWidgets('intro screens fit ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const CustomerApp(config: config));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.text('Get Started')).dy,
        lessThan(size.height),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.text('Continue')).dy,
        lessThan(size.height),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
