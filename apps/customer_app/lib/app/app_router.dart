import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../integration/customer_auth_api.dart';
import '../features/home/development_home_screen.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/login/login_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/otp/development_otp_screen.dart';
import '../features/register/registration_screen.dart';
import '../features/splash/splash_screen.dart';
import 'route_names.dart';

class AppRouter {
  const AppRouter(this.config, this.auth);
  final AppConfig config;
  final CustomerAuthApi auth;

  Route<dynamic> generate(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      RouteNames.splash => const SplashScreen(),
      RouteNames.onboarding => const OnboardingScreen(),
      RouteNames.login => LoginScreen(config: config, authApi: auth),
      RouteNames.register => RegistrationScreen(
        config: config,
        authApi: auth,
        registration: settings.arguments is CustomerRegistrationArgs
            ? settings.arguments! as CustomerRegistrationArgs
            : null,
      ),
      RouteNames.otp
          when settings.arguments is CustomerOtpRouteArgs =>
        CustomerOtpScreen(
          args: settings.arguments! as CustomerOtpRouteArgs,
          auth: auth,
        ),
      RouteNames.home when config.mockAuthEnabled =>
        const DevelopmentHomeScreen(),
      RouteNames.home => CatalogScreen(config: config),
      RouteNames.catalog => CatalogScreen(config: config),
      _ => LoginScreen(config: config, authApi: auth),
    };
    return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
  }
}
