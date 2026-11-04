import 'support/customer_fixture_api.dart';
import 'support/customer_catalog_contract_cases.dart';
import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/app/route_names.dart';
import 'package:customer_app/core/config/app_config.dart';
import 'package:customer_app/core/config/environment.dart';
import 'package:customer_app/core/constants/app_assets.dart';
import 'package:customer_app/core/api/mobile_api.dart';
import 'package:customer_app/integration/customer_auth_api.dart';
import 'package:customer_app/integration/customer_mobile_operations_api.dart';
import 'package:customer_app/features/login/login_screen.dart';
import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:customer_app/features/otp/development_otp_screen.dart';
import 'package:customer_app/features/register/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

const config = AppConfig(Environment.development);

class _MemoryCustomerTokenStorage implements CustomerTokenStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> delete() async => token = null;
}

CustomerAuthApi _testAuth({
  bool registrationRequired = false,
  bool unregisteredOnLogin = false,
}) {
  return CustomerAuthApi(
    api: MobileApi(
      baseUrl: 'https://example.test/api',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/otp/request')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (unregisteredOnLogin && body['flow'] == 'login') {
            return http.Response(
              '{"success":true,"data":{"registrationRequired":true,"appType":"customer","mobileNumber":"+919876543210"}}',
              200,
            );
          }
          return http.Response(
            '{"success":true,"data":{"challengeId":"aaaaaaaaaaaaaaaaaaaaaaaa","expiresInSeconds":300,"resendAfterSeconds":30}}',
            201,
          );
        }
        if (path.endsWith('/otp/verify')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['fullName'], isNotNull);
          if (body['code'] == '111111') {
            return http.Response(
              '{"success":false,"error":{"code":"INVALID_OTP","message":"Verification code is invalid or expired."}}',
              401,
            );
          }
          if (registrationRequired) {
            return http.Response(
              '{"success":true,"data":{"registrationRequired":true,"registrationToken":"${'r' * 43}","appType":"customer"}}',
              200,
            );
          }
          return http.Response(
            '{"success":true,"data":{"accessToken":"${'a' * 43}","appType":"customer","user":{"id":"customer-id","fullName":"Asha Patil","mobileNumber":"+919876543210"}}}',
            200,
          );
        }
        if (path.endsWith('/register/customer')) {
          return http.Response(
            '{"success":true,"data":{"accessToken":"${'a' * 43}","appType":"customer","user":{"id":"customer-id","fullName":"Asha Patil","mobileNumber":"+919876543210"}}}',
            201,
          );
        }
        return http.Response('{"success":true,"data":{"loggedOut":true}}', 200);
      }),
    ),
    tokenStorage: _MemoryCustomerTokenStorage(),
  );
}

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
    expect(find.byKey(const ValueKey('hi-beauty-logo')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('hi-beauty-logo')), findsOneWidget);
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

  testWidgets('phone validation and backend OTP login flow', (tester) async {
    await tester.pumpWidget(
      CustomerApp(
        config: config,
        operationsApi: CustomerFixtureApi(),
        auth: _testAuth(),
      ),
    );
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
    await tester.pumpAndSettle();
    expect(find.text('Verify mobile number'), findsOneWidget);
    expect(find.text('One step closer'), findsOneWidget);
    expect(find.text('VERIFICATION CODE'), findsOneWidget);
    expect(find.byKey(const ValueKey('otp-input')), findsOneWidget);
    expect(find.textContaining('Total Solution'), findsNothing);
    await tester.enterText(find.byType(TextField), '111111');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pump();
    expect(find.textContaining('invalid or expired'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '654321');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(DevelopmentHomeScreen), findsOneWidget);
    expect(find.text('Popular Services'), findsOneWidget);
    expect(find.textContaining('Total Solution'), findsNothing);
  });

  testWidgets(
    'unregistered customer goes to registration without sending login OTP',
    (tester) async {
      await tester.pumpWidget(
        CustomerApp(config: config, auth: _testAuth(unregisteredOnLogin: true)),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationScreen), findsOneWidget);
      expect(find.text('Verify mobile number'), findsNothing);
    },
  );

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

  testWidgets(
    'production home exposes booking UI without mock authentication',
    (tester) async {
      final operations = CustomerMobileOperationsApi(
        apiBaseUrl: 'https://example.test/api',
        tokenStorage: _MemoryCustomerTokenStorage(),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [],
                'user': {'fullName': 'Customer'},
                'pagination': {'pages': 1},
              },
            }),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        CustomerApp(
          config: const AppConfig(Environment.production),
          operationsApi: operations,
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(RouteNames.home);
      await tester.pumpAndSettle();
      expect(find.byType(DevelopmentHomeScreen), findsOneWidget);
      expect(const AppConfig(Environment.production).mockAuthEnabled, isFalse);
      expect(find.byKey(const ValueKey('confirm-booking')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      operations.close();
    },
  );

  testWidgets('registration validates fields and reaches backend OTP', (
    tester,
  ) async {
    await tester.pumpWidget(
      CustomerApp(
        config: config,
        operationsApi: CustomerFixtureApi(),
        auth: _testAuth(registrationRequired: true),
      ),
    );
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
    expect(find.byKey(const ValueKey('hi-beauty-logo')), findsOneWidget);
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
    await tester.pumpAndSettle();
    final otp = tester.widget<CustomerOtpScreen>(
      find.byType(CustomerOtpScreen),
    );
    expect(otp.args.registration?.name, 'Asha Patil');
    expect(otp.args.phone, '9876543210');
    await tester.enterText(find.byType(TextField), '654321');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(DevelopmentHomeScreen), findsOneWidget);
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
    await tester.pumpWidget(
      CustomerApp(
        config: config,
        operationsApi: CustomerFixtureApi(),
        auth: _testAuth(),
      ),
    );
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
    expect(find.byType(CustomerOtpScreen), findsOneWidget);
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

  testWidgets(
    'production registration fails closed without API configuration',
    (tester) async {
      await tester.pumpWidget(
        const CustomerApp(config: AppConfig(Environment.production)),
      );
      await tester.pump(const Duration(seconds: 2));
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
      await tester.pumpAndSettle();
      expect(find.textContaining('Configure API_BASE_URL'), findsOneWidget);
      expect(find.byType(CustomerOtpScreen), findsNothing);
      navigator.pushNamed(
        RouteNames.otp,
        arguments: const CustomerOtpRouteArgs(
          phone: '9876543210',
          challengeId: 'aaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomerOtpScreen), findsOneWidget);
    },
  );

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

  // Replaced implicit demo data with backend contract cases. Existing compact
  // checkout and booking lifecycle suites retain complete persisted-flow checks.
  registerCustomerCatalogContractCases();

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

      expect(
        find.byKey(const ValueKey('customer-login-background')),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(TextField)).width, greaterThan(0));
      final background = tester.getSize(
        find.byKey(const ValueKey('customer-login-background')),
      );
      expect(background.width, size.width);
      expect(
        background.height,
        inInclusiveRange(size.height * .9, size.height),
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
