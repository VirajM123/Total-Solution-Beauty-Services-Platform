import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../features/home/development_home_screen.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/login/login_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/otp/development_otp_screen.dart';
import '../features/register/registration_screen.dart';
import '../features/splash/splash_screen.dart';
import 'route_names.dart';

class AppRouter {
  const AppRouter(this.config);
  final AppConfig config;

  Route<dynamic> generate(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      RouteNames.splash => const SplashScreen(),
      RouteNames.onboarding => const OnboardingScreen(),
      RouteNames.login => LoginScreen(config: config),
      RouteNames.register => RegistrationScreen(config: config),
      RouteNames.otp
          when config.mockAuthEnabled && settings.arguments is String =>
        DevelopmentOtpScreen(phone: settings.arguments! as String),
      RouteNames.otp
          when config.mockAuthEnabled &&
              settings.arguments is DevelopmentRegistration =>
        DevelopmentOtpScreen(
          phone: (settings.arguments! as DevelopmentRegistration).phone,
          registration: settings.arguments! as DevelopmentRegistration,
        ),
      RouteNames.home when config.mockAuthEnabled =>
        const DevelopmentHomeScreen(),
      RouteNames.home => CatalogScreen(config: config),
      RouteNames.catalog => CatalogScreen(config: config),
      _ => LoginScreen(config: config),
    };
    return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
  }
}
