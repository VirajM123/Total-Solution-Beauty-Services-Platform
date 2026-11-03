import 'package:worker_app/features/widgets/worker_reference_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_dashboard_screen.dart';

void main() {
  testWidgets(
    'empty dashboard stays anchored to the top on a 360 by 800 phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkerDashboardScreen(demoMode: false, orders: []),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(WorkerReferenceHeader)).dy,
        lessThanOrEqualTo(4),
      );
      final header = tester.widget<WorkerReferenceHeader>(
        find.byType(WorkerReferenceHeader),
      );
      expect(header.brandWidth, 190);
      expect(tester.takeException(), isNull);
    },
  );

  final today = DateTime(2026, 10, 19, 9, 30);
  final orders = [
    WorkerDashboardOrder(
      id: 'today',
      customer: 'A Customer',
      service: 'Gold Facial',
      time: '11:59 PM',
      location: 'Latur',
      customerPayable: 1200,
      status: 'Accepted',
      appointmentDate: today,
    ),
    WorkerDashboardOrder(
      id: 'future',
      customer: 'Another Customer',
      service: 'Hair Spa',
      time: '10:00 AM',
      location: 'MIDC, Latur',
      customerPayable: 900,
      status: 'Scheduled',
      appointmentDate: today.add(const Duration(days: 1)),
    ),
  ];

  testWidgets(
    'dashboard fits narrow phone widths and uses dated appointments',
    (tester) async {
      for (final width in [320.0, 360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: WorkerDashboardScreen(
              demoMode: false,
              orders: orders,
              currentDate: today,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pinkora'), findsNothing);
        expect(find.text('Worker App'), findsNothing);
        expect(find.text('Manage Your Work'), findsNothing);
        expect(find.text('Rating'), findsOneWidget);
        expect(find.textContaining('₹1,200'), findsWidgets);
        expect(find.text('A Customer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets('next appointment stays readable above the fold', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerDashboardScreen(
          demoMode: false,
          orders: orders,
          currentDate: today,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Your next appointment')).dy,
      lessThan(844 - 80),
    );
    expect(
      tester.getTopLeft(find.text('Gold Facial').first).dy,
      lessThan(844 - 80),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('availability toggle still calls the existing handler', (
    tester,
  ) async {
    bool? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerDashboardScreen(
          demoMode: false,
          isApproved: true,
          onAvailabilityRequested: (desiredOnline) async {
            requested = desiredOnline;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(requested, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a loaded empty list shows zero counts and zero customer payable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkerDashboardScreen(demoMode: false, orders: []),
        ),
      );

      expect(find.text('0'), findsWidgets);
      expect(find.text('₹0'), findsWidgets);
      expect(find.text('Rating'), findsOneWidget);
      expect(
        find.text('No upcoming appointment is scheduled yet.'),
        findsOneWidget,
      );
      expect(find.text('No appointments scheduled for today.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('counts by local date, sorts today and shows the next booking', (
    tester,
  ) async {
    final today = DateTime(2026, 10, 19, 9, 30);
    final orders = [
      WorkerDashboardOrder(
        id: 'late',
        customer: 'Later Customer',
        service: 'Hair Spa',
        time: '10:00 AM',
        location: 'Latur',
        customerPayable: 1200,
        status: 'Accepted',
        appointmentDate: today,
      ),
      WorkerDashboardOrder(
        id: 'cancelled',
        customer: 'Cancelled Customer',
        service: 'Nails',
        time: '8:00 AM',
        location: 'Latur',
        customerPayable: 500,
        status: 'Cancelled',
        appointmentDate: today,
      ),
      WorkerDashboardOrder(
        id: 'early',
        customer: 'Early Customer',
        service: 'Gold Facial',
        time: '9:00 AM',
        location: 'MIDC, Latur',
        customerPayable: 900,
        status: 'Scheduled',
        appointmentDate: today,
      ),
      WorkerDashboardOrder(
        id: 'next',
        customer: 'Tomorrow Customer',
        service: 'Bridal Makeup',
        time: '10:00 AM',
        location: 'Ring Road, Latur',
        customerPayable: 1500,
        status: 'Scheduled',
        appointmentDate: today.add(const Duration(days: 1)),
      ),
      WorkerDashboardOrder(
        id: 'completed',
        customer: 'Completed Customer',
        service: 'Facial',
        time: '8:00 AM',
        location: 'Latur',
        customerPayable: 700,
        status: 'Completed',
        appointmentDate: today,
        completedAt: today,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: WorkerDashboardScreen(
          demoMode: false,
          orders: orders,
          currentDate: today,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Later Customer'), findsOneWidget);
    expect(find.text('Tomorrow Customer'), findsNothing);
    expect(find.text('Cancelled Customer'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Early Customer')).dy,
      greaterThan(tester.getTopLeft(find.text('Completed Customer')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('counts an actual completion timestamp before payment settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerDashboardScreen(
          demoMode: false,
          currentDate: today,
          orders: [
            WorkerDashboardOrder(
              id: 'finished',
              customer: 'Finished Customer',
              service: 'Facial',
              time: '9:00 AM',
              location: 'Latur',
              customerPayable: 900,
              status: 'Payment Pending',
              appointmentDate: today,
              completedAt: today,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsWidgets);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dated demo fixtures drive dashboard metrics deterministically', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerDashboardScreen(
          demoMode: false,
          orders: previewWorkerOrders,
          currentDate: DateTime(2026, 10, 19, 10, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Sneha Patil'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undated bookings remain unavailable to date-based lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerDashboardScreen(
          demoMode: false,
          orders: const [
            WorkerDashboardOrder(
              id: 'undated',
              customer: 'Undated Customer',
              service: 'Hair Spa',
              time: 'not a time',
              location: 'Latur',
              customerPayable: 900,
              status: 'Scheduled',
            ),
          ],
          currentDate: DateTime(2026, 10, 19),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsWidgets);
    expect(
      find.text('No upcoming appointment is scheduled yet.'),
      findsOneWidget,
    );
    expect(find.text('No appointments scheduled for today.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard navigation retains existing destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var payoutsOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerDashboardScreen(
          demoMode: false,
          orders: const [
            WorkerDashboardOrder(
              id: 'completed',
              customer: 'Completed Customer',
              service: 'Facial',
              time: '10:00 AM',
              location: 'Latur',
              customerPayable: 700,
              status: 'Completed',
            ),
            WorkerDashboardOrder(
              id: 'cancelled',
              customer: 'Cancelled Customer',
              service: 'Nails',
              time: '11:00 AM',
              location: 'Latur',
              customerPayable: 500,
              status: 'Cancelled',
            ),
          ],
          onPayoutsTap: () => payoutsOpened = true,
        ),
      ),
    );

    await tester.tap(find.text('Bookings').last);
    await tester.pumpAndSettle();
    expect(find.text('My Bookings'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('My Schedule'));
    await tester.tap(find.byTooltip('My Schedule'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('My Schedule / Leave'),
      ),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Notifications'));
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Earnings'));
    expect(payoutsOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('schedule preview receives dated shared bookings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerDashboardScreen(
          demoMode: false,
          currentDate: today,
          orders: [
            WorkerDashboardOrder(
              id: 'scheduled',
              customer: 'Shared Customer',
              service: 'Shared Service',
              time: '9:00 AM',
              location: 'Latur',
              customerPayable: 500,
              status: 'Scheduled',
              appointmentDate: today,
            ),
            WorkerDashboardOrder(
              id: 'cancelled',
              customer: 'Cancelled Customer',
              service: 'Cancelled Service',
              time: '10:00 AM',
              location: 'Latur',
              customerPayable: 700,
              status: 'Cancelled',
              appointmentDate: today,
            ),
          ],
        ),
      ),
    );

    await tester.ensureVisible(find.byTooltip('My Schedule'));
    await tester.tap(find.byTooltip('My Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Shared Service'), findsOneWidget);
    expect(find.text('Cancelled Service'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
