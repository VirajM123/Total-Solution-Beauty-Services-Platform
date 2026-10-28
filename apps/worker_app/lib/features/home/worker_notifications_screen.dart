import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../integration/worker_mobile_operations_api.dart';
import 'worker_booking_data.dart';
import 'worker_demo_booking_store.dart';
import 'worker_notification_repository.dart';
import '../widgets/worker_design.dart';

const _pink = WorkerDesign.pink;
const _deep = WorkerDesign.deep;
const _muted = WorkerDesign.muted;
const _border = WorkerDesign.border;
const _cream = WorkerDesign.cream;

/// Production-ready In-App Notifications Feed for Worker App.
/// Supports live server notifications, instant offline caching, pull-to-refresh,
/// "Hide seen" toggling, and granular read-status synchronization.
class WorkerNotificationsScreen extends StatefulWidget {
  const WorkerNotificationsScreen({
    super.key,
    required this.orders,
    this.onBookingTap,
    this.demoMode = true,
    this.repository,
    this.operationsApi,
  });

  final List<WorkerDashboardOrder> orders;
  final ValueChanged<WorkerDashboardOrder>? onBookingTap;
  final bool demoMode;
  final WorkerNotificationRepository? repository;
  final WorkerMobileOperationsApi? operationsApi;

  @override
  State<WorkerNotificationsScreen> createState() =>
      _WorkerNotificationsScreenState();
}

class _WorkerNotificationsScreenState extends State<WorkerNotificationsScreen> {
  late final WorkerNotificationRepository _repository;
  bool _ownsRepository = false;
  String _filter = 'All';
  bool _hideSeen = false;
  final Set<String> _readIds = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository!;
    } else {
      _repository = WorkerNotificationRepository(
        operationsApi: widget.operationsApi,
        initialOrders: widget.orders,
      );
      _ownsRepository = true;
    }
    _repository.addListener(_onRepositoryChanged);

    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.addListener(_onBookingsChanged);
    }

    _load();
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.removeListener(_onBookingsChanged);
    }
    if (_ownsRepository) {
      _repository.dispose();
    }
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  void _onBookingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _repository.load(fallbackOrders: widget.orders);
  }

  List<WorkerNotificationItem> get _alerts {
    if (_repository.notifications.isNotEmpty) {
      return _repository.notifications;
    }
    return (widget.demoMode && WorkerDemoBookingStore.repository.isInitialized
            ? WorkerDemoBookingStore.resolveAll(widget.orders)
            : widget.orders)
        .map(WorkerNotificationItem.fromOrder)
        .toList(growable: false);
  }

  List<WorkerNotificationItem> get _visible => _alerts.where((item) {
    final isRead = item.isRead || _readIds.contains(item.id);
    if (_hideSeen && isRead) return false;
    if (_filter == 'Unread') return !isRead;
    if (_filter == 'Bookings') return item.group == 'Bookings';
    if (_filter == 'Updates') return item.group == 'Updates';
    return true;
  }).toList(growable: false);

  int get _unreadCount =>
      _alerts.where((a) => !a.isRead && !_readIds.contains(a.id)).length;

  void _open(WorkerNotificationItem alert) {
    setState(() => _readIds.add(alert.id));
    _repository.markAsRead(alert.id);

    WorkerDashboardOrder? order = alert.order;
    if (order == null && alert.entityId != null) {
      final matches = widget.orders.where((o) => o.id == alert.entityId);
      if (matches.isNotEmpty) {
        order = matches.first;
      }
    }

    if (order != null && widget.onBookingTap != null) {
      widget.onBookingTap!(order);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alert.order != null
                ? 'Booking details are not connected for this preview.'
                : 'Alert marked as read: ${alert.title}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _markAllRead() {
    setState(() {
      for (final a in _alerts) {
        _readIds.add(a.id);
      }
    });
    _repository.markAllAsRead();
  }

  Widget _buildStatusBanner() {
    if (_repository.isOffline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 15,
              color: Color(0xFF6B7280),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offline mode · Showing saved alerts. Pull down to refresh.',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF374151),
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.demoMode) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDF3),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: _pink,
            ),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Preview alerts from bookings. Push notifications and a server inbox are not connected.',
                style: TextStyle(
                  fontSize: 10,
                  color: _deep,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_repository.notifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.verified_outlined,
            size: 15,
            color: Color(0xFF16A34A),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Live production inbox · Synced with salon backend.',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF166534),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _unreadCount;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: _deep,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: unread == 0 ? null : _markAllRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: _pink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: RefreshIndicator(
              color: _pink,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                children: [
                  const WorkerPageBanner(
                    eyebrow: 'Stay in the loop',
                    title: 'Your Alerts',
                    subtitle: 'Booking updates and activity in one place.',
                    icon: Icons.notifications_active_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBanner(),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Text(
                        'Your activity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _deep,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$unread unread',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _pink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...['All', 'Unread', 'Bookings', 'Updates'].map((
                          filter,
                        ) {
                          final active = _filter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              label: Text(filter),
                              visualDensity: const VisualDensity(
                                horizontal: -3,
                                vertical: -3,
                              ),
                              selected: active,
                              selectedColor: _pink,
                              backgroundColor: Colors.white,
                              side: BorderSide(color: active ? _pink : _border),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : _muted,
                              ),
                              showCheckmark: false,
                              onSelected: (_) {
                                HapticFeedback.lightImpact();
                                setState(() => _filter = filter);
                              },
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: FilterChip(
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_off_outlined,
                                  size: 13,
                                ),
                                SizedBox(width: 4),
                                Text('Hide seen'),
                              ],
                            ),
                            visualDensity: const VisualDensity(
                              horizontal: -3,
                              vertical: -3,
                            ),
                            selected: _hideSeen,
                            selectedColor: const Color(0xFFFFEDF3),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: _hideSeen ? _pink : _border,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _hideSeen ? _pink : _muted,
                            ),
                            showCheckmark: false,
                            onSelected: (val) {
                              HapticFeedback.lightImpact();
                              setState(() => _hideSeen = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (_visible.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 34,
                            color: _pink,
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'No notifications here',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _deep,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _filter == 'Unread' || _hideSeen
                                ? 'All visible alerts are marked as read.'
                                : 'Booking updates will appear here when available.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._visible.map(
                      (alert) {
                        final isRead =
                            alert.isRead || _readIds.contains(alert.id);
                        final bookingSubtitle = alert.order != null
                            ? 'Booking ${alert.order!.id}  ·  ${alert.group}'
                            : (alert.entityId != null &&
                                    alert.entityId!.isNotEmpty
                                ? 'Ref ${alert.entityId!.substring(0, alert.entityId!.length.clamp(0, 8))}  ·  ${alert.group}'
                                : alert.group);

                        return Padding(
                          key: ValueKey('alert-${alert.id}'),
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Material(
                            color: isRead
                                ? const Color(0xFFFAFAFA)
                                : Colors.white,
                            elevation: isRead ? 0 : 1,
                            shadowColor: const Color(0x12C74776),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _open(alert),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isRead
                                        ? const Color(0xFFE5E7EB)
                                        : _border,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? const Color(0xFFF3F4F6)
                                            : const Color(0xFFFFEDF3),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        alert.icon,
                                        color: isRead
                                            ? const Color(0xFF9CA3AF)
                                            : _pink,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  alert.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isRead
                                                        ? const Color(
                                                            0xFF4B5563,
                                                          )
                                                        : _deep,
                                                    fontSize: 12,
                                                    fontWeight: isRead
                                                        ? FontWeight.w600
                                                        : FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                alert.formattedTime,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: _muted,
                                                ),
                                              ),
                                              if (!isRead) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: _pink,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            alert.message,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: _muted,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            bookingSubtitle,
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: isRead
                                                  ? const Color(0xFF9CA3AF)
                                                  : _pink,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: _muted,
                                      size: 17,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
