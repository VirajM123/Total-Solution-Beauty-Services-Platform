import 'package:flutter/foundation.dart';

/// Shared frontend representation of a booking.
/// customerPayable is the customer's bill, never the worker's payout.
@immutable
class WorkerDashboardOrder {
  const WorkerDashboardOrder({
    required this.id,
    required this.customer,
    required this.service,
    required this.time,
    required this.location,
    required this.customerPayable,
    required this.status,
    this.duration = '60 min',
  });
  final String id;
  final String customer;
  final String service;
  final String time;
  final String location;
  final int customerPayable;
  final String status;
  final String duration;

  WorkerDashboardOrder copyWith({String? status}) => WorkerDashboardOrder(
        id: id, customer: customer, service: service, time: time,
        location: location, customerPayable: customerPayable,
        status: status ?? this.status, duration: duration,
      );
}

/// One source of UI preview data for both Dashboard and Bookings.
/// Production callers must supply authenticated worker-specific bookings.
const previewWorkerOrders = <WorkerDashboardOrder>[
  WorkerDashboardOrder(id: 'P-001', customer: 'Rutuja More', service: 'Hair Spa', time: '10:00 AM', location: 'MIDC, Latur', customerPayable: 999, status: 'Completed'),
  WorkerDashboardOrder(id: 'P-002', customer: 'Sneha Patil', service: 'Gold Facial', time: '11:00 AM', location: 'Mangalwar Peth, Latur', customerPayable: 1200, status: 'Accepted'),
  WorkerDashboardOrder(id: 'P-003', customer: 'Pooja Jadhav', service: 'Bridal Makeup', time: '4:00 PM', location: 'Ring Road, Latur', customerPayable: 1500, status: 'Scheduled'),
];

String formatCustomerRupees(int amount) {
  final raw = amount.toString();
  if (raw.length <= 3) return '₹$raw';
  final last = raw.substring(raw.length - 3);
  final first = raw.substring(0, raw.length - 3);
  final prefix = first.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (_) => ',');
  return '₹$prefix,$last';
}
