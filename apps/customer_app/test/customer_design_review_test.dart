import 'support/load_customer_fonts.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:customer_app/core/config/app_config.dart';
import 'package:customer_app/core/config/environment.dart';
import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:customer_app/features/login/login_screen.dart';
import 'package:customer_app/features/splash/splash_screen.dart';
import 'package:customer_app/features/onboarding/onboarding_screen.dart';
import 'package:customer_app/features/register/registration_screen.dart';
import 'package:customer_app/features/otp/development_otp_screen.dart';
import 'package:customer_app/core/api/mobile_api.dart';
import 'package:customer_app/integration/customer_auth_api.dart';
import 'package:customer_app/features/shared/customer_visuals.dart';
import 'package:customer_app/integration/customer_mobile_operations_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_system/design_system.dart';

// Test records only: production still gets all of these values from its API.
class _DesignApi extends CustomerMobileOperationsApi {
  @override
  Future<Map<String, dynamic>> getNotificationPreferences() async => {};
  @override
  Future<List<Map<String, dynamic>>> getCatalogServices() async => [
    {
      'id': '123456789012345678901234',
      'name': 'Gold Facial',
      'category': {'name': 'Skin Care'},
      'pricePaise': 120000,
      'durationMinutes': 60,
      'description': 'A treatment supplied by the catalog.',
      'benefits': ['Gentle skin care'],
      'thumbnail': 'assets/images/home/gold_facial.png',
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> getAddresses() async => [
    {
      '_id': 'address-1',
      'label': 'Home',
      'line1': '12 Rose Lane',
      'city': 'Latur',
      'postalCode': '413512',
      'serviceAreaId': 'area-1',
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> getBookings() async => [];
  @override
  Future<Map<String, dynamic>> getProfile() async => {
    'user': {'fullName': 'Sneha Patil', 'mobileNumber': '+91 9876543210'},
  };
  @override
  Future<List<Map<String, dynamic>>> getRecords(String path) async {
    if (path.endsWith('/categories')) {
      return [
        {'id': 'skin', 'name': 'Skin Care'},
      ];
    }
    if (path.endsWith('/offers')) {
      return [
        {
          '_id': 'offer-1',
          'name': 'API Offer',
          'code': 'API20',
          'discountType': 'percentage',
          'value': 20,
          'description': 'Offer details supplied by the API.',
          'terms': 'API eligibility terms.',
        },
      ];
    }
    if (path.endsWith('/notifications')) {
      return [
        {
          'title': 'Appointment update',
          'message': 'Your booking status has changed.',
        },
      ];
    }
    return [];
  }
}

class _LifecycleApi extends _DesignApi {
  @override
  Future<List<Map<String, dynamic>>> getCatalogServices() async => [
    ...await super.getCatalogServices(),
    {
      'id': '123456789012345678901235',
      'name': 'Manicure',
      'category': {'name': 'Skin Care'},
      'pricePaise': 50000,
      'durationMinutes': 45,
      'thumbnail': 'assets/images/home/manicure.png',
    },
  ];
  String status = 'assigned';
  bool finished = false;
  Map<String, dynamic> get booking => {
    '_id': '123456789012345678901239',
    'status': status,
    'assignmentStatus': 'accepted',
    'startsAt': '2026-11-03T04:30:00Z',
    'worker': {'fullName': 'Priya Sharma'},
    'addressSnapshot': {
      'label': 'Home',
      'line1': 'Account address',
      'city': 'Latur',
    },
    'items': [
      {'name': 'Gold Facial', 'pricePaise': 120000, 'quantity': 1},
      {'name': 'Manicure', 'pricePaise': 50000, 'quantity': 1},
    ],
    'subtotalPaise': 170000,
    'totalPaise': 170000,
    'discountPaise': 0,
    'paymentStatus': status == 'completed' ? 'paid' : 'pending',
    if (finished) 'serviceFinishedAt': '2026-11-04T05:30:00Z',
    'pendingExtraServices': status == 'in_progress' && !finished
        ? [
            {'_id': 'extra-1', 'name': 'Head Massage', 'amountPaise': 30000},
          ]
        : [],
  };
  @override
  Future<List<Map<String, dynamic>>> getBookings() async => [booking];
  @override
  Future<Map<String, dynamic>> getBooking(String id) async => booking;
  @override
  Future<String> revealServiceOtp(String bookingId) async => '483261';
  int? submittedRating;
  @override
  Future<void> submitReview(
    String bookingId,
    int rating,
    String comment,
  ) async {
    submittedRating = rating;
  }
}

void main() {
  for (final variant in const [
    (Size(320, 680), 1.0),
    (Size(360, 800), 1.0),
    (Size(393, 852), 1.0),
    (Size(412, 915), 1.0),
    (Size(430, 932), 1.0),
    (Size(320, 680), 1.4),
  ]) {
    final size = variant.$1;
    final scale = variant.$2;
    testWidgets('customer design keeps API actions usable at $size text $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadCustomerFonts();
      final api = _DesignApi();
      addTearDown(api.close);
      final boundaryKey = GlobalKey();
      final font = FontLoader('Montserrat')
        ..addFont(rootBundle.load('assets/fonts/Montserrat-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Montserrat-SemiBold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Montserrat-Bold.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final brands = FontLoader('packages/font_awesome_flutter/FontAwesomeBrands')
        ..addFont(
          rootBundle.load(
            'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
          ),
        );
      await brands.load();
      Widget shell(Widget child) => RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: CustomerVisuals.theme(
            BeautyTheme.data.copyWith(
              textTheme: BeautyTheme.data.textTheme.apply(
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        ),
      );
      Future<void> capture(String name) async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (!const bool.fromEnvironment('CAPTURE_CUSTOMER_DESIGN')) return;
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final picture = await boundary.toImage(pixelRatio: 2);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          picture.dispose();
          final directory = Directory(
            '../../../output/customer-app-design-review',
          )..createSync(recursive: true);
          File(
            '${directory.path}/${size.width.toInt()}-${scale == 1 ? '' : 'large-text-'}$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      await tester.pumpWidget(shell(const SplashScreen()));
      await tester.pump();
      await capture('splash');
      await tester.pumpWidget(shell(const OnboardingScreen()));
      await tester.pumpAndSettle();
      await capture('onboarding');
      await tester.pumpWidget(
        shell(
          const RegistrationScreen(config: AppConfig(Environment.development)),
        ),
      );
      await tester.pumpAndSettle();
      await capture('registration');
      final authTransport = MobileApi(baseUrl: 'https://example.test');
      addTearDown(authTransport.close);
      await tester.pumpWidget(
        shell(
          CustomerOtpScreen(
            args: const CustomerOtpRouteArgs(
              phone: '9876543210',
              challengeId: 'test-challenge',
            ),
            auth: CustomerAuthApi(api: authTransport),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture('verify-otp');

      await tester.pumpWidget(
        shell(const LoginScreen(config: AppConfig(Environment.development))),
      );
      await tester.pumpAndSettle();
      await capture('login');
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a valid 10-digit Indian mobile number.'),
        findsOneWidget,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await capture('login-keyboard');
      tester.view.resetViewInsets();
      // Home/Services are deliberately unchanged; large-text coverage here is
      // for the refined authentication views. Booking components are tested separately.
      if (scale > 1) {
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }

      await tester.pumpWidget(shell(DevelopmentHomeScreen(operationsApi: api)));
      await tester.pumpAndSettle();
      await capture('home');
      await tester.tap(find.byKey(const ValueKey('category-All Services')));
      await tester.pumpAndSettle();
      await capture('all-services');
      await tester.tap(
        find.byKey(const ValueKey('service-category-Skin Care')),
      );
      await tester.pumpAndSettle();
      await capture('category');
      await tester.tap(find.byKey(const ValueKey('subservice-Gold Facial')));
      await tester.pumpAndSettle();
      await capture('service-details');
      await tester.tap(find.byKey(const ValueKey('close-service-details')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('back-to-service-categories')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('add-Gold Facial')));
      await tester.tap(find.byKey(const ValueKey('add-Gold Facial')));
      await tester.tap(find.text('My Cart').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await capture('cart');
      await tester.tap(find.byKey(const ValueKey('proceed-to-booking')));
      await tester.pumpAndSettle();
      await capture('date-time');
      await tester.tap(find.byKey(const ValueKey('checkout-continue')));
      await tester.pumpAndSettle();
      await capture('address');
      await tester.tap(find.byKey(const ValueKey('checkout-continue')));
      await tester.pumpAndSettle();
      await capture('summary');
      // Reopen the shell to inspect account views without changing checkout state rules.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(shell(DevelopmentHomeScreen(operationsApi: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Offers').last);
      await tester.pumpAndSettle();
      await capture('offers');
      expect(find.text('API Offer'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('offer-promotion-details-API20')),
      );
      await tester.tap(
        find.byKey(const ValueKey('offer-promotion-details-API20')),
      );
      await tester.pumpAndSettle();
      await capture('offer-details');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('Sneha Patil'), findsOneWidget);
      expect(find.text('+91 9876543210'), findsOneWidget);
      await capture('profile');
      await tester.tap(find.byKey(const ValueKey('edit-customer-profile')));
      await tester.pumpAndSettle();
      await capture('edit-profile');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-menu-Settings')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('profile-settings-screen')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-menu-Settings')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-menu-Settings')));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNWidgets(2));
      await capture('settings');
      await tester.pumpWidget(const SizedBox.shrink());
      final lifecycleApi = _LifecycleApi();
      addTearDown(lifecycleApi.close);
      await tester.pumpWidget(
        shell(DevelopmentHomeScreen(operationsApi: lifecycleApi)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Cart').last);
      await tester.pumpAndSettle();
      expect(find.text('Priya Sharma'), findsOneWidget);
      await capture('expert-assigned');
      lifecycleApi.status = 'travelling';
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await capture('tracking');
      lifecycleApi.status = 'arrived';
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Service start code 483261',
        ),
        findsOneWidget,
      );
      await capture('service-start-code');
      lifecycleApi.status = 'in_progress';
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await capture('service-progress');
      await tester.ensureVisible(find.text('Extra service approval'));
      await tester.pumpAndSettle();
      await capture('extra-service-approval');
      lifecycleApi.finished = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.textContaining('Scan the Razorpay QR shown by your worker'),
      );
      await tester.pumpAndSettle();
      await capture('pay-worker-qr');
      lifecycleApi.status = 'completed';
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await capture('service-completed');
      await tester.tap(find.text('Rate Your Experience'));
      await tester.pumpAndSettle();
      await capture('review');
      await tester.tap(find.byKey(const ValueKey('experience-rating-5')));
      await tester.tap(find.text('Submit Review'));
      await tester.pumpAndSettle();
      expect(lifecycleApi.submittedRating, 5);
      expect(
        find.byKey(const ValueKey('booking-history-list')),
        findsOneWidget,
      );
      await capture('booking-history');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
