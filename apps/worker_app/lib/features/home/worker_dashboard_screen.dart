import 'dart:io';

import 'package:flutter/material.dart';
import 'worker_booking_data.dart';
import 'worker_demo_booking_store.dart';
import 'worker_booking_session.dart';
import 'worker_bookings_screen.dart';
import 'worker_service_history_screen.dart';
import 'worker_profile_settings_screen.dart';
import 'worker_profile_data.dart';
import 'worker_notifications_screen.dart';
import 'worker_payout_data.dart';
import 'worker_payouts_screen.dart';
import 'worker_incoming_booking_screen.dart';
import 'worker_booking_details_screen.dart';
import '../../app/slide_page_route.dart';
import '../schedule/worker_schedule_leave_screen.dart';

// Preserve the original public model import path for existing callers.
export 'worker_booking_data.dart' show WorkerDashboardOrder;

// Pinkora worker dashboard — frontend preview only.
// Do not use this local toggle or sample booking data for production dispatch.
// Backend must enforce worker approval, online status and active-service locks.

const _pink = Color(0xFFF50070);
const _deep = Color(0xFF111D3A);
const _muted = Color(0xFF667085);
const _cream = Color(0xFFFFF7FA);
const _border = Color(0xFFF4DDE6);

const _upcomingStatuses = {
  'accepted',
  'assigned',
  'confirmed',
  'scheduled',
  'upcoming',
};

const _scheduleStatuses = {
  ..._upcomingStatuses,
  'arrived',
  'in progress',
  'in_progress',
  'ongoing',
  'service_started',
  'traveling',
  'travelling',
};

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    super.key,
    this.workerName = 'Worker',
    this.location = 'Your service area',
    this.workerPhone = '',
    this.profilePhotoPath,
    this.profileRepository,
    this.payoutRepository,
    this.isApproved = false,
    this.activeService = false,
    this.demoMode = true,
    this.orders,
    this.currentDate,
    this.onAvailabilityRequested,
    this.onOrderTap,
    this.onBookingsTap,
    this.onPayoutsTap,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onLogoutTap,
  });

  final String workerName;
  final String location;
  final String workerPhone;
  final String? profilePhotoPath;
  final WorkerProfileRepository? profileRepository;
  final WorkerPayoutRepository? payoutRepository;

  /// Must come from authenticated, backend-verified account state in production.
  final bool isApproved;

  /// Must come from server-side booking state in production.
  final bool activeService;

  /// Only true for development previews; no actual dispatch occurs.
  final bool demoMode;
  final List<WorkerDashboardOrder>? orders;

  /// Optional date override for deterministic previews and tests.
  final DateTime? currentDate;

  /// Parent handles API, waits for server confirmation, then rebuilds state.
  final Future<bool> Function(bool desiredOnline)? onAvailabilityRequested;
  final ValueChanged<WorkerDashboardOrder>? onOrderTap;
  final VoidCallback? onBookingsTap;
  final VoidCallback? onPayoutsTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  bool _previewOnline = false;
  bool _availabilityBusy = false;
  int _navIndex = 0;
  Object? _storeError;
  bool _storeLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.addListener(_onStoreChanged);
      _loadDemoStore();
    } else {
      _storeLoading = false;
    }
  }

  Future<void> _loadDemoStore() async {
    try {
      await WorkerDemoBookingStore.initialize();
      if (mounted) {
        setState(() {
          _storeLoading = false;
          _storeError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _storeLoading = false;
          _storeError = error;
        });
      }
    }
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.removeListener(_onStoreChanged);
    }
    super.dispose();
  }

  List<WorkerDashboardOrder> get _orders {
    final source =
        widget.orders ??
        (widget.demoMode
            ? WorkerDemoBookingStore.bookings
            : const <WorkerDashboardOrder>[]);
    if (!widget.demoMode || _storeLoading || _storeError != null) {
      return source;
    }
    return WorkerDemoBookingStore.resolveAll(source);
  }

  bool get _isOnline => widget.demoMode ? _previewOnline : false;

  DateTime get _now => (widget.currentDate ?? DateTime.now()).toLocal();

  String _rupees(int amount) => formatCustomerRupees(amount);

  String get _greeting {
    final hour = _now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  DateTime? _appointmentAt(WorkerDashboardOrder order) {
    final date = order.appointmentDate?.toLocal();
    final time = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([AP]M))?$',
      caseSensitive: false,
    ).firstMatch(order.time.trim());
    if (date == null || time == null) return null;
    var hour = int.parse(time.group(1)!);
    final minute = int.parse(time.group(2)!);
    final period = time.group(3)?.toUpperCase();
    if (minute > 59 ||
        hour > (period == null ? 23 : 12) ||
        (period != null && hour == 0)) {
      return null;
    }
    if (period != null) {
      hour %= 12;
      if (period == 'PM') hour += 12;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  String _dateLabel(DateTime date, DateTime now) => _sameDay(date, now)
      ? 'Today'
      : '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}';

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleAvailability(bool desired) async {
    if (_availabilityBusy) return;
    if (!widget.demoMode && !widget.isApproved) {
      _notice('Admin approval is required before going online.');
      return;
    }
    if (!desired &&
        (widget.activeService ||
            (widget.demoMode &&
                WorkerDemoBookingStore.repository.hasActivePhysicalService))) {
      _notice('Finish your active service before going offline.');
      return;
    }
    if (widget.demoMode) {
      setState(() => _previewOnline = desired);
      _notice('Preview only — availability was not sent to the server.');
      return;
    }
    // Never optimistically claim online status before server confirmation.
    if (widget.onAvailabilityRequested == null) {
      _notice('Availability API is not connected yet.');
      return;
    }
    setState(() => _availabilityBusy = true);
    try {
      final accepted = await widget.onAvailabilityRequested!(desired);
      if (mounted) {
        _notice(
          accepted
              ? 'Request accepted. Refreshing backend availability is required.'
              : 'The server did not accept the availability change.',
        );
      }
    } catch (_) {
      _notice('Unable to update availability. Please retry.');
    } finally {
      if (mounted) setState(() => _availabilityBusy = false);
    }
  }

  void _openOrder(WorkerDashboardOrder order) {
    if (widget.demoMode && (_storeLoading || _storeError != null)) {
      _notice(
        'Booking state is not loaded. Retry loading before opening a booking.',
      );
      return;
    }
    if (widget.onOrderTap != null) {
      widget.onOrderTap!(order);
      return;
    }
    Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerBookingDetailsScreen(
          order: order,
          demoMode: widget.demoMode,
        ),
      ),
    );
  }

  void _openBookings() {
    if (widget.demoMode && (_storeLoading || _storeError != null)) {
      _notice(
        'Booking state is not loaded. Retry loading before opening bookings.',
      );
      return;
    }
    if (widget.onBookingsTap != null) {
      widget.onBookingsTap!();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WorkerBookingsScreen(
          orders: _orders,
          demoMode: widget.demoMode,
          onOrderTap: widget.onOrderTap,
        ),
      ),
    );
  }

  void _openServiceHistory() {
    if (widget.demoMode && (_storeLoading || _storeError != null)) {
      _notice(
        'Booking state is not loaded. Retry loading before opening history.',
      );
      return;
    }
    Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerServiceHistoryScreen(
          orders: _orders,
          demoMode: widget.demoMode,
          onOrderTap: widget.onOrderTap,
        ),
      ),
    );
  }

  void _openProfileSettings() {
    if (widget.onProfileTap != null) {
      widget.onProfileTap!();
      return;
    }
    Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerProfileSettingsScreen(
          workerName: widget.workerName,
          phoneNumber: widget.workerPhone,
          demoMode: widget.demoMode,
          repository: widget.profileRepository,
          isVerified: widget.isApproved && !widget.demoMode,
          onLogoutTap: widget.onLogoutTap,
        ),
      ),
    );
  }

  void _openNotifications() {
    if (widget.onNotificationsTap != null) {
      widget.onNotificationsTap!();
      return;
    }
    if (widget.demoMode && (_storeLoading || _storeError != null)) {
      _notice(
        'Booking state is not loaded. Retry before viewing notifications.',
      );
      return;
    }
    Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerNotificationsScreen(
          orders: _orders,
          demoMode: widget.demoMode,
          onBookingTap: _openOrder,
        ),
      ),
    );
  }

  void _openScheduleLeave() {
    Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerScheduleLeaveScreen(
          demoMode: widget.demoMode,
          orders: _orders,
        ),
      ),
    );
  }

  Future<void> _previewIncomingOffer() async {
    if (!widget.demoMode || _storeLoading || _storeError != null) return;
    if (!_previewOnline) {
      _notice('Go Online first to preview a booking offer.');
      return;
    }
    final source = _orders;
    if (source.isEmpty) {
      _notice('No sample order available for preview.');
      return;
    }
    final chosen = source.firstWhere(
      (item) => item.status.toLowerCase() == 'scheduled',
      orElse: () => source.first,
    );
    final result = await Navigator.of(context).push<WorkerOfferDecision>(
      MaterialPageRoute(
        builder: (_) => WorkerIncomingBookingScreen(
          order: chosen,
          ongoingService:
              widget.activeService ||
              WorkerDemoBookingStore.repository.hasActivePhysicalService,
        ),
      ),
    );
    if (!mounted || result == null) return;
    switch (result.type) {
      case WorkerOfferDecisionType.accepted:
        _notice('Demo acceptance only — no booking was assigned.');
      case WorkerOfferDecisionType.rejected:
        _notice(
          'Demo rejection: ${result.rejection?.reason ?? 'reason unavailable'}. No penalty.',
        );
      case WorkerOfferDecisionType.expired:
        _notice('Demo offer expired. No booking was changed.');
    }
  }

  void _navigate(int i) {
    if (i == 0) {
      setState(() => _navIndex = 0);
      return;
    }
    if (i == 1) {
      _openBookings();
      return;
    }
    if (i == 2) {
      _openPayouts();
      return;
    }
    if (i == 3) {
      _openNotifications();
      return;
    }
    if (i == 4) {
      _openProfileSettings();
      return;
    }
    final handlers = <VoidCallback?>[
      null,
      widget.onBookingsTap,
      widget.onPayoutsTap,
      widget.onNotificationsTap,
      widget.onProfileTap,
    ];
    if (handlers[i] == null) {
      _notice(
        '${['Home', 'Bookings', 'Payouts', 'Notifications', 'Profile'][i]} screen is not connected yet.',
      );
    } else {
      handlers[i]!();
    }
  }

  void _openPayouts() {
    if (widget.onPayoutsTap != null) {
      widget.onPayoutsTap!();
      return;
    }
    Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerPayoutsScreen(
          repository: widget.payoutRepository,
          onNavigationSelected: _handlePayoutNavigation,
        ),
      ),
    );
  }

  void _handlePayoutNavigation(int index) {
    if (index == 2) return;
    Navigator.of(context).pop();
    _navigate(index);
  }

  Widget _panel(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(16),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0CF50070),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );

  Widget _heading(String text, {VoidCallback? action}) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _deep,
          ),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: action,
          child: const Text(
            'View All  ›',
            style: TextStyle(color: _pink, fontWeight: FontWeight.w700),
          ),
        ),
    ],
  );

  Widget _metric(IconData icon, String label, String value, Color color) =>
      Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0AF50070),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: _deep,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10.5,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _quickAction({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? badge,
  }) => Expanded(
    child: Material(
      key: key,
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAF2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: _pink, size: 20),
                  ),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: _pink,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _deep,
                  fontSize: 11.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _orderRow(WorkerDashboardOrder item) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => _openOrder(item),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              item.time,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _deep,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Container(
            width: 38,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEAF2),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.spa_outlined, color: _pink, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _deep,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  item.customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10.5),
                ),
                Text(
                  item.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 9.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 62),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDF3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                item.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _pink,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _pink, size: 19),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final now = _now;
    final todayBookings = orders
        .where((order) {
          final date = order.appointmentDate?.toLocal();
          return date != null &&
              _sameDay(date, now) &&
              !{
                'cancelled',
                'canceled',
              }.contains(order.status.toLowerCase().trim());
        })
        .toList(growable: false);
    final todayCount = todayBookings.length;
    final todayCustomerPayable = todayBookings.fold<int>(
      0,
      (total, order) => total + order.customerPayable,
    );
    final todaySchedule =
        orders.where((order) {
          final date = order.appointmentDate;
          return date != null &&
              _sameDay(date.toLocal(), now) &&
              _scheduleStatuses.contains(order.status.toLowerCase().trim()) &&
              _appointmentAt(order) != null;
        }).toList()..sort(
          (first, second) =>
              _appointmentAt(first)!.compareTo(_appointmentAt(second)!),
        );
    final upcoming =
        orders.where((order) {
          final appointment = _appointmentAt(order);
          return _upcomingStatuses.contains(
                order.status.toLowerCase().trim(),
              ) &&
              appointment != null &&
              appointment.isAfter(now);
        }).toList()..sort(
          (first, second) =>
              _appointmentAt(first)!.compareTo(_appointmentAt(second)!),
        );
    final next = upcoming.isEmpty ? null : upcoming.first;
    final completedStatuses = {'closed', 'completed', 'demo completed', 'paid'};
    final completedOrders = orders
        .where(
          (order) =>
              completedStatuses.contains(order.status.toLowerCase().trim()),
        )
        .toList(growable: false);
    final completionDates = <String, DateTime>{
      for (final order in orders)
        if (order.completedAt != null) order.id: order.completedAt!.toLocal(),
    };
    final completedIdsWithoutDate = completedOrders
        .where((order) => order.completedAt == null)
        .map((order) => order.id)
        .toSet();
    if (widget.demoMode && !_storeLoading && _storeError == null) {
      for (final session in WorkerDemoBookingStore.repository.sessions) {
        final finishedAt = session.finishedAt;
        if (finishedAt != null &&
            orders.any((order) => order.id == session.bookingId)) {
          completionDates[session.bookingId] = finishedAt.toLocal();
          completedIdsWithoutDate.remove(session.bookingId);
        }
      }
    }
    final completedToday = completedIdsWithoutDate.isNotEmpty
        ? null
        : completionDates.values.where((date) => _sameDay(date, now)).length;
    final pendingCount = orders
        .where(
          (order) => {
            'pending',
            'requested',
            'offered',
            'new',
          }.contains(order.status.toLowerCase().trim()),
        )
        .length;
    final online = _isOnline;
    return Scaffold(
      backgroundColor: _cream,
      body: widget.demoMode && (_storeLoading || _storeError != null)
          ? SafeArea(
              child: Center(
                child: _storeLoading
                    ? const CircularProgressIndicator(color: _pink)
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Could not load saved demo bookings.',
                              style: TextStyle(
                                color: _deep,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$_storeError',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _muted),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _storeLoading = true;
                                  _storeError = null;
                                });
                                _loadDemoStore();
                              },
                              child: const Text('Retry loading'),
                            ),
                          ],
                        ),
                      ),
              ),
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(17, 18, 17, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEAF2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.local_florist_rounded,
                                      color: _pink,
                                      size: 29,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pinkora',
                                          style: TextStyle(
                                            color: _pink,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            height: 1.05,
                                          ),
                                        ),
                                        Text(
                                          'Beauty at Your Doorstep',
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _navigate(3),
                                    tooltip: 'Notifications',
                                    icon: const Icon(
                                      Icons.notifications_none_rounded,
                                      color: _deep,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFFEAF2),
                                        Color(0xFFFFF4F8),
                                      ],
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: -48,
                                        right: -40,
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          decoration: const BoxDecoration(
                                            color: Color(0x22F50070),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              CircleAvatar(
                                                radius: 27,
                                                backgroundColor: Colors.white,
                                                child: CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: const Color(
                                                    0xFFFFE2EC,
                                                  ),
                                                  child:
                                                      widget.profilePhotoPath ==
                                                          null
                                                      ? Text(
                                                          widget
                                                                  .workerName
                                                                  .isEmpty
                                                              ? 'W'
                                                              : widget
                                                                    .workerName[0]
                                                                    .toUpperCase(),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 21,
                                                                color: _pink,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                        )
                                                      : ClipOval(
                                                          child: Image.file(
                                                            File(
                                                              widget
                                                                  .profilePhotoPath!,
                                                            ),
                                                            width: 48,
                                                            height: 48,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) => Text(
                                                                  widget
                                                                          .workerName
                                                                          .isEmpty
                                                                      ? 'W'
                                                                      : widget
                                                                            .workerName[0]
                                                                            .toUpperCase(),
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        21,
                                                                    color:
                                                                        _pink,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                  ),
                                                                ),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              if (online)
                                                Positioned(
                                                  bottom: -1,
                                                  right: -1,
                                                  child: Container(
                                                    width: 15,
                                                    height: 15,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF13B76A,
                                                      ),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _greeting,
                                                  style: const TextStyle(
                                                    color: _muted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Text(
                                                  widget.workerName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _deep,
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .location_on_outlined,
                                                      color: _pink,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        widget.location,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: _muted,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                online ? 'Online' : 'Offline',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: online
                                                      ? const Color(0xFF138552)
                                                      : _muted,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Transform.scale(
                                                scale: 0.84,
                                                child: Switch.adaptive(
                                                  value: online,
                                                  activeTrackColor: const Color(
                                                    0xFF13B76A,
                                                  ),
                                                  onChanged: _availabilityBusy
                                                      ? null
                                                      : _toggleAvailability,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (widget.demoMode) ...[
                                const SizedBox(height: 7),
                                const Text(
                                  'PREVIEW · Sample bookings may be undated · No worker payout data',
                                  style: TextStyle(fontSize: 9, color: _muted),
                                ),
                              ],
                              if (widget.demoMode) ...[
                                Builder(
                                  builder: (context) {
                                    final activeSessions =
                                        WorkerDemoBookingStore
                                            .repository
                                            .sessions
                                            .where(
                                              (session) =>
                                                  session.serviceStage ==
                                                  WorkerServiceStage.inProgress,
                                            )
                                            .toList(growable: false);
                                    final active = activeSessions.isEmpty
                                        ? null
                                        : activeSessions.first;
                                    if (active == null) {
                                      return const SizedBox.shrink();
                                    }
                                    WorkerDashboardOrder? activeOrder;
                                    for (final order in orders) {
                                      if (order.id == active.bookingId) {
                                        activeOrder = order;
                                        break;
                                      }
                                    }
                                    if (activeOrder == null) {
                                      return _panel(
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Active demo session needs attention',
                                              style: TextStyle(
                                                color: _deep,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              'Booking ${active.bookingId} is saved but not present in the current list.',
                                              style: const TextStyle(
                                                color: _muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    final order = activeOrder;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: _panel(
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .play_circle_outline_rounded,
                                                  color: _pink,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Service in progress',
                                                  style: TextStyle(
                                                    color: _deep,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 7),
                                            Text(
                                              '${order.service} · ${order.customer}',
                                              style: const TextStyle(
                                                color: _muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: FilledButton.icon(
                                                onPressed: () =>
                                                    _openOrder(order),
                                                icon: const Icon(
                                                  Icons.play_arrow_rounded,
                                                ),
                                                label: const Text(
                                                  'Resume Active Service',
                                                ),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: _pink,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 13),
                              Row(
                                children: [
                                  _quickAction(
                                    icon: Icons.calendar_month_outlined,
                                    label: 'Incoming Bookings',
                                    badge: pendingCount > 0
                                        ? pendingCount
                                        : null,
                                    onTap: widget.demoMode
                                        ? _previewIncomingOffer
                                        : _openBookings,
                                  ),
                                  const SizedBox(width: 8),
                                  _quickAction(
                                    icon: Icons.event_available_outlined,
                                    label: 'My Schedule / Leave',
                                    onTap: _openScheduleLeave,
                                  ),
                                  const SizedBox(width: 8),
                                  _quickAction(
                                    key: const Key('open-service-history'),
                                    icon: Icons.history_rounded,
                                    label: 'Service History',
                                    onTap: _openServiceHistory,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _metric(
                                    Icons.calendar_month_outlined,
                                    "Today's Bookings",
                                    '$todayCount',
                                    _pink,
                                  ),
                                  const SizedBox(width: 8),
                                  _metric(
                                    Icons.currency_rupee_rounded,
                                    "Today's Customer Payable",
                                    _rupees(todayCustomerPayable),
                                    const Color(0xFF13B76A),
                                  ),
                                  const SizedBox(width: 8),
                                  _metric(
                                    Icons.star_rounded,
                                    'Completed Today',
                                    completedToday?.toString() ??
                                        'Not available',
                                    const Color(0xFFF2A900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _panel(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _heading('Next Appointment'),
                                    if (next == null)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          'No upcoming appointment is scheduled yet.',
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    else ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 58,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFEAF2),
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                            ),
                                            child: const Icon(
                                              Icons.spa_outlined,
                                              color: _pink,
                                              size: 26,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  next.customer,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _deep,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                Text(
                                                  next.service,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _muted,
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_dateLabel(next.appointmentDate!.toLocal(), now)} · ${next.time} · ${next.duration}',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _muted,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                Text(
                                                  next.location,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _muted,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.payments_outlined,
                                            color: _pink,
                                            size: 17,
                                          ),
                                          const SizedBox(width: 5),
                                          const Expanded(
                                            child: Text(
                                              'Customer payable',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _muted,
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _rupees(next.customerPayable),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: _deep,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                          onPressed: () => _openOrder(next),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _pink,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(0, 43),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                            ),
                                          ),
                                          child: const Text('View Booking  ›'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _panel(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _heading(
                                      "Today's Schedule",
                                      action: _openScheduleLeave,
                                    ),
                                    if (todaySchedule.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          'No appointments scheduled for today.',
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    else ...[
                                      for (
                                        var i = 0;
                                        i < todaySchedule.length && i < 3;
                                        i++
                                      ) ...[
                                        if (i > 0)
                                          const Divider(
                                            height: 1,
                                            color: _border,
                                          ),
                                        _orderRow(todaySchedule[i]),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 64,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFFFE2EC),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected) ? _pink : _muted,
                fontSize: 10,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _navIndex,
            onDestinationSelected: _navigate,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: _muted),
                selectedIcon: Icon(Icons.home_rounded, color: _pink),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined, color: _muted),
                selectedIcon: Icon(Icons.calendar_today_rounded, color: _pink),
                label: 'Bookings',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _muted,
                ),
                selectedIcon: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: _pink,
                ),
                label: 'Payouts',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none_outlined, color: _muted),
                selectedIcon: Icon(Icons.notifications_rounded, color: _pink),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: _muted),
                selectedIcon: Icon(Icons.person_rounded, color: _pink),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _weekday(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

String _month(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
