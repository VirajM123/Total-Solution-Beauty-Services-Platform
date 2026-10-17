import 'package:flutter/foundation.dart';

/// Frontend-only workflow states; these must not be interpreted as server trust.
enum WorkerServiceStage { notStarted, inProgress, finished }
enum WorkerPaymentStage { notRequested, pending, processing, paid, failed }
enum WorkerExtraApprovalStage { selected, pending, approved, rejected }

@immutable
class WorkerExtraSnapshot {
  const WorkerExtraSnapshot({
    required this.id,
    required this.name,
    required this.customerPrice,
    required this.durationMinutes,
    this.approval = WorkerExtraApprovalStage.selected,
  });

  final String id;
  final String name;
  final int customerPrice;
  final int durationMinutes;
  final WorkerExtraApprovalStage approval;

  Map<String, Object?> toJson() => {
        'id': id, 'name': name, 'customerPrice': customerPrice,
        'durationMinutes': durationMinutes, 'approval': approval.name,
      };

  factory WorkerExtraSnapshot.fromJson(Map<String, dynamic> json) =>
      WorkerExtraSnapshot(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        customerPrice: _requiredNonNegativeInt(json, 'customerPrice'),
        durationMinutes: _requiredNonNegativeInt(json, 'durationMinutes'),
        approval: _readEnum(WorkerExtraApprovalStage.values,
            _requiredString(json, 'approval')),
      );
}

@immutable
class WorkerBookingSession {
  const WorkerBookingSession({
    required this.bookingId,
    required this.baseCustomerPayable,
    this.serviceStage = WorkerServiceStage.notStarted,
    this.paymentStage = WorkerPaymentStage.notRequested,
    this.startedAt,
    this.finishedAt,
    this.demoPaidAt,
    this.extras = const [],
  });

  final String bookingId;
  /// Snapshot of customer base amount, not worker earnings.
  final int baseCustomerPayable;
  final WorkerServiceStage serviceStage;
  /// Only the backend may eventually set this to `paid`.
  final WorkerPaymentStage paymentStage;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  /// Separate demo marker. Does not change paymentStage to `paid`.
  final DateTime? demoPaidAt;
  final List<WorkerExtraSnapshot> extras;

  int get demoCustomerTotal => baseCustomerPayable +
      extras.where((e) => e.approval != WorkerExtraApprovalStage.rejected)
          .fold<int>(0, (sum, e) => sum + e.customerPrice);

  WorkerBookingSession copyWith({
    WorkerServiceStage? serviceStage,
    WorkerPaymentStage? paymentStage,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? demoPaidAt,
    List<WorkerExtraSnapshot>? extras,
  }) => WorkerBookingSession(
        bookingId: bookingId,
        baseCustomerPayable: baseCustomerPayable,
        serviceStage: serviceStage ?? this.serviceStage,
        paymentStage: paymentStage ?? this.paymentStage,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        demoPaidAt: demoPaidAt ?? this.demoPaidAt,
        extras: extras ?? this.extras,
      );

  Map<String, Object?> toJson() => {
        'bookingId': bookingId,
        'baseCustomerPayable': baseCustomerPayable,
        'serviceStage': serviceStage.name,
        'paymentStage': paymentStage.name,
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'finishedAt': finishedAt?.toUtc().toIso8601String(),
        'demoPaidAt': demoPaidAt?.toUtc().toIso8601String(),
        'extras': extras.map((e) => e.toJson()).toList(),
      };

  factory WorkerBookingSession.fromJson(Map<String, dynamic> json) {
    final rawExtras = json['extras'];
    if (rawExtras is! List) throw const FormatException('Invalid extras list');
    return WorkerBookingSession(
      bookingId: _requiredString(json, 'bookingId'),
      baseCustomerPayable: _requiredNonNegativeInt(json, 'baseCustomerPayable'),
      serviceStage: _readEnum(WorkerServiceStage.values,
          _requiredString(json, 'serviceStage')),
      paymentStage: _readEnum(WorkerPaymentStage.values,
          _requiredString(json, 'paymentStage')),
      startedAt: _readDate(json['startedAt']),
      finishedAt: _readDate(json['finishedAt']),
      demoPaidAt: _readDate(json['demoPaidAt']),
      extras: List.unmodifiable(rawExtras.map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Invalid extra item');
        }
        return WorkerExtraSnapshot.fromJson(value);
      })),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException('Invalid $key');
  return value;
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw FormatException('Invalid $key');
  return value;
}

T _readEnum<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown enum value: $name');
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Invalid timestamp');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException('Invalid timestamp');
  return parsed;
}
