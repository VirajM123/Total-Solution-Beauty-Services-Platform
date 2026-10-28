import '../schedule/worker_leave_repository.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../integration/worker_api.dart';
import 'worker_booking_data.dart';
import 'worker_demo_booking_store.dart';
import 'worker_booking_session.dart';
import 'worker_bookings_screen.dart';
import 'worker_service_history_screen.dart';
import 'worker_profile_settings_screen.dart';
import 'worker_profile_data.dart';
import 'worker_notifications_screen.dart';
import 'worker_notification_repository.dart';
import 'worker_payout_data.dart';
import 'worker_payouts_screen.dart';
import 'worker_incoming_booking_screen.dart';
import 'worker_booking_details_screen.dart';
import '../../app/slide_page_route.dart';
import '../schedule/worker_schedule_leave_screen.dart';
import '../../integration/worker_mobile_operations_api.dart';

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
    this.leaveRepository,
    this.notificationRepository,
    this.isApproved = false,
    this.activeService = false,
    this.demoMode = true,
    this.orders,
    this.currentDate,
    this.initialOnline = false,
    this.onAvailabilityRequested,
    this.onOrderTap,
    this.onBookingsTap,
    this.onPayoutsTap,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onLogoutTap,
    this.operationsApi,
  });

  final String workerName;
  final String location;
  final String workerPhone;
  final String? profilePhotoPath;
  final WorkerProfileRepository? profileRepository;
  final WorkerPayoutRepository? payoutRepository;
  final WorkerLeaveRepository? leaveRepository;
  final WorkerNotificationRepository? notificationRepository;

  /// Must come from authenticated, backend-verified account state in production.
  final bool isApproved;

  /// Must come from server-side booking state in production.
  final bool activeService;

  /// Only true for development previews; no actual dispatch occurs.
  final bool demoMode;
  final List<WorkerDashboardOrder>? orders;

  /// Optional date override for deterministic previews and tests.
  final DateTime? currentDate;

  /// Initial confirmed online availability from authoritative profile.
  final bool initialOnline;

  /// Parent handles API, waits for server confirmation, then rebuilds state.
  final Future<bool> Function(bool desiredOnline)? onAvailabilityRequested;
  final ValueChanged<WorkerDashboardOrder>? onOrderTap;
  final VoidCallback? onBookingsTap;
  final VoidCallback? onPayoutsTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;
  final WorkerOperationsApi? operationsApi;

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  late bool _previewOnline;
  bool _availabilityBusy = false;
  int _navIndex = 0;
  int _offerIndex = 0;
  late final PageController _offersController = PageController(
    viewportFraction: .86,
  );
  Object? _storeError;
  bool _storeLoading = true;

  @override
  void initState() {
    super.initState();
    _previewOnline = widget.initialOnline;
    widget.notificationRepository?.addListener(_onNotificationChanged);
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.addListener(_onStoreChanged);
      _loadDemoStore();
    } else {
      _storeLoading = false;
    }
  }

  void _onNotificationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant WorkerDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialOnline != widget.initialOnline) {
      _previewOnline = widget.initialOnline;
    }
    if (oldWidget.notificationRepository != widget.notificationRepository) {
      oldWidget.notificationRepository?.removeListener(_onNotificationChanged);
      widget.notificationRepository?.addListener(_onNotificationChanged);
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
    _offersController.dispose();
    widget.notificationRepository?.removeListener(_onNotificationChanged);
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

  bool get _isOnline => _previewOnline;

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
        setState(() {
          _previewOnline = accepted;
        });
        _notice(
          accepted
              ? "You're now online and available for bookings."
              : "You're now offline.",
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
          operationsApi: widget.operationsApi,
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
          operationsApi: widget.operationsApi,
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
          operationsApi: widget.operationsApi,
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
          operationsApi: widget.operationsApi,
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
          repository: widget.notificationRepository,
          operationsApi: widget.operationsApi as WorkerMobileOperationsApi?,
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
          operationsApi: widget.operationsApi,
          leaveRepository: widget.leaveRepository,
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
          isLiveOffer: true,
          distanceKm: '2.8 km away',
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
    height: 172,
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
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Spacer(),
                Stack(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _openNotifications,
                        tooltip: 'Notifications',
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 25,
                          color: _deep,
                        ),
                      ),
                    ),
                    if (pendingCount > 0 ||
                        (widget.notificationRepository?.unreadCount ?? 0) > 0)
                      Positioned(
                        right: 5,
                        top: 5,
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: _profilePhoto(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 19,
                        height: 1.15,
                      ),
                      children: [
                        TextSpan(text: '$_greeting, '),
                        TextSpan(
                          text: widget.workerName.split(' ').first,
                          style: const TextStyle(
                            color: _deep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.favorite_border, color: _pink, size: 19),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: _pink, size: 17),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    widget.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _muted,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
              decoration: _surface(
                radius: 30,
              ).copyWith(color: const Color(0xF4FFFFFF)),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          online
                              ? 'Available for new bookings'
                              : 'Go online for new bookings',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: .78,
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

  Widget _overviewStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: _deep,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 9, height: 1.1),
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

  Widget _offerCard({
    required String title,
    required String description,
    required String image,
    required Color accent,
    required Alignment imageAlignment,
  }) => InkWell(
    onTap: () => _notice('Offer details are coming soon.'),
    borderRadius: BorderRadius.circular(18),
    child: Container(
      margin: const EdgeInsets.only(right: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(image, fit: BoxFit.cover, alignment: imageAlignment),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  accent.withValues(alpha: .94),
                  accent.withValues(alpha: .85),
                  accent.withValues(alpha: .08),
                ],
                stops: const [0, .57, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 165,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _pink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _deep,
                        fontSize: 9,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Know more  →',
                      style: TextStyle(
                        color: _pink,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _offersSection() {
    const offerCount = 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Offers for You'),
        const SizedBox(height: 5),
        SizedBox(
          height: 84,
          child: PageView(
            key: const Key('worker-offers-carousel'),
            clipBehavior: Clip.none,
            controller: _offersController,
            onPageChanged: (index) => setState(() => _offerIndex = index),
            children: [
              _offerCard(
                title: 'Earn More This Season',
                description: 'Get extra bookings with seasonal offers.',
                image: 'assets/images/dashboard/worker_hero.jpg',
                accent: const Color(0xFFFFD9E8),
                imageAlignment: const Alignment(.8, -.25),
              ),
              _offerCard(
                title: 'Refer & Earn',
                description: 'Invite beauty professionals to join you.',
                image: 'assets/images/dashboard/makeup_brushes.jpg',
                accent: const Color(0xFFFFEAD8),
                imageAlignment: Alignment.centerRight,
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            offerCount,
            (index) => AnimatedContainer(
              key: Key('offer-indicator-$index'),
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _offerIndex == index ? 13 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _offerIndex == index ? _pink : const Color(0xFFD9D7DC),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashboardAction({
    Key? key,
    required IconData icon,
    required String label,
    required String detail,
    required VoidCallback onTap,
    int? badge,
    Color color = _pink,
  }) => InkWell(
    key: key,
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (badge != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
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
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _deep,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'View',
            style: TextStyle(
              color: _pink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _pink, size: 20),
        ],
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
          padding: const EdgeInsets.all(12),
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
                        fontSize: 16,
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
              const SizedBox(height: 8),
              if (next == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
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
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: const Color(0xFFFFE1EB),
                              child: const Icon(
                                Icons.spa_outlined,
                                color: _pink,
                                size: 25,
                              ),
                            ),
                    ),
                    const SizedBox(width: 9),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            next.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: _pink,
                                size: 11,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${_dateLabel(next.appointmentDate!.toLocal(), now)}  •  ${next.time}  •  ${next.duration}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 9,
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
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  next.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 9,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: _pink, size: 16),
                    const SizedBox(width: 5),
                    const Expanded(
                      child: Text(
                        'Customer Payable',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 9),
                      ),
                    ),
                    Text(
                      _rupees(next.customerPayable),
                      style: const TextStyle(
                        color: _deep,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _openOrder(next),
                      style: FilledButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Details',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
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
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _sectionTitle("Today's Overview"),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _overviewStat(
                                    icon: Icons.calendar_month_outlined,
                                    label: "Today's Bookings",
                                    value: '$todayCount',
                                    color: _pink,
                                  ),
                                  const SizedBox(
                                    height: 34,
                                    child: VerticalDivider(
                                      width: 16,
                                      thickness: 1,
                                      color: _border,
                                    ),
                                  ),
                                  _overviewStat(
                                    icon: Icons.account_balance_wallet_outlined,
                                    label: 'Customer Payable',
                                    value: _rupees(todayCustomerPayable),
                                    color: _deep,
                                  ),
                                  const SizedBox(
                                    height: 34,
                                    child: VerticalDivider(
                                      width: 16,
                                      thickness: 1,
                                      color: _border,
                                    ),
                                  ),
                                  _overviewStat(
                                    icon: Icons.star_outline_rounded,
                                    label: 'Completed Today',
                                    value: completedToday?.toString() ?? '—',
                                    color: const Color(0xFFB7791F),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _sectionTitle(
                                'Manage Your Work',
                                onSeeAll: _openBookings,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                decoration: _surface(radius: 20),
                                child: Column(
                                  children: [
                                    _dashboardAction(
                                      icon: Icons.event_available_outlined,
                                      label: 'Incoming Bookings',
                                      detail: 'Review new booking requests',
                                      badge: pendingCount > 0
                                          ? pendingCount
                                          : null,
                                      onTap: widget.demoMode
                                          ? _previewIncomingOffer
                                          : _openBookings,
                                    ),
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: _border,
                                      indent: 66,
                                    ),
                                    _dashboardAction(
                                      icon: Icons.calendar_today_outlined,
                                      label: 'My Schedule',
                                      detail:
                                          'View your daily schedule and leave',
                                      onTap: _openScheduleLeave,
                                    ),
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: _border,
                                      indent: 66,
                                    ),
                                    _dashboardAction(
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      label: 'Payouts & Earnings',
                                      detail: 'Track earnings and payouts',
                                      color: const Color(0xFF00A95C),
                                      onTap: _openPayouts,
                                    ),
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: _border,
                                      indent: 66,
                                    ),
                                    _dashboardAction(
                                      key: const Key('open-service-history'),
                                      icon: Icons.history_rounded,
                                      label: 'Service History',
                                      detail: 'Review your past services',
                                      color: const Color(0xFF9B2DD7),
                                      onTap: _openServiceHistory,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (activeOrder != null) ...[
                                _activeServiceCard(activeOrder),
                                const SizedBox(height: 8),
                              ],
                              _offersSection(),
                              const SizedBox(height: 6),
                              _appointmentCard(next, now),
                              const SizedBox(height: 12),
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
            destinations: [
              const NavigationDestination(
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
                icon: (widget.notificationRepository?.unreadCount ?? 0) > 0
                    ? Badge(
                        backgroundColor: _pink,
                        label: Text(
                          '${widget.notificationRepository!.unreadCount}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_none_outlined,
                          color: _muted,
                        ),
                      )
                    : const Icon(
                        Icons.notifications_none_outlined,
                        color: _muted,
                      ),
                selectedIcon:
                    (widget.notificationRepository?.unreadCount ?? 0) > 0
                        ? Badge(
                            backgroundColor: _pink,
                            label: Text(
                              '${widget.notificationRepository!.unreadCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                            child: const Icon(
                              Icons.notifications_rounded,
                              color: _pink,
                            ),
                          )
                        : const Icon(
                            Icons.notifications_rounded,
                            color: _pink,
                          ),
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
