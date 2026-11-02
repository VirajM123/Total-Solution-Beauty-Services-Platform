import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/login/worker_login_screen.dart';
import 'package:worker_app/features/otp/worker_otp_screen.dart';
import 'package:worker_app/features/registration/screens/worker_account_registration_screen.dart';
import 'package:worker_app/features/registration/screens/worker_personal_details_screen.dart';
import 'package:worker_app/features/registration/screens/worker_professional_details_screen.dart';
import 'package:worker_app/features/registration/screens/worker_document_verification_screen.dart';
import 'package:worker_app/features/registration/screens/worker_application_status_screen.dart';
import 'package:worker_app/integration/worker_mobile_auth_api.dart';

void main() {
  testWidgets(
    'reference layouts retain comfortable controls on narrow phones',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final font = FontLoader('Montserrat')
        ..addFont(rootBundle.load('assets/fonts/Montserrat-Regular.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final auth = WorkerMobileAuthApi();
      final pages = <String, Widget>{
        'login': const WorkerLoginScreen(demoEnabled: false),
        'otp': const WorkerOtpScreen(phone: '9876543210'),
        'account': WorkerAccountRegistrationScreen(
          phone: '9876543210',
          authApi: auth,
        ),
        'personal': const WorkerPersonalDetailsScreen(),
        'professional': const WorkerProfessionalDetailsScreen(),
        'documents': const WorkerDocumentVerificationScreen(),
        'status': const WorkerApplicationStatusScreen(),
      };
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 844);
        for (final entry in pages.entries) {
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'Montserrat'),
              home: RepaintBoundary(key: key, child: entry.value),
            ),
          );
          await tester.runAsync(() async {
            final context = key.currentContext!;
            await Future.wait([
              for (final asset in [
                'assets/images/logo/logo.png',
                'assets/images/illustrations/worker_customer_otp_phone.png',
                'assets/images/backgrounds/worker_auth_petals.png',
                'assets/images/backgrounds/worker_soft_canvas.png',
              ])
                precacheImage(AssetImage(asset), context),
            ]);
          });
          await tester.pump(const Duration(seconds: 1));
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} at $width',
          );
          if (entry.key == 'login') {
            expect(
              tester.getSize(find.byKey(const Key('worker-phone'))).height,
              greaterThanOrEqualTo(64),
            );
          }
          if (width == 390) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory('../../../output/worker-reference-review');
              await dir.create(recursive: true);
              await File(
                '${dir.path}/${entry.key}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
        }
      }
    },
  );
}
