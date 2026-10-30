import 'package:flutter/foundation.dart';

/// Shared frontend booking display model. customerPayable is NOT worker earnings.
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
    this.appointmentDate,
    this.completedAt,
    this.customerPhone,
    this.itemsDescription,
    this.paymentMethod,
    this.paymentStatus,
    this.customerPayablePaise,
    this.compensationRupees,
    this.serviceStartedAt,
    this.serviceEndsAt,
    this.serviceFinishedAt,
    this.cashCollectionReportedAt,
    this.durationExtension,
  });

  final String id;
  final String customer;
  final String service;
  final String time;
  final String location;
  final int customerPayable;
  final String status;
  final String duration;

  /// Nullable until the booking backend supplies a real scheduled calendar date.
  /// Never infer a date from a time-of-day string.
  final DateTime? appointmentDate;

  /// Optional authoritative service completion time; customer bill data cannot
  /// be used to infer either the date or the worker's earnings.
  final DateTime? completedAt;

  final String? customerPhone;
  final String? itemsDescription;
  final String? paymentMethod;
  final String? paymentStatus;
  final int? customerPayablePaise;
  int get exactCustomerPayablePaise =>
      customerPayablePaise ?? customerPayable * 100;
  String get formattedCustomerPayable =>
      formatCustomerPaise(exactCustomerPayablePaise);
  final int? compensationRupees;
  final DateTime? serviceStartedAt;
  final DateTime? serviceEndsAt;
  final DateTime? serviceFinishedAt;
  final DateTime? cashCollectionReportedAt;
  final Map<String, dynamic>? durationExtension;

  WorkerDashboardOrder copyWith({
    String? status,
    DateTime? appointmentDate,
    DateTime? completedAt,
    String? customerPhone,
    String? itemsDescription,
    String? paymentMethod,
    String? paymentStatus,
    int? customerPayablePaise,
    int? compensationRupees,
    DateTime? serviceStartedAt,
    DateTime? serviceEndsAt,
    DateTime? serviceFinishedAt,
    DateTime? cashCollectionReportedAt,
    Map<String, dynamic>? durationExtension,
  }) => WorkerDashboardOrder(
    id: id,
    customer: customer,
    service: service,
    time: time,
    location: location,
    customerPayable: customerPayable,
    status: status ?? this.status,
    duration: duration,
    appointmentDate: appointmentDate ?? this.appointmentDate,
    completedAt: completedAt ?? this.completedAt,
    customerPhone: customerPhone ?? this.customerPhone,
    itemsDescription: itemsDescription ?? this.itemsDescription,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    customerPayablePaise: customerPayablePaise ?? this.customerPayablePaise,
    compensationRupees: compensationRupees ?? this.compensationRupees,
    serviceStartedAt: serviceStartedAt ?? this.serviceStartedAt,
    serviceEndsAt: serviceEndsAt ?? this.serviceEndsAt,
    serviceFinishedAt: serviceFinishedAt ?? this.serviceFinishedAt,
    cashCollectionReportedAt:
        cashCollectionReportedAt ?? this.cashCollectionReportedAt,
    durationExtension: durationExtension ?? this.durationExtension,
  );
}

/// Explicit, deterministic demo dates keep every worker preview on one dataset.
/// Production API records continue to use their authoritative scheduled dates.
final previewWorkerOrders = List<WorkerDashboardOrder>.unmodifiable([
  WorkerDashboardOrder(
    id: 'P-001',
    customer: 'Rutuja More',
    service: 'Hair Spa',
    time: '10:00 AM',
    location: 'MIDC, Latur',
    customerPayable: 999,
    status: 'Completed',
    appointmentDate: DateTime(2026, 10, 19),
    completedAt: DateTime(2026, 10, 19, 10, 15),
  ),
  WorkerDashboardOrder(
    id: 'P-002',
    customer: 'Sneha Patil',
    service: 'Gold Facial',
    time: '11:00 AM',
    location: 'Mangalwar Peth, Latur',
    customerPayable: 1200,
    status: 'Accepted',
    appointmentDate: DateTime(2026, 10, 19),
  ),
  WorkerDashboardOrder(
    id: 'P-003',
    customer: 'Pooja Jadhav',
    service: 'Bridal Makeup',
    time: '4:00 PM',
    location: 'Ring Road, Latur',
    customerPayable: 1500,
    status: 'Scheduled',
    appointmentDate: DateTime(2026, 10, 20),
  ),
]);

String formatCustomerRupees(int amount) {
  final raw = amount.toString();
  if (raw.length <= 3) return '₹$raw';
  final last = raw.substring(raw.length - 3);
  final first = raw.substring(0, raw.length - 3);
  final prefix = first.replaceAllMapped(
    RegExp(r'\B(?=(\d{2})+(?!\d))'),
    (_) => ',',
  );
  return '₹$prefix,$last';
}

String formatCustomerPaise(int amountPaise) {
  final whole = formatCustomerRupees(amountPaise ~/ 100);
  final remainder = amountPaise.abs() % 100;
  return remainder == 0
      ? whole
      : whole + '.' + remainder.toString().padLeft(2, '0');
}
