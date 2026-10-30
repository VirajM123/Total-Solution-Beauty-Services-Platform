import 'dart:convert';

import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:customer_app/integration/customer_auth_api.dart';
import 'package:customer_app/integration/customer_mobile_operations_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStorage implements CustomerTokenStorage {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  testWidgets('dashboard and tabs tolerate non-discounted compare-at prices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = CustomerMobileOperationsApi(
      apiBaseUrl: 'https://example.test/api',
      tokenStorage: _TokenStorage(),
      client: MockClient((request) async {
        final items = request.url.path.endsWith('/services')
            ? [
                for (var index = 0; index < 4; index++)
                  {
                    '_id': '${index + 1}'.padLeft(24, '0'),
                    'name': 'Facial $index',
                    'category': {'name': 'Facial'},
                    'pricePaise': 10000,
                    if (index > 0)
                      'compareAtPricePaise': [0, 0, 10000, 20000][index],
                    'durationMinutes': 30,
                    'thumbnail': '',
                  },
              ]
            : [];
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'items': items},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(home: DevelopmentHomeScreen(operationsApi: api)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final tab in ['My Cart', 'Offers', 'Profile', 'Home']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
      if (tab == 'Offers') {
        expect(find.text('50% OFF'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('offer-service-deal-facial::facial 1')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('offer-service-deal-facial::facial 2')),
          findsNothing,
        );
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
