import 'package:flutter/foundation.dart';

import 'worker_booking_data.dart';
import 'worker_booking_session.dart';
import 'worker_booking_state_repository.dart';

/// Debug-only composition point, shared across Dashboard, List and Details.
/// A production API-backed implementation will replace this provider later.
class WorkerDemoBookingStore {
  WorkerDemoBookingStore._();
  static final WorkerBookingStateRepository repository =
      WorkerBookingStateRepository(SecureDemoBookingStorage(), demoMode: true);
  static Future<void>? _loading;

  static List<WorkerDashboardOrder> get bookings => repository.bookings;

  static Future<void> initialize() {
    if (!kDebugMode) return Future<void>.value();
    return _loading ??= repository.initialize().catchError((Object error) {
      _loading = null; // Permit retry; never silently discard corrupted data.
      throw error;
    });
  }

  static WorkerBookingSession? session(String id) =>
      repository.isInitialized ? repository.byId(id) : null;

  static String displayStatus(WorkerDashboardOrder order) {
    if (!kDebugMode) return order.status;
    final s = session(order.id);
    if (s == null) return order.status;
    if (s.demoPaidAt != null) return 'Demo Completed';
    if (s.serviceStage == WorkerServiceStage.finished) return 'Payment Pending';
    if (s.serviceStage == WorkerServiceStage.inProgress) return 'In Progress';
    return order.status;
  }

  static WorkerDashboardOrder resolve(WorkerDashboardOrder order) =>
      order.copyWith(status: displayStatus(order));

  static List<WorkerDashboardOrder> resolveAll(
    List<WorkerDashboardOrder> orders,
  ) => List.unmodifiable(orders.map(resolve));
}
