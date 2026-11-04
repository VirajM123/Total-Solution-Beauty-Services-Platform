import 'package:flutter/material.dart';
import 'worker_booking_data.dart';
import 'worker_extra_service_item.dart';

/// Read-only status supplied by the booking API. No local payment completion.
class WorkerWaitingCustomerPaymentScreen extends StatelessWidget {
  const WorkerWaitingCustomerPaymentScreen({super.key, required this.order,
    required this.extraServices, required this.demoFinishedAt, this.demoMode = false});
  final WorkerDashboardOrder order;
  final List<WorkerExtraServiceItem> extraServices;
  // Retained for compatibility with existing review callers; never authorizes payment.
  final DateTime demoFinishedAt;
  final bool demoMode;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment Collection')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Text(order.service, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      const Text('Amount to collect'),
      Text(order.formattedCustomerPayable, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      Text(order.paymentStatus == 'paid' ? 'Payment verified by the server' : 'Awaiting verified payment'),
      const SizedBox(height: 8),
      const Text('Payment and service completion must be verified through the booking workflow.'),
      const SizedBox(height: 20),
      OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Back to booking')),
    ]),
  );
}
