import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_payment_qr_screen.dart';
import 'package:worker_app/features/home/worker_booking_details_screen.dart';
import 'package:worker_app/features/home/worker_extra_service_item.dart';
import 'package:worker_app/features/home/worker_waiting_customer_payment_screen.dart';
import 'package:worker_app/integration/worker_mobile_operations_api.dart';

const order = WorkerDashboardOrder(
  id: '123456789012345678901234',
  customer: 'Customer',
  service: 'Facial',
  time: '10:00',
  location: 'Latur',
  customerPayable: 170,
  status: 'In Progress',
);

class PaymentApi extends WorkerMobileOperationsApi {
  bool paid = false;
  bool completed = false;
  bool finished = false;
  bool cashReported = false;
  String? cashReference;
  int? cashAmountPaise;
  bool readFails = false;
  int creates = 0;
  WorkerDashboardOrder? currentOrder;
  @override
  Future<WorkerDashboardOrder?> fetchBookingDetails(String id) async {
    if (readFails) throw StateError('Offline');
    return (currentOrder ?? order).copyWith(
      status: completed
          ? 'Completed'
          : paid
          ? 'In Progress'
          : finished
          ? 'Payment pending'
          : 'In Progress',
      paymentStatus: paid ? 'paid' : 'pending',
      paymentMethod: (currentOrder ?? order).paymentMethod,
      customerPayablePaise: (currentOrder ?? order).customerPayablePaise,
      serviceFinishedAt: finished ? DateTime(2026, 10, 29) : null,
      cashCollectionReportedAt: cashReported ? DateTime(2026, 10, 29) : null,
    );
  }

  @override
  Future<Map<String, dynamic>> createBookingPaymentQr(String id) async {
    creates++;
    return {'imageUrl': 'https://provider.test/qr.png', 'amountPaise': 17055};
  }

  @override
  Future<Map<String, dynamic>> updateBookingProgress({
    required String bookingId,
    required String action,
    String? otp,
    List<String> evidenceIds = const [],
  }) async {
    if (action == 'finish') finished = true;
    if (action == 'complete' && paid && otp == '123456') completed = true;
    return {'status': completed ? 'completed' : 'in_progress'};
  }

  @override
  Future<Map<String, dynamic>> reportCashCollection({
    required String bookingId,
    required int amountPaise,
    required String reference,
    required String idempotencyKey,
  }) async {
    cashReported = true;
    cashReference = reference;
    cashAmountPaise = amountPaise;
    return {'verification': 'pending_reconciliation'};
  }
}

void main() {
  testWidgets('demo payment status follows the collection-screen styling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerWaitingCustomerPaymentScreen(
            order: order.copyWith(status: 'Payment Pending'),
            extraServices: const [
              WorkerExtraServiceItem(
                id: 'preview-extra',
                name: 'Head Massage',
                customerPrice: 400,
                durationMinutes: 15,
              ),
            ],
            demoFinishedAt: DateTime(2026, 11, 3, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment Collection'), findsOneWidget);
      expect(find.text('Amount to collect'), findsOneWidget);
      expect(find.text('Card · Soon'), findsOneWidget);
      expect(find.text('PAYMENT PENDING · NOT SENT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('payment collection keeps future card UI inactive', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      final api = PaymentApi();
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerPaymentQrScreen(
            order: order,
            operationsApi: api,
            onCashCollection: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment Collection'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('Card · Soon'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(
                of: find.text('Card · Soon'),
                matching: find.byType(TextButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    }
  });

  testWidgets(
    'payment checks recover after a connection failure without showing success',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final api = PaymentApi()..readFails = true;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerPaymentQrScreen(order: order, operationsApi: api),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Unable to check payment.'), findsOneWidget);
      expect(find.text('Payment received · Service completed'), findsNothing);
      api.readFails = false;
      await tester.ensureVisible(find.text('Check payment status'));
      await tester.tap(find.text('Check payment status'));
      await tester.pump();
      expect(
        find.text('Awaiting verified payment from Razorpay.'),
        findsOneWidget,
      );
      expect(find.text('Payment received · Service completed'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('cash collection waits for admin reconciliation and OTP', (
    tester,
  ) async {
    final cashOrder = order.copyWith(
      paymentMethod: 'cash',
      customerPayablePaise: 17055,
    );
    final api = PaymentApi();
    api.currentOrder = cashOrder;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerBookingDetailsScreen(
          order: cashOrder,
          demoMode: false,
          operationsApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add Extra Service'), findsOneWidget);
    expect(find.text('Finish Service'), findsOneWidget);
    await tester.tap(find.byKey(const Key('finish-service')));
    await tester.pumpAndSettle();
    expect(find.text('Services provided'), findsOneWidget);
    await tester.tap(find.byKey(const Key('finish-service-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Payment Collection'), findsOneWidget);
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(find.text('Report cash collection'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'cash-receipt-1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(api.finished, isTrue);
    expect(api.cashReported, isTrue);
    expect(api.cashReference, 'cash-receipt-1');
    expect(api.cashAmountPaise, 17055);
    expect(find.text('Awaiting Admin Cash Reconciliation'), findsOneWidget);
    api.paid = true;
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('Enter Admin Completion OTP'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start-service-entry')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(api.completed, isTrue);
    expect(find.text('Service completed!'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Go to Home'), 200);
    expect(find.text('Go to Home'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('finishing work opens QR checkout before completion', (
    tester,
  ) async {
    for (final finished in [false, true]) {
      final api = PaymentApi();
      api.finished = finished;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkerBookingDetailsScreen(
            order: order,
            demoMode: false,
            operationsApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(finished ? 'View Payment QR' : 'Finish Service'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(Key(finished ? 'start-service-entry' : 'finish-service')),
      );
      await tester.pumpAndSettle();
      if (!finished) {
        expect(find.text('Services provided'), findsOneWidget);
        await tester.tap(find.byKey(const Key('finish-service-continue')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Payment Collection'), findsOneWidget);
      expect(find.text('Generate QR Code'), findsOneWidget);
      expect(api.creates, 0);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('verified payment still requires the worker completion OTP', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final api = PaymentApi();
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerPaymentQrScreen(order: order, operationsApi: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Payment Collection'), findsOneWidget);
    expect(find.text('Payment received · Service completed'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('generate-payment-qr-action')),
    );
    await tester.tap(find.byKey(const Key('generate-payment-qr-action')));
    await tester.pumpAndSettle();
    expect(api.creates, 0);
    await tester.tap(find.text('Generate QR'));
    await tester.pumpAndSettle();
    expect(api.creates, 1);
    expect(find.text('₹170.55'), findsOneWidget);
    expect(find.text('Payment received · Service completed'), findsNothing);
    api.paid = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Payment verified. Ask your administrator for the completion OTP.',
      ),
      findsOneWidget,
    );
    expect(find.text('Payment received · Service completed'), findsNothing);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify OTP & complete service'));
    await tester.pumpAndSettle();
    expect(find.text('Payment received · Service completed'), findsOneWidget);
    expect(find.text('Back to booking'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
