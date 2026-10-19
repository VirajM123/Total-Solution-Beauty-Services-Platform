import 'package:flutter/foundation.dart';

enum WorkerPayoutStatus { paid, pending, adjusted }

enum WorkerPayoutLoadStatus { idle, loading, loaded, error }

@immutable
class WorkerPayoutRecord {
  const WorkerPayoutRecord({
    required this.id,
    required this.payoutId,
    required this.amountRupees,
    required this.serviceCount,
    required this.date,
    required this.status,
  }) : assert(amountRupees >= 0),
       assert(serviceCount >= 0);

  final String id;
  final String payoutId;
  final int amountRupees;
  final int serviceCount;
  final DateTime date;
  final WorkerPayoutStatus status;
}

/// Worker-scoped source for administrator-issued payout records.
///
/// Implementations must only publish values returned by an authoritative
/// payout service. Booking customer-payable amounts are never payout data.
abstract class WorkerPayoutRepository extends ChangeNotifier {
  WorkerPayoutLoadStatus get loadStatus;
  Object? get error;
  List<WorkerPayoutRecord> get records;

  Future<void> refresh();
}
