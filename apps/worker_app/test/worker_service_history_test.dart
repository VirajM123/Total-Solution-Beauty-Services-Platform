import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_service_history_screen.dart';

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
}
