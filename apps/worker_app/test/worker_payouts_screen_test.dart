import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_dashboard_screen.dart';
import 'package:worker_app/features/home/worker_payout_data.dart';
import 'package:worker_app/features/home/worker_payouts_screen.dart';

void main() {
  testWidgets('unconfigured payout source shows an intentional empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WorkerPayoutsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('My Earnings / Payouts'), findsOneWidget);
    expect(find.text('Waiting for payout records'), findsOneWidget);
    expect(find.text('Your payout space is ready'), findsOneWidget);
    expect(find.text('PAYOUT DATA NOT CONNECTED'), findsOneWidget);
    expect(find.text('How payouts work'), findsOneWidget);
    expect(find.text('Not available'), findsNothing);
    expect(find.text('₹0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('records render totals, filters and payout detail values', (
    tester,
  ) async {
    final repository = _FakePayoutRepository(
      records: [
        _payout(
          id: '1',
          payoutId: 'PAY-20261019-01',
          amount: 1200,
          date: DateTime(2026, 10, 19),
          status: WorkerPayoutStatus.paid,
          services: 4,
        ),
        _payout(
          id: '2',
          payoutId: 'PAY-20261018-01',
          amount: 740,
          date: DateTime(2026, 10, 18),
          status: WorkerPayoutStatus.pending,
          services: 3,
        ),
        _payout(
          id: '3',
          payoutId: 'PAY-20261017-01',
          amount: 620,
          date: DateTime(2026, 10, 17),
          status: WorkerPayoutStatus.adjusted,
          services: 2,
        ),
      ],
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(home: WorkerPayoutsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(repository.refreshCount, 1);
    expect(find.text('₹1,200'), findsNWidgets(2));
    expect(find.text('1 paid'), findsOneWidget);
    expect(find.textContaining('PAY-20261019-01'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Pending').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('PAY-20261018-01'), findsOneWidget);
    expect(find.textContaining('PAY-20261019-01'), findsNothing);

    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Payout details'), findsOneWidget);
    expect(find.text('Payout ID'), findsOneWidget);
    expect(find.text('PAY-20261018-01'), findsOneWidget);
  });

  testWidgets('a connected empty payout source displays a true zero total', (
    tester,
  ) async {
    final repository = _FakePayoutRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(home: WorkerPayoutsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('₹0'), findsOneWidget);
    expect(find.text('0 paid'), findsOneWidget);
    expect(find.text('No payout records yet'), findsOneWidget);
    expect(find.text('Not available'), findsNothing);
  });

  testWidgets('payout source updates are reflected reactively', (tester) async {
    final repository = _FakePayoutRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(home: WorkerPayoutsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No payout records yet'), findsOneWidget);

    repository.publish([
      _payout(
        id: 'live-1',
        payoutId: 'LIVE-1',
        amount: 8950,
        date: DateTime(2026, 10, 19),
        status: WorkerPayoutStatus.paid,
        services: 5,
      ),
    ]);
    await tester.pump();

    expect(find.text('₹8,950'), findsNWidgets(2));
    expect(find.textContaining('LIVE-1'), findsOneWidget);
  });

  testWidgets('source errors show retry and do not turn into zero payouts', (
    tester,
  ) async {
    final repository = _FakePayoutRepository(failRefresh: true);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(home: WorkerPayoutsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load payouts'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('No payout records yet'), findsNothing);
  });

  testWidgets('dashboard payout tab opens the payout screen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkerDashboardScreen(demoMode: false, orders: []),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Payouts'));
    await tester.pumpAndSettle();

    expect(find.text('My Earnings / Payouts'), findsOneWidget);
    expect(find.text('Your payout space is ready'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar).last,
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pinkora'), findsOneWidget);
    expect(find.text('My Earnings / Payouts'), findsNothing);
  });

  testWidgets('payout screen fits supported phone widths', (tester) async {
    final repository = _FakePayoutRepository(
      records: [
        _payout(
          id: '1',
          payoutId: 'PAY-20261019-01-WITH-A-LONG-IDENTIFIER',
          amount: 12450,
          date: DateTime(2026, 10, 19),
          status: WorkerPayoutStatus.paid,
          services: 12,
        ),
      ],
    );
    addTearDown(repository.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(home: WorkerPayoutsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

WorkerPayoutRecord _payout({
  required String id,
  required String payoutId,
  required int amount,
  required DateTime date,
  required WorkerPayoutStatus status,
  required int services,
}) => WorkerPayoutRecord(
  id: id,
  payoutId: payoutId,
  amountRupees: amount,
  serviceCount: services,
  date: date,
  status: status,
);

class _FakePayoutRepository extends WorkerPayoutRepository {
  _FakePayoutRepository({
    List<WorkerPayoutRecord> records = const [],
    this.failRefresh = false,
  }) : _records = List.unmodifiable(records);

  List<WorkerPayoutRecord> _records;
  final bool failRefresh;
  int refreshCount = 0;
  WorkerPayoutLoadStatus _loadStatus = WorkerPayoutLoadStatus.idle;
  Object? _error;

  @override
  WorkerPayoutLoadStatus get loadStatus => _loadStatus;

  @override
  Object? get error => _error;

  @override
  List<WorkerPayoutRecord> get records => _records;

  @override
  Future<void> refresh() async {
    refreshCount++;
    _loadStatus = WorkerPayoutLoadStatus.loading;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    if (failRefresh) {
      _loadStatus = WorkerPayoutLoadStatus.error;
      _error = StateError('Payout service unavailable');
      notifyListeners();
      throw _error!;
    }
    _loadStatus = WorkerPayoutLoadStatus.loaded;
    notifyListeners();
  }

  void publish(List<WorkerPayoutRecord> records) {
    _records = List.unmodifiable(records);
    _loadStatus = WorkerPayoutLoadStatus.loaded;
    notifyListeners();
  }
}
