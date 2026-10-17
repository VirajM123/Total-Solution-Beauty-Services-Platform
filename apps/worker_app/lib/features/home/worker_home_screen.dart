import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'worker_dashboard_screen.dart';

/// Existing OTP route targets WorkerHomeScreen.
/// Preserve that contract while substituting the new Pinkora dashboard.
/// A backend-confirmed approved worker session is required before enabling
/// the real dashboard in release builds.
class WorkerHomeScreen extends StatelessWidget {
  const WorkerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF9F5),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 52, color: Color(0xFFB20A50)),
                  SizedBox(height: 16),
                  Text('Worker access not configured',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                          color: Color(0xFF460621))),
                  SizedBox(height: 8),
                  Text('Secure worker authentication and admin approval are required before dashboard access.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Frontend-only preview. Orders, status and totals are sample data.
    return const WorkerDashboardScreen(demoMode: true);
  }
}
