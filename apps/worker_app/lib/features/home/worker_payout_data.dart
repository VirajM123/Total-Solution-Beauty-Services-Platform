import 'package:flutter/foundation.dart';
import '../../integration/worker_mobile_operations_api.dart';

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


class WorkerBackendPayoutRepository extends WorkerPayoutRepository {
  WorkerBackendPayoutRepository({WorkerMobileOperationsApi? operationsApi})
      : _api = operationsApi ?? WorkerMobileOperationsApi();

  final WorkerMobileOperationsApi _api;
  WorkerPayoutLoadStatus _loadStatus = WorkerPayoutLoadStatus.idle;
  Object? _error;
  List<WorkerPayoutRecord> _records = const [];

  @override
  WorkerPayoutLoadStatus get loadStatus => _loadStatus;

  @override
  Object? get error => _error;

  @override
  List<WorkerPayoutRecord> get records => _records;

  @override
  Future<void> refresh() async {
    _loadStatus = WorkerPayoutLoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final list = await _api.fetchSettlements();
      final parsed = <WorkerPayoutRecord>[];
      for (final doc in list) {
        final id = '${doc['_id'] ?? ''}';
        final reference = doc['reference'] as String?;
        final payoutId = (reference != null && reference.isNotEmpty)
            ? reference
            : (id.length >= 8 ? id.substring(id.length - 8).toUpperCase() : id);

        final earningsPaise = doc['earningsPaise'] is num
            ? (doc['earningsPaise'] as num).toInt()
            : 0;
        final compPaidPaise = doc['compensationPaidPaise'] is num
            ? (doc['compensationPaidPaise'] as num).toInt()
            : 0;
        final paise = compPaidPaise > 0 ? compPaidPaise : earningsPaise;
        final amountRupees = (paise / 100).round();

        final rawStatus = '${doc['status'] ?? 'pending'}'.toLowerCase().trim();
        final status = switch (rawStatus) {
          'paid' => WorkerPayoutStatus.paid,
          'approved' => WorkerPayoutStatus.paid,
          'pending' => WorkerPayoutStatus.pending,
          _ => WorkerPayoutStatus.adjusted,
        };

        DateTime date = DateTime.now();
        if (doc['date'] != null) {
          date = DateTime.tryParse('${doc['date']}') ?? date;
        } else if (doc['settledAt'] != null) {
          date = DateTime.tryParse('${doc['settledAt']}') ?? date;
        } else if (doc['createdAt'] != null) {
          date = DateTime.tryParse('${doc['createdAt']}') ?? date;
        }

        final serviceCount = (doc['serviceCount'] is num)
            ? (doc['serviceCount'] as num).toInt()
            : 1;

        parsed.add(
          WorkerPayoutRecord(
            id: id,
            payoutId: payoutId,
            amountRupees: amountRupees,
            serviceCount: serviceCount,
            date: date,
            status: status,
          ),
        );
      }
      _records = List.unmodifiable(parsed);
      _loadStatus = WorkerPayoutLoadStatus.loaded;
    } catch (e) {
      _error = e;
      _loadStatus = WorkerPayoutLoadStatus.error;
    }
    notifyListeners();
  }
}
