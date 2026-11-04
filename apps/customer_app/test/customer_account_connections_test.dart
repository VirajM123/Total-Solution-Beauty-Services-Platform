import 'dart:convert';
import 'package:customer_app/features/home/customer_account_screen.dart';
import 'package:customer_app/features/home/development_home_screen.dart';
import 'package:customer_app/integration/customer_auth_api.dart';
import 'package:customer_app/integration/customer_mobile_operations_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Storage implements CustomerTokenStorage {
  String? token = 'customer-token';
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> delete() async => token = null;
}

void main() {
  test(
    'offline logout removes credentials even when revocation fails',
    () async {
      final storage = _Storage();
      final api = CustomerMobileOperationsApi(
        tokenStorage: storage,
        apiBaseUrl: 'https://example.test/api/v1',
        client: MockClient(
          (_) async => http.Response('{"error":{"message":"Offline"}}', 503),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.logout(),
        throwsA(isA<CustomerMobileApiException>()),
      );
      expect(storage.token, isNull);
    },
  );

  testWidgets(
    'profile logout revokes the backend session and returns to login',
    (tester) async {
      final storage = _Storage();
      final calls = <String>[];
      final api = CustomerMobileOperationsApi(
        tokenStorage: storage,
        apiBaseUrl: 'https://example.test/api/v1',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/profile')
                  ? {
                      'user': {'fullName': 'Customer'},
                    }
                  : {'items': []},
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: DevelopmentHomeScreen(operationsApi: api),
          routes: {
            '/login': (_) => const Scaffold(body: Text('Sign in again')),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      final logout = find.byKey(const ValueKey('profile-menu-Logout'));
      await tester.scrollUntilVisible(
        logout,
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-settings-screen')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(calls, contains('POST /api/v1/mobile/customer/logout'));
      expect(storage.token, isNull);
      expect(find.text('Sign in again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cart restores backend IDs and saves quantity changes without repricing',
    (tester) async {
      final saved = <Map<String, dynamic>>[];
      final api = CustomerMobileOperationsApi(
        tokenStorage: _Storage(),
        apiBaseUrl: 'https://example.test/api/v1',
        client: MockClient((request) async {
          final path = request.url.path;
          dynamic data = {'items': []};
          if (path.endsWith('/services'))
            data = {
              'items': [
                {
                  'id': '123456789012345678901234',
                  'name': 'Gold Facial',
                  'category': {'name': 'Facial'},
                  'pricePaise': '10000',
                  'durationMinutes': 60,
                },
              ],
            };
          if (path.endsWith('/cart-draft')) {
            if (request.method == 'PUT') {
              saved.add(jsonDecode(request.body));
              data = {};
            } else {
              data = {
                'items': [
                  {'serviceId': '123456789012345678901234', 'quantity': 2},
                ],
              };
            }
          }
          if (path.endsWith('/profile'))
            data = {
              'user': {'fullName': 'Customer'},
            };
          return http.Response(jsonEncode({'data': data}), 200);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(home: DevelopmentHomeScreen(operationsApi: api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Cart').last);
      await tester.pumpAndSettle();
      expect(find.text('Gold Facial'), findsWidgets);
      expect(find.text('₹200'), findsWidgets);
      await tester.tap(find.byTooltip('Increase Gold Facial quantity'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(saved.last['items'], [
        {'serviceId': '123456789012345678901234', 'quantity': 3},
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('general account support sends and reloads a persisted ticket', (
    tester,
  ) async {
    final tickets = <Map<String, dynamic>>[];
    final api = CustomerMobileOperationsApi(
      tokenStorage: _Storage(),
      apiBaseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          final ticket = jsonDecode(request.body) as Map<String, dynamic>;
          expect(ticket.containsKey('bookingId'), isFalse);
          expect(request.headers['x-idempotency-key'], startsWith('support_'));
          tickets.add({...ticket, 'status': 'open'});
        }
        return http.Response(
          jsonEncode({
            'data': {'items': tickets},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerAccountScreen(
          api: api,
          section: 'support',
          title: 'Help & Support',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get help'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Please help with my account',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(tickets, hasLength(1));
    expect(tickets.single['subject'], 'Please help with my account');
    expect(find.text('Please help with my account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
