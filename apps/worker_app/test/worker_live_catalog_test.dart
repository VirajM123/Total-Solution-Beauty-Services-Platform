import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worker_app/integration/worker_mobile_operations_api.dart';
import 'package:worker_app/features/home/worker_add_extra_service_screen.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_profile_data.dart';
import 'package:worker_app/integration/worker_mobile_auth_api.dart';
import 'package:worker_app/features/registration/screens/worker_professional_details_screen.dart';

class _Token implements WorkerTokenStorage {
  @override
  Future<String?> read() async => 'worker-session';
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

class _ProfileStorage implements WorkerProfileStorage {
  @override
  Future<String?> read(String key) async =>
      throw StateError('Live profiles must use the backend');
  @override
  Future<void> write(String key, String value) async {}
}

void main() {
  test(
    'live worker profile resolves backend skill IDs without invented personal details',
    () async {
      final api = WorkerMobileOperationsApi(
        apiBaseUrl: 'https://example.test/api',
        tokenStorage: _Token(),
        client: MockClient((request) async {
          final data = request.url.path.endsWith('/profile')
              ? {
                  'user': {
                    'fullName': 'Backend Worker',
                    'mobileNumber': '+919876543210',
                  },
                  'profile': {
                    'serviceIds': ['123456789012345678901234'],
                  },
                }
              : {
                  'items': [
                    {
                      'id': '123456789012345678901234',
                      'name': 'Backend Custom Treatment',
                      'category': {'name': 'Backend Custom Category'},
                    },
                  ],
                  'pagination': {'pages': 1},
                };
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
      );
      final repository = WorkerProfileRepository(
        _ProfileStorage(),
        operationsApi: api,
      );
      final profile = await repository.load('9876543210');
      expect(profile!.fullName, 'Backend Worker');
      expect(profile.services, ['Backend Custom Treatment']);
      expect(profile.primaryCategory, 'Backend Custom Category');
      expect(profile.dateOfBirth, isNull);
      expect(profile.languages, isEmpty);
      expect(profile.cityOrArea, isEmpty);
      expect(profile.about, isEmpty);
      expect(profile.certificateDetails, isEmpty);
      repository.dispose();
      api.close();
    },
  );
  test(
    'worker catalog preserves query parameters and reads every page',
    () async {
      final pages = <int>[];
      final api = WorkerMobileOperationsApi(
        apiBaseUrl: 'https://example.test/api/v1',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/catalog/services');
          expect(request.url.queryParameters['limit'], '100');
          final page = int.parse(request.url.queryParameters['page']!);
          pages.add(page);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {'id': '$page', 'name': 'Backend service $page'},
                ],
                'pagination': {'page': page, 'pages': 2},
              },
            }),
            200,
          );
        }),
      );
      final services = await api.fetchCatalogServices();
      expect(pages, [1, 2]);
      expect(services.map((service) => service['name']), [
        'Backend service 1',
        'Backend service 2',
      ]);
      api.close();
    },
  );

  test(
    'worker registration reads every backend service page from the public catalog',
    () async {
      final pages = <int>[];
      final api = WorkerMobileAuthApi(
        apiBaseUrl: 'https://example.test/api',
        tokenStorage: _Token(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/catalog/services');
          expect(request.url.queryParameters['limit'], '100');
          final page = int.parse(request.url.queryParameters['page']!);
          pages.add(page);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'service-$page',
                    'name': 'Backend service $page',
                    'category': {'name': 'Backend category'},
                  },
                ],
                'pagination': {'page': page, 'pages': 2},
              },
            }),
            200,
          );
        }),
      );

      final services = await api.fetchServices();

      expect(pages, [1, 2]);
      expect(services.map((service) => service['name']), [
        'Backend service 1',
        'Backend service 2',
      ]);
      api.close();
    },
  );

  test(
    'worker service catalog errors are surfaced instead of hidden',
    () async {
      final api = WorkerMobileAuthApi(
        apiBaseUrl: 'https://example.test/api',
        tokenStorage: _Token(),
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'SERVICE_UNAVAILABLE'},
            }),
            503,
          ),
        ),
      );

      await expectLater(
        api.fetchServices(),
        throwsA(isA<WorkerAuthException>()),
      );
      api.close();
    },
  );

  testWidgets('worker professional choices use only live backend services', (
    tester,
  ) async {
    final api = WorkerMobileAuthApi(
      apiBaseUrl: 'https://example.test/api',
      tokenStorage: _Token(),
      client: MockClient((request) async {
        final items = request.url.path.endsWith('/services')
            ? [
                {
                  'id': 'service-live',
                  'name': 'Backend Custom Treatment',
                  'category': {'name': 'Backend Custom Category'},
                },
              ]
            : <Map<String, dynamic>>[];
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': items,
              'pagination': {'page': 1, 'pages': 1},
            },
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: WorkerProfessionalDetailsScreen(authApi: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Backend Custom Category'), findsOneWidget);
    await tester.tap(find.text('Backend Custom Category'));
    await tester.pumpAndSettle();
    expect(find.text('Backend Custom Treatment'), findsOneWidget);
    expect(find.text('Hair'), findsNothing);
    expect(find.text('Haircut'), findsNothing);
    api.close();
  });

  testWidgets('worker catalog failures do not show fixture services', (
    tester,
  ) async {
    final api = WorkerMobileAuthApi(
      apiBaseUrl: 'https://example.test/api',
      tokenStorage: _Token(),
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'success': false,
            'error': {'code': 'SERVICE_UNAVAILABLE'},
          }),
          503,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: WorkerProfessionalDetailsScreen(authApi: api)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not load published services'),
      findsOneWidget,
    );
    expect(find.text('Haircut'), findsNothing);
    expect(find.text('Hair Spa'), findsNothing);
    api.close();
  });

  testWidgets(
    'live extras display backend services, prices, and durations only',
    (tester) async {
      final api = WorkerMobileOperationsApi(
        apiBaseUrl: 'https://example.test/api',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': '123456789012345678901234',
                    'name': 'Backend Custom Treatment',
                    'pricePaise': '135000',
                    'durationMinutes': 75,
                  },
                ],
                'pagination': {'pages': 1},
              },
            }),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerAddExtraServiceScreen(
            demoMode: false,
            operationsApi: api,
            order: const WorkerDashboardOrder(
              id: '123456789012345678901235',
              customer: 'Backend Customer',
              service: 'Service',
              time: '11:00 AM',
              location: 'Saved address',
              customerPayable: 1200,
              status: 'In Progress',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Backend Custom Treatment'), findsOneWidget);
      expect(find.textContaining('75 mins'), findsOneWidget);
      expect(find.textContaining('1,350'), findsOneWidget);
      expect(find.text('Face Bleach'), findsNothing);
      expect(find.text('Head Massage'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );
}
