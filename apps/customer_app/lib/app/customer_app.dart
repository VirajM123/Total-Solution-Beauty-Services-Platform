import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import 'app_router.dart';
import 'route_names.dart';
import '../core/constants/pinkora_brand.dart';

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key, required this.config});
  final AppConfig config;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: PinkoraBrand.name,
    debugShowCheckedModeBanner: false,
    theme: BeautyTheme.data.copyWith(
      textTheme: BeautyTheme.data.textTheme.apply(fontFamily: 'Montserrat'),
      primaryTextTheme: BeautyTheme.data.primaryTextTheme.apply(
        fontFamily: 'Montserrat',
      ),
      inputDecorationTheme: BeautyTheme.data.inputDecorationTheme,
    ),
    initialRoute: RouteNames.splash,
    onGenerateRoute: AppRouter(config).generate,
  );
}
