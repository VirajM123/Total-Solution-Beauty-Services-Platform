import '../../integration/worker_api.dart';
import '../../integration/worker_mobile_operations_api.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum WorkerLeaveStatus { draft, pending, approved, rejected }

@immutable
class WorkerLeaveRequest {
  const WorkerLeaveRequest({
    required this.id,
    required this.from,
    required this.to,
    required this.reason,
    required this.createdAt,
    this.status = WorkerLeaveStatus.draft,
  });

  final String id;
  final DateTime from;
  final DateTime to;
  final String reason;
  final DateTime createdAt;
  final WorkerLeaveStatus status;

  Map<String, Object?> toJson() => {
    'id': id,
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory WorkerLeaveRequest.fromJson(Map<String, dynamic> json) {
    final status = WorkerLeaveStatus.values.where(
      (v) => v.name == json['status'],
    );
    if (json['id'] is! String || (json['id'] as String).isEmpty ||
        json['reason'] is! String || (json['reason'] as String).isEmpty ||
        json['from'] is! String || json['to'] is! String ||
        json['createdAt'] is! String || status.isEmpty) {
      throw const FormatException('Invalid demo leave request');
    }
    final from = DateTime.tryParse(json['from'] as String);
    final to = DateTime.tryParse(json['to'] as String);
    final created = DateTime.tryParse(json['createdAt'] as String);
    if (from == null || to == null || created == null || from.isAfter(to)) {
      throw const FormatException('Invalid leave dates');
    }
    return WorkerLeaveRequest(
      id: json['id'] as String,
      from: DateTime(from.year, from.month, from.day),
      to: DateTime(to.year, to.month, to.day),
      reason: json['reason'] as String,
      createdAt: created,
      status: status.first,
    );
  }
}

abstract interface class WorkerLeaveStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureDemoLeaveStorage implements WorkerLeaveStorage {
  SecureDemoLeaveStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  static const key = 'pinkora.worker.demo_leave_requests.v1';
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

class WorkerLeaveException implements Exception {
  const WorkerLeaveException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Local demo storage only; future API implementation can replace this adapter.
/// No fake admin approval or real worker leave is ever recorded.
class WorkerLeaveRepository extends ChangeNotifier {
  WorkerLeaveRepository(this._storage, {required this.demoMode});
  final WorkerLeaveStorage _storage;
  final bool demoMode;
  List<WorkerLeaveRequest> _requests = const [];
  bool _initialized = false;
  bool _busy = false;

  bool get isInitialized => _initialized;
  List<WorkerLeaveRequest> get requests => List.unmodifiable(_requests);

  void _ready() {
    if (!kDebugMode || !demoMode) {
      throw const WorkerLeaveException('Demo leave is unavailable in release mode');
    }
    if (!_initialized) throw const WorkerLeaveException('Leave requests not loaded');
    if (_busy) throw const WorkerLeaveException('Leave operation is already running');
  }

  Future<void> initialize() async {
    if (!kDebugMode || !demoMode) return;
    if (_initialized) return;
    if (_busy) throw const WorkerLeaveException('Leave repository busy');
    _busy = true;
    try {
      final raw = await _storage.read();
      final result = <WorkerLeaveRequest>[];
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> || decoded['version'] != 1 ||
            decoded['requests'] is! List) {
          throw const FormatException('Unrecognized leave storage format');
        }
        for (final item in decoded['requests'] as List) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid stored leave record');
          }
          result.add(WorkerLeaveRequest.fromJson(item));
        }
      }
      _requests = List.unmodifiable(result);
      _initialized = true;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool overlaps(DateTime from, DateTime to) => _requests.any((r) =>
      !day(from).isAfter(day(r.to)) && !day(to).isBefore(day(r.from)) &&
      r.status != WorkerLeaveStatus.rejected);

  Future<WorkerLeaveRequest> saveDraft({
    required DateTime from,
    required DateTime to,
    required String reason,
  }) async {
    _ready();
    final start = day(from);
    final end = day(to);
    if (start.isAfter(end) || reason.trim().isEmpty) {
      throw const WorkerLeaveException('Choose valid dates and a reason');
    }
    if (overlaps(start, end)) {
      throw const WorkerLeaveException('An overlapping leave request already exists');
    }
    _busy = true;
    try {
      final now = DateTime.now();
      final request = WorkerLeaveRequest(
        id: 'demo-${now.microsecondsSinceEpoch}',
        from: start, to: end, reason: reason.trim(), createdAt: now,
      );
      final next = [..._requests, request];
      // Never update the UI state unless persistence succeeds.
      await _storage.write(jsonEncode({
        'version': 1,
        'requests': next.map((r) => r.toJson()).toList(),
      }));
      _requests = List.unmodifiable(next);
      notifyListeners();
      return request;
    } finally {
      _busy = false;
    }
  }
}

class WorkerDemoLeaveStore {
  WorkerDemoLeaveStore._();
  static final WorkerLeaveRepository repository = WorkerLeaveRepository(
    SecureDemoLeaveStorage(), demoMode: true,
  );
  static Future<void>? _loading;
  static Future<void> initialize() {
    if (!kDebugMode) return Future<void>.value();
    return _loading ??= repository.initialize().catchError((Object error) {
      _loading = null;
      throw error;
    });
  }
}

class WorkerBackendLeaveRepository extends WorkerLeaveRepository {
  WorkerBackendLeaveRepository({
    WorkerOperationsApi? operationsApi,
  })  : _api = operationsApi is WorkerMobileOperationsApi
            ? operationsApi
            : WorkerMobileOperationsApi(),
        super(SecureDemoLeaveStorage(), demoMode: false);

  final WorkerMobileOperationsApi _api;
  bool _backendInitialized = false;

  @override
  bool get isInitialized => _backendInitialized;

  @override
  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final items = await _api.fetchLeaves();
      final parsed = <WorkerLeaveRequest>[];
      for (final doc in items) {
        final id = '${doc['_id'] ?? ''}';
        final reason = '${doc['reason'] ?? 'Personal'}';
        final startsAtStr = doc['startsAt'] as String?;
        final endsAtStr = doc['endsAt'] as String?;
        final createdAtStr = doc['createdAt'] as String?;
        final rawStatus = '${doc['status'] ?? 'pending'}'.toLowerCase().trim();

        final from = startsAtStr != null ? DateTime.tryParse(startsAtStr)?.toLocal() : null;
        final to = endsAtStr != null ? DateTime.tryParse(endsAtStr)?.toLocal() : null;
        final created = createdAtStr != null ? DateTime.tryParse(createdAtStr)?.toLocal() : null;

        if (from == null || to == null) continue;

        final status = switch (rawStatus) {
          'approved' => WorkerLeaveStatus.approved,
          'rejected' => WorkerLeaveStatus.rejected,
          _ => WorkerLeaveStatus.pending,
        };

        parsed.add(
          WorkerLeaveRequest(
            id: id,
            from: DateTime(from.year, from.month, from.day),
            to: DateTime(to.year, to.month, to.day),
            reason: reason,
            createdAt: created ?? from,
            status: status,
          ),
        );
      }
      _requests = List.unmodifiable(parsed);
      _backendInitialized = true;
      notifyListeners();
    } catch (_) {
      // Keep existing requests
    }
  }

  @override
  Future<WorkerLeaveRequest> saveDraft({
    required DateTime from,
    required DateTime to,
    required String reason,
  }) async {
    final start = DateTime(from.year, from.month, from.day, 9, 0);
    final end = DateTime(to.year, to.month, to.day, 18, 0);
    final response = await _api.submitLeaveRequest(
      startsAt: start,
      endsAt: end,
      reason: reason,
    );
    final id = '${response['_id'] ?? (response['leave'] is Map ? (response['leave'] as Map)['_id'] : '') ?? ''}';
    final request = WorkerLeaveRequest(
      id: id.isNotEmpty ? id : 'leave-${DateTime.now().microsecondsSinceEpoch}',
      from: from,
      to: to,
      reason: reason,
      createdAt: DateTime.now(),
      status: WorkerLeaveStatus.pending,
    );
    _requests = List.unmodifiable([request, ..._requests]);
    notifyListeners();
    return request;
  }
}
