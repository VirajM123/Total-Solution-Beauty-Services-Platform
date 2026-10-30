import 'dart:async';

import 'package:flutter/material.dart';
import 'app/worker_app.dart';
import 'integration/mobile_push.dart';
import 'integration/worker_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WorkerApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      MobilePush.initialize(
        appType: 'worker',
        apiBaseUrl: WorkerEnvironment.apiBaseUrl,
      ),
    );
  });
}
