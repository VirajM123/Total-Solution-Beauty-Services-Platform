import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../integration/worker_mobile_operations_api.dart';
import 'worker_booking_data.dart';

@immutable
class WorkerNotificationItem {
  const WorkerNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.group,
    required this.type,
    this.entityId,
    this.isRead = false,
    required this.createdAt,
    required this.icon,
    this.order,
  });

  final String id;
  final String title;
  final String message;
  final String group;
  final String type;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;
  final IconData icon;
  final WorkerDashboardOrder? order;

  WorkerNotificationItem copyWith({
    bool? isRead,
    String? title,
    String? message,
    WorkerDashboardOrder? order,
  }) => WorkerNotificationItem(
    id: id,
    title: title ?? this.title,
    message: message ?? this.message,
    group: group,
    type: type,
    entityId: entityId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    icon: icon,
    order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'group': group,
    'type': type,
    'entityId': entityId,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WorkerNotificationItem.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?) ?? 'general';
    return WorkerNotificationItem(
      id: (json['id'] as String?) ?? '${DateTime.now().millisecondsSinceEpoch}',
      title: (json['title'] as String?) ?? 'Alert',
      message: (json['message'] as String?) ?? '',
      group: (json['group'] as String?) ?? 'Updates',
      type: type,
      entityId: json['entityId'] as String?,
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      icon: _iconForType(type),
    );
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  factory WorkerNotificationItem.fromServerMap(Map<String, dynamic> map) {
    final type = '${map['type'] ?? 'general'}';
    final entityId = map['entityId'] as String?;
    final isRead = map['isRead'] == true;
    final createdAt =
        DateTime.tryParse('${map['createdAt']}') ?? DateTime.now();
    final meta = _metaForType(type, entityId);
    final title = (map['title'] as String?)?.isNotEmpty == true
        ? map['title'] as String
        : meta.title;
    final message = (map['message'] as String?)?.isNotEmpty == true
        ? map['message'] as String
        : meta.message;

    return WorkerNotificationItem(
      id: '${map['_id'] ?? map['id'] ?? DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      group: meta.group,
      type: type,
      entityId: entityId,
      isRead: isRead,
      createdAt: createdAt,
      icon: meta.icon,
    );
  }

  static IconData _iconForType(String type) => _metaForType(type, null).icon;

  static ({String title, String message, String group, IconData icon}) _metaForType(
    String type,
    String? entityId,
  ) {
    switch (type) {
      case 'assignment.offered':
        return (
          title: 'New Service Request',
          message:
              'A new client appointment offer is waiting for your confirmation.',
          group: 'Bookings',
          icon: Icons.bolt_rounded,
        );
      case 'assignment.expired':
        return (
          title: 'Offer Expired',
          message:
              'A booking offer was not accepted in time and has been reassigned.',
          group: 'Updates',
          icon: Icons.timer_off_outlined,
        );
      case 'assignment.revoked':
        return (
          title: 'Booking Assigned Elsewhere',
          message:
              'The booking was reassigned to another available specialist.',
          group: 'Updates',
          icon: Icons.event_busy_rounded,
        );
      case 'worker.approved':
        return (
          title: 'Profile Approved! 🎉',
          message:
              'Congratulations! Your professional partner account is approved.',
          group: 'Updates',
          icon: Icons.verified_rounded,
        );
      case 'worker.rejected':
        return (
          title: 'Partner Application Notice',
          message:
              'Your partner documents need review. Please contact administration.',
          group: 'Updates',
          icon: Icons.error_outline_rounded,
        );
      case 'booking.confirmed':
        return (
          title: 'Booking Confirmed',
          message: 'Client appointment confirmed and added to your schedule.',
          group: 'Bookings',
          icon: Icons.event_available_rounded,
        );
      case 'booking.completed':
        return (
          title: 'Service Completed ✅',
          message: 'The beauty service has been marked completed successfully.',
          group: 'Bookings',
          icon: Icons.task_alt_rounded,
        );
      case 'booking.cancelled':
        return (
          title: 'Booking Cancelled',
          message: 'A client booking was cancelled.',
          group: 'Bookings',
          icon: Icons.event_busy_rounded,
        );
      case 'settlement.completed':
      case 'settlement.created':
        return (
          title: 'Payout Processed 💰',
          message:
              'A compensation payout settlement was recorded by administration.',
          group: 'Updates',
          icon: Icons.account_balance_wallet_outlined,
        );
      case 'leave.approved':
        return (
          title: 'Leave Approved 🏖️',
          message: 'Your leave request has been approved by the salon team.',
          group: 'Updates',
          icon: Icons.event_available_rounded,
        );
      case 'leave.rejected':
        return (
          title: 'Leave Request Declined',
          message: 'Your leave request could not be approved at this time.',
          group: 'Updates',
          icon: Icons.event_busy_rounded,
        );
      default:
        return (
          title: 'System Notification',
          message: 'Activity update from Hii Beauty platform.',
          group: 'Updates',
          icon: Icons.notifications_active_outlined,
        );
    }
  }

  factory WorkerNotificationItem.fromOrder(WorkerDashboardOrder order) {
    final status = order.status.trim().toLowerCase();
    if (status == 'completed' || status == 'demo completed') {
      return WorkerNotificationItem(
        id: '${order.id}:$status',
        order: order,
        title: 'Service completed',
        message: '${order.service} for ${order.customer} is marked completed.',
        group: 'Updates',
        type: 'booking.completed',
        isRead: false,
        createdAt: order.appointmentDate ?? DateTime.now(),
        icon: Icons.task_alt_rounded,
      );
    }
    if (status == 'cancelled' || status == 'canceled' || status == 'rejected') {
      return WorkerNotificationItem(
        id: '${order.id}:$status',
        order: order,
        title: 'Booking cancelled',
        message: '${order.service} for ${order.customer} is marked $status.',
        group: 'Updates',
        type: 'booking.cancelled',
        isRead: false,
        createdAt: order.appointmentDate ?? DateTime.now(),
        icon: Icons.event_busy_rounded,
      );
    }
    if (status == 'in progress' ||
        status == 'ongoing' ||
        status == 'payment pending') {
      return WorkerNotificationItem(
        id: '${order.id}:$status',
        order: order,
        title: status == 'payment pending'
            ? 'Payment pending'
            : 'Service in progress',
        message: '${order.service} for ${order.customer} · ${order.time}.',
        group: 'Updates',
        type: 'booking.in_progress',
        isRead: false,
        createdAt: order.appointmentDate ?? DateTime.now(),
        icon: Icons.access_time_rounded,
      );
    }
    return WorkerNotificationItem(
      id: '${order.id}:$status',
      order: order,
      title: 'Booking ${order.status}',
      message: '${order.service} for ${order.customer} · ${order.time}.',
      group: 'Bookings',
      type: 'booking.${order.status.toLowerCase()}',
      isRead: false,
      createdAt: order.appointmentDate ?? DateTime.now(),
      icon: Icons.calendar_today_rounded,
    );
  }
}

abstract interface class WorkerNotificationStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureWorkerNotificationStorage implements WorkerNotificationStorage {
  SecureWorkerNotificationStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class WorkerNotificationRepository extends ChangeNotifier {
  WorkerNotificationRepository({
    WorkerNotificationStorage? storage,
    WorkerMobileOperationsApi? operationsApi,
    List<WorkerDashboardOrder>? initialOrders,
  }) : _storage = storage ?? SecureWorkerNotificationStorage(),
       _operationsApi = operationsApi {
    if (initialOrders != null && initialOrders.isNotEmpty) {
      _items = initialOrders
          .map(WorkerNotificationItem.fromOrder)
          .toList(growable: true);
    }
  }

  final WorkerNotificationStorage _storage;
  WorkerMobileOperationsApi? _operationsApi;

  List<WorkerNotificationItem> _items = [];
  bool _isLoading = false;
  bool _isOffline = false;
  static const _cacheKey = 'hii_beauty.worker.notifications.v1';

  List<WorkerNotificationItem> get notifications => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  int get unreadCount => _items.where((item) => !item.isRead).length;

  void setOperationsApi(WorkerMobileOperationsApi? api) {
    _operationsApi = api;
  }

  Future<void> load({
    List<WorkerDashboardOrder>? fallbackOrders,
  }) async {
    _isLoading = true;
    notifyListeners();

    // 1. Instant local cache load (0 ms offline resilience)
    try {
      final cachedRaw = await _storage.read(_cacheKey);
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        final decoded = jsonDecode(cachedRaw);
        if (decoded is List) {
          _items = decoded
              .whereType<Map<String, dynamic>>()
              .map(WorkerNotificationItem.fromJson)
              .toList(growable: true);
          notifyListeners();
        }
      }
    } catch (_) {}

    // 2. Server revalidation if operationsApi is connected
    if (_operationsApi != null) {
      try {
        final serverList = await _operationsApi!.fetchNotifications();
        if (serverList.isNotEmpty) {
          final mapped = serverList
              .map(WorkerNotificationItem.fromServerMap)
              .toList(growable: true);

          // If fallbackOrders were provided, associate matching orders
          if (fallbackOrders != null && fallbackOrders.isNotEmpty) {
            for (var i = 0; i < mapped.length; i++) {
              final item = mapped[i];
              if (item.entityId != null) {
                final match = fallbackOrders.firstWhere(
                  (o) => o.id == item.entityId,
                  orElse: () => fallbackOrders.first,
                );
                mapped[i] = item.copyWith(order: match);
              }
            }
          }

          _items = mapped;
          _isOffline = false;
          _saveCache(_items);
          _isLoading = false;
          notifyListeners();
          return;
        } else {
          _isOffline = false;
          if (fallbackOrders == null || fallbackOrders.isEmpty) {
            _items = [];
            _saveCache(_items);
          }
        }
      } catch (_) {
        // Offline / network failure: retain cached items gracefully
        _isOffline = true;
      }
    }

    // 3. Fallback to derived orders if cache and server are empty
    if (_items.isEmpty && fallbackOrders != null && fallbackOrders.isNotEmpty) {
      _items = fallbackOrders
          .map(WorkerNotificationItem.fromOrder)
          .toList(growable: true);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1 || _items[index].isRead) return;

    final updated = _items[index].copyWith(isRead: true);
    _items[index] = updated;
    notifyListeners();

    _saveCache(_items);

    if (_operationsApi != null && !id.contains(':')) {
      await _operationsApi!.markNotificationAsRead(id).catchError((_) => false);
    }
  }

  Future<void> markAllAsRead() async {
    if (_items.every((item) => item.isRead)) return;

    _items = _items
        .map((item) => item.copyWith(isRead: true))
        .toList(growable: true);
    notifyListeners();

    _saveCache(_items);

    if (_operationsApi != null) {
      await _operationsApi!.markAllNotificationsAsRead().catchError((_) => false);
    }
  }

  void _saveCache(List<WorkerNotificationItem> items) {
    try {
      unawaited(
        _storage
            .write(
              _cacheKey,
              jsonEncode(items.map((i) => i.toJson()).toList(growable: false)),
            )
            .catchError((_) {}),
      );
    } catch (_) {}
  }
}
