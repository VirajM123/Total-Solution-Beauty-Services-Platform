/// Domain seams only. No wire format or URL is assumed until worker contracts
/// exist. Implementations must return server records and enforce worker scope.
enum WorkerApproval { pending, approved, rejected, suspended }

enum WorkerJobAction {
  accept,
  reject,
  startTravel,
  arrive,
  startService,
  complete,
}

enum CollectionMethod { cash, upi }

enum CollectionStatus { pending, verified }

class WorkerIntegrationPending implements Exception {
  const WorkerIntegrationPending(this.feature);
  final String feature;
  @override
  String toString() =>
      '$feature is unavailable until the worker backend contract is implemented.';
}

class WorkerIdentity {
  const WorkerIdentity({required this.workerId, required this.approval});
  final String workerId;
  final WorkerApproval approval;
  bool get mayWork => approval == WorkerApproval.approved;
}

class WorkerPage<T> {
  WorkerPage({
    required List<T> items,
    required this.page,
    required this.hasMore,
  }) : items = List.unmodifiable(items);
  final List<T> items;
  final int page;
  final bool hasMore;
}

class WorkerAssignmentRecord {
  const WorkerAssignmentRecord({
    required this.id,
    required this.bookingId,
    required this.status,
    required this.expiresAt,
  });
  final String id;
  final String bookingId;
  final String status;
  final DateTime? expiresAt;
}

class WorkerCollectionRecord {
  const WorkerCollectionRecord({
    required this.bookingId,
    required this.amountDuePaise,
    required this.status,
  });
  final String bookingId;
  final int amountDuePaise;
  final CollectionStatus status;
}

/// No mutation method exists: only Admin may settle worker payouts.
class WorkerSettlementRecord {
  const WorkerSettlementRecord({
    required this.id,
    required this.settlementDate,
    required this.bookingCount,
    required this.earningsPaise,
    required this.adjustmentsPaise,
    required this.netPaise,
    required this.status,
    this.reference,
  });
  final String id;
  final DateTime settlementDate;
  final int bookingCount;
  final int earningsPaise;
  final int adjustmentsPaise;
  final int netPaise;
  final String status;
  final String? reference;
}

abstract interface class WorkerAuthApi {
  Future<void> requestOtp(String indianMobile);
  Future<WorkerIdentity> verifyOtp(String indianMobile, String otp);
  Future<WorkerIdentity> currentIdentity();
  Future<void> logout();
}

abstract interface class WorkerOperationsApi {
  Future<WorkerPage<WorkerAssignmentRecord>> assignments({int page = 1});
  Future<WorkerAssignmentRecord> transition({
    required String assignmentId,
    required WorkerJobAction action,
    required String idempotencyKey,
    String? rejectionReason,
    String? arrivalOtp,
  });
  Future<bool> availability();
  Future<bool> updateAvailability(bool online);
  Future<WorkerCollectionRecord> collection(String bookingId);
  Future<WorkerCollectionRecord> recordCash({
    required String bookingId,
    required String idempotencyKey,
  });
  Future<WorkerPage<WorkerSettlementRecord>> settlements({int page = 1});
}

/// Composition-root default until authenticated worker routes are available.
/// Never redirects to Admin routes or substitutes local demo records.
class PendingWorkerApi implements WorkerAuthApi, WorkerOperationsApi {
  const PendingWorkerApi();
  Future<T> _pending<T>(String feature) =>
      Future<T>.error(WorkerIntegrationPending(feature));
  @override
  Future<void> requestOtp(String indianMobile) => _pending('Worker OTP');
  @override
  Future<WorkerIdentity> verifyOtp(String indianMobile, String otp) =>
      _pending('Worker OTP verification');
  @override
  Future<WorkerIdentity> currentIdentity() =>
      _pending('Worker session and approval');
  @override
  Future<void> logout() => _pending('Worker session revocation');
  @override
  Future<WorkerPage<WorkerAssignmentRecord>> assignments({int page = 1}) =>
      _pending('Worker assignments');
  @override
  Future<WorkerAssignmentRecord> transition({
    required String assignmentId,
    required WorkerJobAction action,
    required String idempotencyKey,
    String? rejectionReason,
    String? arrivalOtp,
  }) => _pending('Assignment transition');
  @override
  Future<bool> availability() => _pending('Worker availability');
  @override
  Future<bool> updateAvailability(bool online) =>
      _pending('Worker availability update');
  @override
  Future<WorkerCollectionRecord> collection(String bookingId) =>
      _pending('Customer collection status');
  @override
  Future<WorkerCollectionRecord> recordCash({
    required String bookingId,
    required String idempotencyKey,
  }) => _pending('Authorized cash collection');
  @override
  Future<WorkerPage<WorkerSettlementRecord>> settlements({int page = 1}) =>
      _pending('Worker settlements');
}
