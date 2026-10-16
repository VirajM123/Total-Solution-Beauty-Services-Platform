import 'package:flutter/material.dart';

class WorkerHomeScreen extends StatelessWidget {
  const WorkerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Worker Dashboard')),
    body: const Center(child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.work_outline, size: 66, color: Color(0xFFB20A50)),
        SizedBox(height: 20),
        Text('Dashboard preview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Text('Authentication is not connected. No real worker account or bookings are loaded.',
            textAlign: TextAlign.center),
      ]),
    )),
  );
}
