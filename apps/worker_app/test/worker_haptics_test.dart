import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/home/worker_booking_data.dart';
import 'package:worker_app/features/home/worker_bookings_screen.dart';
import 'package:worker_app/features/home/worker_incoming_booking_screen.dart';
import 'package:worker_app/features/home/worker_start_service_otp_screen.dart';
import 'package:worker_app/features/registration/screens/worker_registration_mobile_otp_screen.dart';
import 'package:worker_app/features/otp/worker_otp_screen.dart';

const _order = WorkerDashboardOrder(
  id: 'haptic-test',
  customer: 'Customer',
  service: 'Hair Spa',
  time: '10:00 AM',
  location: 'Latur',
  customerPayable: 900,
  status: 'Accepted',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('incoming 60-second offer uses a medium impact', (tester) async {
    final impacts = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          impacts.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: WorkerIncomingBookingScreen(order: _order)),
    );
    await tester.pump();

    expect(impacts, contains('HapticFeedbackType.mediumImpact'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('entering service OTP digits uses a light impact', (
    tester,
  ) async {
    final impacts = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          impacts.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: WorkerStartServiceOtpScreen(order: _order)),
    );
    await tester.enterText(find.byKey(const Key('start-service-otp')), '2');
    await tester.pump();

    expect(impacts, contains('HapticFeedbackType.lightImpact'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('live service OTP is returned for server verification', (
    tester,
  ) async {
    String? submittedCode;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                submittedCode = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => WorkerStartServiceOtpScreen(
                      order: _order,
                      demoMode: false,
                    ),
                  ),
                );
              },
              child: const Text('Open OTP'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('start-service-otp')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('verify-start-service')));
    await tester.pumpAndSettle();

    expect(submittedCode, '123456');
    expect(tester.takeException(), isNull);
  });

  testWidgets('entering registration OTP digits uses a light impact', (
    tester,
  ) async {
    final impacts = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          impacts.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: WorkerRegistrationMobileOtpScreen(mobile: '9876543210'),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('registration-mobile-demo-otp')),
      '1',
    );
    await tester.pump();

    expect(impacts, contains('HapticFeedbackType.lightImpact'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('entering login OTP digits uses a light impact', (tester) async {
    final impacts = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          impacts.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: WorkerOtpScreen(phone: '9876543210')),
    );
    await tester.enterText(find.byKey(const Key('worker-otp')), '1');
    await tester.pump();

    expect(impacts, contains('HapticFeedbackType.lightImpact'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a booking filter chip uses a light impact', (
    tester,
  ) async {
    final impacts = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          impacts.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: WorkerBookingsScreen(orders: [_order], demoMode: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pump();

    expect(impacts, contains('HapticFeedbackType.lightImpact'));
    expect(tester.takeException(), isNull);
  });
}
