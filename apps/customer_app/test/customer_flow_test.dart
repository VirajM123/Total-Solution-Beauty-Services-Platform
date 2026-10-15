import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/app/route_names.dart';
import 'package:customer_app/core/config/app_config.dart';
import 'package:customer_app/core/config/environment.dart';
import 'package:customer_app/core/constants/app_assets.dart';
import 'package:customer_app/features/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const config = AppConfig(Environment.development);

void main() {
  testWidgets('splash renders branding and advances to onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(const CustomerApp(config: config));
    expect(find.text('Total Solution'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Get Started opens login', (tester) async {
    await tester.pumpWidget(const CustomerApp(config: config));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
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
    expect(find.text('Development OTP'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '111111');
    await tester.tap(find.text('Verify mock code'));
    await tester.pump();
    expect(find.textContaining('Incorrect development code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify mock code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Home screen coming'), findsOneWidget);
  });

  testWidgets('production cannot open development OTP route', (tester) async {
    await tester.pumpWidget(
      const CustomerApp(config: AppConfig(Environment.production)),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(RouteNames.otp, arguments: '9876543210');
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Development OTP'), findsNothing);
  });

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
