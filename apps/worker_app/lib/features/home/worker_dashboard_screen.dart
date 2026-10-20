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

  BoxDecoration _surface({double radius = 22}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _border),
    boxShadow: const [
      BoxShadow(color: Color(0x14D74278), blurRadius: 18, offset: Offset(0, 7)),
    ],
  );

  Widget _profilePhoto() {
    final path = widget.profilePhotoPath;
    return ClipOval(
      child: path != null && File(path).existsSync()
          ? Image.file(File(path), width: 42, height: 42, fit: BoxFit.cover)
          : Image.asset(
              'assets/images/dashboard/worker_hero.jpg',
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              alignment: const Alignment(0.52, -0.28),
            ),
    );
  }

  Widget _hero(bool online, int pendingCount) => Container(
    height: 254,
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/images/dashboard/worker_hero.jpg'),
        fit: BoxFit.cover,
        alignment: Alignment(0.42, -0.28),
      ),
    ),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xF9FFF7FA), Color(0xE6FFF7FA), Color(0x08FFF7FA)],
          stops: [0, .45, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 13, 19, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_florist_outlined,
                  size: 34,
                  color: _pink,
                ),
                const SizedBox(width: 5),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pinkora',
                        style: TextStyle(
                          color: _pink,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        'Worker App',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    IconButton(
                      onPressed: _openNotifications,
                      tooltip: 'Notifications',
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        size: 28,
                        color: _deep,
                      ),
                    ),
                    if (pendingCount > 0)
                      Positioned(
                        right: 9,
                        top: 6,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: _pink,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                GestureDetector(
                  onTap: _openProfileSettings,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: _profilePhoto(),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '$_greeting,',
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
            Text(
              widget.workerName.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _deep,
                fontSize: 31,
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: _pink, size: 18),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    widget.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _muted,
                  size: 19,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 5, 4, 5),
              decoration: _surface(
                radius: 30,
              ).copyWith(color: const Color(0xF4FFFFFF)),
              child: Row(
                children: [
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: online
                          ? const Color(0xFFE0F8ED)
                          : const Color(0xFFF1EEF0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.circle,
                      size: 10,
                      color: online ? const Color(0xFF00A95C) : _muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          online ? "You're Online" : "You're Offline",
                          style: TextStyle(
                            color: online ? const Color(0xFF00A95C) : _deep,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          online
                              ? 'Available for new bookings'
                              : 'Go online for new bookings',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: .82,
                    child: Switch(
                      value: online,
                      onChanged: _availabilityBusy ? null : _toggleAvailability,
                      activeTrackColor: _pink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _metric(IconData icon, String label, String value, Color color) =>
      Expanded(
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: _deep,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 10, height: 1.1),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String title, {VoidCallback? onSeeAll}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _deep,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (onSeeAll != null)
        InkWell(
          onTap: onSeeAll,
          child: const Row(
            children: [
              Text('See All', style: TextStyle(color: _pink, fontSize: 12)),
              Icon(Icons.chevron_right_rounded, color: _pink, size: 18),
            ],
          ),
        ),
    ],
  );

  Widget _quickAction({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? badge,
    Color color = _pink,
  }) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 105,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
          decoration: _surface(radius: 18),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 25),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: _pink,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _deep,
                  fontSize: 10,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _appointmentCard(
    WorkerDashboardOrder? next,
    DateTime now,
  ) => Container(
    decoration: _surface(radius: 23),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/dashboard/makeup_brushes.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFF8FB),
                  const Color(0xEEFFF8FB),
                  const Color(0x88FFF8FB),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Next Appointment',
                      style: TextStyle(
                        color: _deep,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (next != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDEEC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Upcoming',
                        style: TextStyle(
                          color: _pink,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 13),
              if (next == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No upcoming appointment is scheduled yet.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                )
              else ...[
                Row(
                  children: [
                    ClipOval(
                      child: next.service.toLowerCase().contains('bridal')
                          ? Image.asset(
                              'assets/images/dashboard/bridal_portrait.jpg',
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 62,
                              height: 62,
                              color: const Color(0xFFFFE1EB),
                              child: const Icon(
                                Icons.spa_outlined,
                                color: _pink,
                                size: 31,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            next.service,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _deep,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            next.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: _pink,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${_dateLabel(next.appointmentDate!.toLocal(), now)}  •  ${next.time}  •  ${next.duration}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: _pink,
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  next.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
                  decoration: _surface(
                    radius: 17,
                  ).copyWith(color: const Color(0xEFFFFFFF)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            color: _pink,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          const Expanded(
                            child: Text(
                              'Customer Payable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _muted, fontSize: 10),
                            ),
                          ),
                          Text(
                            _rupees(next.customerPayable),
                            style: const TextStyle(
                              color: _deep,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _openOrder(next),
                          style: FilledButton.styleFrom(
                            backgroundColor: _pink,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'View Details',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _activeServiceCard(WorkerDashboardOrder order) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _surface(radius: 18),
    child: Row(
      children: [
        const Icon(Icons.play_circle_outline_rounded, color: _pink, size: 27),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Service in progress',
                style: TextStyle(
                  color: _deep,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text(
                '${order.service} • ${order.customer}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _openOrder(order),
          child: const Text('Resume'),
        ),
      ],
    ),
  );

  Widget _scheduleRow(WorkerDashboardOrder order) => InkWell(
    onTap: () => _openOrder(order),
    borderRadius: BorderRadius.circular(18),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: _surface(radius: 18),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              order.time.replaceFirst(' ', '\n'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _pink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 39,
            margin: const EdgeInsets.symmetric(horizontal: 9),
            color: _border,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _deep,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  order.service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 370) ...[
            const Icon(Icons.access_time_rounded, color: _muted, size: 14),
            const SizedBox(width: 3),
            Text(
              order.duration,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: order.status.toLowerCase().contains('complet')
                  ? const Color(0xFFE1F8ED)
                  : const Color(0xFFFFEAF2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              order.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: order.status.toLowerCase().contains('complet')
                    ? const Color(0xFF00A95C)
                    : _pink,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
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
              (_scheduleStatuses.contains(order.status.toLowerCase().trim()) ||
                  {
                    'completed',
                    'demo completed',
                    'paid',
                  }.contains(order.status.toLowerCase().trim())) &&
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
    WorkerDashboardOrder? activeOrder;
    if (widget.demoMode && !_storeLoading && _storeError == null) {
      for (final session in WorkerDemoBookingStore.repository.sessions) {
        if (session.serviceStage == WorkerServiceStage.inProgress) {
          for (final order in orders) {
            if (order.id == session.bookingId) activeOrder = order;
          }
        }
      }
    }
    final online = _isOnline;
    return Scaffold(
      backgroundColor: _cream,
      body: widget.demoMode && (_storeLoading || _storeError != null)
          ? SafeArea(
              child: Center(
                child: _storeLoading
                    ? const CircularProgressIndicator(color: _pink)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Could not load saved demo bookings.'),
                          const SizedBox(height: 8),
                          Text('$_storeError', textAlign: TextAlign.center),
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
            )
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _hero(online, pendingCount),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 15,
                                ),
                                decoration: _surface(radius: 22),
                                child: Row(
                                  children: [
                                    _metric(
                                      Icons.calendar_month_outlined,
                                      "Today's Bookings",
                                      '$todayCount',
                                      _pink,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 55,
                                      color: _border,
                                    ),
                                    _metric(
                                      Icons.currency_rupee_rounded,
                                      "Today's Customer Payable",
                                      _rupees(todayCustomerPayable),
                                      const Color(0xFF00A95C),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 55,
                                      color: _border,
                                    ),
                                    _metric(
                                      Icons.star_rounded,
                                      'Completed Today',
                                      completedToday?.toString() ?? '—',
                                      const Color(0xFFF59A2A),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              _sectionTitle(
                                'Quick Actions',
                                onSeeAll: _openBookings,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _quickAction(
                                    icon: Icons.event_available_outlined,
                                    label: 'Incoming\nBookings',
                                    badge: pendingCount > 0
                                        ? pendingCount
                                        : null,
                                    onTap: widget.demoMode
                                        ? _previewIncomingOffer
                                        : _openBookings,
                                  ),
                                  _quickAction(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'My Schedule',
                                    onTap: _openScheduleLeave,
                                  ),
                                  _quickAction(
                                    key: const Key('open-service-history'),
                                    icon: Icons.history_rounded,
                                    label: 'Service\nHistory',
                                    color: const Color(0xFF9B2DD7),
                                    onTap: _openServiceHistory,
                                  ),
                                  _quickAction(
                                    icon: Icons.currency_rupee_rounded,
                                    label: 'Payouts &\nEarnings',
                                    color: const Color(0xFF00A95C),
                                    onTap: _openPayouts,
                                  ),
                                  _quickAction(
                                    icon: Icons.person_outline_rounded,
                                    label: 'Profile',
                                    onTap: _openProfileSettings,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              if (activeOrder != null) ...[
                                _activeServiceCard(activeOrder),
                                const SizedBox(height: 12),
                              ],
                              _appointmentCard(next, now),
                              const SizedBox(height: 18),
                              _sectionTitle(
                                "Today's Schedule",
                                onSeeAll: _openScheduleLeave,
                              ),
                              const SizedBox(height: 8),
                              if (todaySchedule.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: _surface(radius: 18),
                                  child: const Text(
                                    'No appointments scheduled for today.',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else
                                for (final order in todaySchedule.take(3))
                                  _scheduleRow(order),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 62,
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
