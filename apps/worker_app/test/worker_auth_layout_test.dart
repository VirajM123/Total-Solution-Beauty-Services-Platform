import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/login/worker_login_screen.dart';
import 'package:worker_app/features/otp/worker_otp_screen.dart';
import 'package:worker_app/features/splash/worker_splash_screen.dart';

void main() {
  testWidgets('auth screens fit compact phones and enlarged text', (
    tester,
  ) async {
    final font = FontLoader('Montserrat')
      ..addFont(rootBundle.load('assets/fonts/Montserrat-Regular.ttf'));
    await font.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      for (final screen in <Widget>[
        const WorkerSplashScreen(),
        const WorkerLoginScreen(),
        const WorkerOtpScreen(phone: '9876543210'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Montserrat'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: screen,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} at $size',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      }
    }
  });
}
