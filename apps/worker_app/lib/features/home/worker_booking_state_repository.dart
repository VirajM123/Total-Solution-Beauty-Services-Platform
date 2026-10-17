import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'worker_booking_session.dart';

/// Storage seam: a future API repository can implement the same workflow API.
abstract interface class WorkerBookingSessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

/// This key stores DEMO booking state only, isolated from registration drafts.
class SecureDemoBookingStorage implements WorkerBookingSessionStorage {
  SecureDemoBookingStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'pinkora.worker.demo_booking_sessions.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: key);
}

class WorkerBookingStateException implements Exception {
  const WorkerBookingStateException(this.message);
  final String message;
  @override
  String toString() => 'WorkerBookingStateException: $message';
}

/// Debug-only, listenable booking-session state. No payment or OTP authorization.
/// Instantiate once at the app's composition root in a later integration step.
class WorkerBookingStateRepository extends ChangeNotifier {
  WorkerBookingStateRepository(this._storage, {required this.demoMode});

  final WorkerBookingSessionStorage _storage;
  final bool demoMode;
  Map<String, WorkerBookingSession> _sessions = {};
  bool _initialized = false;
  bool _busy = false;

  bool get isInitialized => _initialized;
  List<WorkerBookingSession> get sessions =>
      List.unmodifiable(_sessions.values);
  WorkerBookingSession? byId(String bookingId) => _sessions[bookingId];
  bool get hasActivePhysicalService => _sessions.values.any(
      (session) => session.serviceStage == WorkerServiceStage.inProgress);

  void _ensureReady() {
    if (!kDebugMode || !demoMode) {
      throw const WorkerBookingStateException('Demo repository is unavailable in release mode');
    }
    if (!_initialized) {
      throw const WorkerBookingStateException('Booking repository has not loaded');
    }
    if (_busy) {
      throw const WorkerBookingStateException('Another booking operation is in progress');
    }
  }

  Future<void> initialize() async {
    if (!kDebugMode || !demoMode) {
      throw const WorkerBookingStateException('Demo repository is unavailable in release mode');
    }
    if (_initialized) return;
    if (_busy) throw const WorkerBookingStateException('Repository is busy');
    _busy = true;
    try {
      final raw = await _storage.read();
      final restored = <String, WorkerBookingSession>{};
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> || decoded['version'] != 1 ||
            decoded['sessions'] is! List) {
          throw const FormatException('Unknown booking session format');
        }
        for (final item in decoded['sessions'] as List) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid booking session entry');
          }
          final session = WorkerBookingSession.fromJson(item);
          if (restored.containsKey(session.bookingId)) {
            throw const FormatException('Duplicate booking session ID');
          }
          restored[session.bookingId] = session;
        }
      }
      _sessions = restored;
      _initialized = true;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<WorkerBookingSession> _commit(WorkerBookingSession candidate) async {
    _ensureReady();
    _busy = true;
    try {
      final next = Map<String, WorkerBookingSession>.of(_sessions)
        ..[candidate.bookingId] = candidate;
      final encoded = jsonEncode({
        'version': 1,
        'sessions': next.values.map((s) => s.toJson()).toList(),
      });
      // Persist first; do not show a successful transition if storage fails.
      await _storage.write(encoded);
      _sessions = next;
      notifyListeners();
      return candidate;
    } finally {
      _busy = false;
    }
  }

  Future<WorkerBookingSession> startService({
    required String bookingId,
    required int baseCustomerPayable,
    required bool otpVerifiedInPreview,
    DateTime? at,
  }) {
    _ensureReady();
    if (!otpVerifiedInPreview) {
      throw const WorkerBookingStateException('OTP verification is required');
    }
    if (bookingId.isEmpty || baseCustomerPayable < 0) {
      throw const WorkerBookingStateException('Invalid booking details');
    }
    if (hasActivePhysicalService) {
      throw const WorkerBookingStateException('Another service is already in progress');
    }
    if (_sessions.containsKey(bookingId)) {
      throw const WorkerBookingStateException('This booking has already started');
    }
    return _commit(WorkerBookingSession(
      bookingId: bookingId,
      baseCustomerPayable: baseCustomerPayable,
      serviceStage: WorkerServiceStage.inProgress,
      startedAt: at ?? DateTime.now(),
    ));
  }

  Future<WorkerBookingSession> updateExtras({
    required String bookingId,
    required List<WorkerExtraSnapshot> extras,
  }) {
    _ensureReady();
    final old = _sessions[bookingId];
    if (old == null || old.serviceStage != WorkerServiceStage.inProgress) {
      throw const WorkerBookingStateException('No active service for this booking');
    }
    final ids = extras.map((e) => e.id).toSet();
    if (ids.length != extras.length || extras.any((e) => e.customerPrice < 0)) {
      throw const WorkerBookingStateException('Invalid or duplicate extra services');
    }
    return _commit(old.copyWith(extras: List.unmodifiable(extras)));
  }

  Future<WorkerBookingSession> finishService({
    required String bookingId,
    DateTime? at,
  }) {
    _ensureReady();
    final old = _sessions[bookingId];
    if (old == null || old.serviceStage != WorkerServiceStage.inProgress) {
      throw const WorkerBookingStateException('Booking is not in progress');
    }
    final finishedAt = at ?? DateTime.now();
    if (old.startedAt != null && finishedAt.isBefore(old.startedAt!)) {
      throw const WorkerBookingStateException('Finish time precedes start time');
    }
    return _commit(old.copyWith(
      serviceStage: WorkerServiceStage.finished,
      paymentStage: WorkerPaymentStage.pending,
      finishedAt: finishedAt,
    ));
  }

  /// Local visual marker only. Never sets the authoritative paymentStage to paid.
  Future<WorkerBookingSession> simulatePayment({
    required String bookingId,
    DateTime? at,
  }) {
    _ensureReady();
    final old = _sessions[bookingId];
    if (old == null || old.serviceStage != WorkerServiceStage.finished) {
      throw const WorkerBookingStateException('Service must be finished first');
    }
    if (old.demoPaidAt != null) {
      throw const WorkerBookingStateException('Demo payment already simulated');
    }
    return _commit(old.copyWith(demoPaidAt: at ?? DateTime.now()));
  }

  /// Used only to explicitly reset DEMO fixtures, never on routine app startup.
  Future<void> clearDemoSessions() async {
    _ensureReady();
    _busy = true;
    try {
      await _storage.clear();
      _sessions = {};
      notifyListeners();
    } finally {
      _busy = false;
    }
  }
}
