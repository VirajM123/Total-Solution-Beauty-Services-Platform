import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import 'app_router.dart';
import 'route_names.dart';

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key, required this.config});
  final AppConfig config;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Total Solution',
    debugShowCheckedModeBanner: false,
    theme: BeautyTheme.data,
    initialRoute: RouteNames.splash,
    onGenerateRoute: AppRouter(config).generate,
  );
}
