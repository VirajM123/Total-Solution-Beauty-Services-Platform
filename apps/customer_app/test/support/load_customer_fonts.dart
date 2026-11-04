import 'package:flutter/services.dart';

Future<void> loadCustomerFonts() async {
  final loader = FontLoader('HiBeautySans')
    ..addFont(rootBundle.load('assets/fonts/HiBeautySans-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/HiBeautySans-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/HiBeautySans-Bold.ttf'));
  await loader.load();
}
