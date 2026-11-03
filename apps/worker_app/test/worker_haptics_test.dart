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
      MaterialApp(
        home: WorkerStartServiceOtpScreen(order: _order, onContact: () {}),
      ),
    );
    expect(find.text('Enter Customer OTP'), findsOneWidget);
    expect(find.text('Call Customer'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('start-service-otp')), '2');
    await tester.pump();

    expect(find.text('2'), findsWidgets);
    expect(impacts, contains('HapticFeedbackType.lightImpact'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('live service OTP stays locked before product photo upload', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkerStartServiceOtpScreen(order: _order, demoMode: false),
      ),
    );
    expect(find.text('Photograph Service Products'), findsOneWidget);
    expect(find.byKey(const Key('start-service-otp')), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    final nextButton = tester.widget<FilledButton>(
      find.byKey(const Key('next-to-start-service-otp')),
    );
    expect(nextButton.onPressed, isNull);
    expect(find.text('Add at least one photo'), findsOneWidget);
    expect(
      find.text(
        'OTP entry unlocks after a product photo has uploaded successfully.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reference OTP screen preserves demo verification', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? verified;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                verified = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => WorkerStartServiceOtpScreen(order: _order),
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
    await tester.enterText(find.byKey(const Key('start-service-otp')), '2841');
    await tester.ensureVisible(find.byKey(const Key('verify-start-service')));
    await tester.tap(find.byKey(const Key('verify-start-service')));
    await tester.pumpAndSettle();

    expect(verified, isTrue);
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
