import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_service_history_screen.dart';
import 'package:worker_app/integration/worker_mobile_auth_api.dart';
import 'package:worker_app/integration/worker_mobile_operations_api.dart';

class _TestTokenStorage implements WorkerTokenStorage {
  @override
  Future<String?> read() async => 'test-token-worker-history';
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> delete() async {}
}

void main() {
  const orders = <WorkerDashboardOrder>[
    WorkerDashboardOrder(
      id: 'A',
      customer: 'Sneha',
      service: 'Facial',
      time: '10 AM',
      location: 'Pune',
      customerPayable: 900,
      status: 'Completed',
    ),
    WorkerDashboardOrder(
      id: 'B',
      customer: 'Rutuja',
      service: 'Hair Spa',
      time: '11 AM',
      location: 'Latur',
      customerPayable: 700,
      status: 'Cancelled',
    ),
    WorkerDashboardOrder(
      id: 'C',
      customer: 'Pooja',
      service: 'Makeup',
      time: '12 PM',
      location: 'Pune',
      customerPayable: 1500,
      status: 'Accepted',
    ),
    WorkerDashboardOrder(
      id: 'D-404',
      customer: 'Sonal',
      service: 'Nails',
      time: '1 PM',
      location: 'Pune',
      customerPayable: 500,
      status: 'Demo Completed',
    ),
  ];

  test('history excludes nonterminal bookings', () {
    expect(filterWorkerServiceHistory(orders).map((e) => e.id), [
      'A',
      'B',
      'D-404',
    ]);
  });

  test('completed and cancelled filters preserve semantics', () {
    expect(
      filterWorkerServiceHistory(orders, filter: 'Completed').map((e) => e.id),
      ['A', 'D-404'],
    );
    expect(
      filterWorkerServiceHistory(orders, filter: 'Cancelled').map((e) => e.id),
      ['B'],
    );
  });

  test('search matches customer service or ID case insensitively', () {
    expect(filterWorkerServiceHistory(orders, query: 'sNeHa').single.id, 'A');
    expect(
      filterWorkerServiceHistory(orders, query: 'HAIR SPA').single.id,
      'B',
    );
    expect(
      filterWorkerServiceHistory(orders, query: ' d-404 ').single.id,
      'D-404',
    );
  });

  testWidgets('compact history preserves search, filters and order selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    WorkerDashboardOrder? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: WorkerServiceHistoryScreen(
          orders: orders,
          demoMode: false,
          onOrderTap: (order) => selected = order,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Facial'), findsOneWidget);
    expect(find.text('Hair Spa'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('history-filter-Completed')));
    await tester.pumpAndSettle();
    expect(find.text('Facial'), findsOneWidget);
    expect(find.text('Hair Spa'), findsNothing);

    await tester.tap(find.byKey(const Key('history-order-A')));
    expect(selected?.id, 'A');

    await tester.enterText(find.byKey(const Key('history-search')), 'Rutuja');
    await tester.pumpAndSettle();
    expect(find.text('No matching history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live service history loads backend bookings and displays live booking details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      if (request.url.path == '/api/mobile/worker/bookings') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [
                {
                  '_id': '6ae0398913ae096318e8c799',
                  'status': 'completed',
                  'customerSnapshot': {
                    'fullName': 'Pooja Sharma',
                    'mobileNumber': '+919876543210',
                  },
                  'items': [
                    {
                      'name': 'Bridal Glow Facial',
                      'quantity': 1,
                      'pricePaise': 250000,
                      'durationMinutes': 60,
                    }
                  ],
                  'addressSnapshot': {
                    'line1': 'Flat 302, Sunrise Apt',
                    'city': 'Latur',
                  },
                  'totalPaise': 250000,
                  'compensationPaise': 80000,
                  'paymentMethod': 'cash',
                  'paymentStatus': 'pending',
                  'startsAt': '2026-10-27T10:00:00.000Z',
                  'completedAt': '2026-10-27T11:15:00.000Z',
                }
              ]
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"success":false}', 404);
    });

    final opsApi = WorkerMobileOperationsApi(
      apiBaseUrl: 'http://localhost:5001/api',
      tokenStorage: _TestTokenStorage(),
      client: client,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkerServiceHistoryScreen(
          orders: const [],
          demoMode: false,
          operationsApi: opsApi,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LIVE PRODUCTION · Service history synced with salon backend'), findsOneWidget);
    expect(find.text('Bridal Glow Facial'), findsOneWidget);
    expect(find.textContaining('Pooja Sharma'), findsOneWidget);

    await tester.tap(find.text('Bridal Glow Facial'));
    await tester.pumpAndSettle();

    expect(find.text('Booking Details'), findsWidgets);
    expect(find.text('Pooja Sharma'), findsOneWidget);
    expect(find.textContaining('+919876543210'), findsOneWidget);
    expect(find.textContaining('Worker Compensation: ₹800'), findsOneWidget);
    expect(find.text('Service Completed 🎉 (Back)'), findsOneWidget);

    // Tap back button
    await tester.tap(find.text('Service Completed 🎉 (Back)'));
    await tester.pumpAndSettle();

    expect(find.text('Service History'), findsOneWidget);
  });
}
