import 'dart:async';
import 'package:customer_app/features/shared/customer_image.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  CustomerImage.diskCacheEnabled = false;
  await testMain();
}
