import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/core/config/app_config.dart';
import 'package:customer_app/core/config/environment.dart';

void main() {
  testWidgets('customer app starts with its real branding', (tester) async {
    await tester.pumpWidget(
      const CustomerApp(config: AppConfig(Environment.production)),
    );
    expect(find.byKey(const ValueKey('hi-beauty-logo')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
