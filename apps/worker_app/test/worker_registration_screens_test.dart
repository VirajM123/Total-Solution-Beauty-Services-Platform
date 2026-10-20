import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/registration/screens/worker_application_status_screen.dart';
import 'package:worker_app/features/registration/screens/worker_document_verification_screen.dart';
import 'package:worker_app/features/registration/screens/worker_personal_details_screen.dart';
import 'package:worker_app/features/registration/screens/worker_professional_details_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> setCompactPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void expectNoLayoutException(WidgetTester tester) {
    final error = tester.takeException();
    expect(
      error,
      isNull,
      reason: error is FlutterError ? error.toStringDeep() : '$error',
    );
  }

  testWidgets('personal registration remains usable on compact phones', (
    tester,
  ) async {
    await setCompactPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(home: WorkerPersonalDetailsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 4'), findsOneWidget);
    expect(find.text('Full name *'), findsOneWidget);
    expectNoLayoutException(tester);
  });

  testWidgets('professional registration remains usable on compact phones', (
    tester,
  ) async {
    await setCompactPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(home: WorkerProfessionalDetailsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('STEP 2 OF 4'), findsOneWidget);
    expect(find.text('Primary expertise *'), findsOneWidget);
    expectNoLayoutException(tester);
  });

  testWidgets('document and application status pages avoid narrow overflow', (
    tester,
  ) async {
    await setCompactPhone(tester);
    await tester.pumpWidget(
      const MaterialApp(home: WorkerDocumentVerificationScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('STEP 3 OF 4'), findsOneWidget);
    expectNoLayoutException(tester);

    await tester.pumpWidget(
      const MaterialApp(home: WorkerApplicationStatusScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Almost there!'), findsOneWidget);
    expectNoLayoutException(tester);
  });
}
