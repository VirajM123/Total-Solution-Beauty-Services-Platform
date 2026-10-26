import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/login/worker_login_screen.dart';
import 'package:worker_app/features/otp/worker_otp_screen.dart';
import 'package:worker_app/integration/worker_environment.dart';

void main() {
  testWidgets(
    'default login cannot accept development OTP or claim SMS delivery',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: WorkerLoginScreen(demoEnabled: true)),
      );
      await tester.enterText(
        find.byKey(const Key('worker-phone')),
        '9876543210',
      );
      await tester.ensureVisible(find.byKey(const Key('worker-continue')));
      await tester.tap(find.byKey(const Key('worker-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkerOtpScreen), findsNothing);
      expect(find.textContaining('Configure API_BASE_URL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: WorkerEnvironment.developmentPreview,
  );
}
