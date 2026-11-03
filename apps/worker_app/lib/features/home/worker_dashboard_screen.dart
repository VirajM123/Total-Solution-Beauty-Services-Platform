import '../widgets/worker_reference_widgets.dart';
import '../widgets/worker_images.dart';
import '../schedule/worker_leave_repository.dart';

import 'package:flutter/material.dart';
import '../../integration/worker_api.dart';
import 'worker_booking_data.dart';
import 'worker_demo_booking_store.dart';
import 'worker_booking_session.dart';
import 'worker_bookings_screen.dart';
import 'worker_profile_settings_screen.dart';
import 'worker_profile_data.dart';
import 'worker_notifications_screen.dart';
import 'worker_notification_repository.dart';
import 'worker_payout_data.dart';
import 'worker_payouts_screen.dart';
import 'worker_booking_details_screen.dart';
import '../../app/slide_page_route.dart';
import '../schedule/worker_schedule_leave_screen.dart';
import '../../integration/worker_mobile_operations_api.dart';

// Preserve the original public model import path for existing callers.
export 'worker_booking_data.dart' show WorkerDashboardOrder;

// Pinkora worker dashboard — frontend preview only.
// Do not use this local toggle or sample booking data for production dispatch.
// Backend must enforce worker approval, online status and active-service locks.

const _pink = Color(0xFFFF1678);
const _deep = Color(0xFF210B35);
const _muted = Color(0xFF686080);
const _border = Color(0xFFFFDFEB);

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
  List<Map<String, dynamic>> _liveBanners = [];
  Object? _storeError;
  bool _storeLoading = true;

  @override
  void initState() {
    super.initState();
    _previewOnline = widget.initialOnline;
    if (!widget.demoMode) _loadBanners();
    widget.notificationRepository?.addListener(_onNotificationChanged);
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.addListener(_onStoreChanged);
      _loadDemoStore();
    } else {
      _storeLoading = false;
    }
  }

  Future<void> _loadBanners() async {
    try {
      final banners =
          await (widget.operationsApi is WorkerMobileOperationsApi
                  ? widget.operationsApi as WorkerMobileOperationsApi
                  : WorkerMobileOperationsApi())
              .fetchCatalogRecords('banners');
      if (mounted)
        setState(
          () => _liveBanners = banners
              .where((b) => (b['audiences'] as List? ?? []).contains('worker'))
              .toList(),
        );
    } catch (_) {
      /* Optional promotional content stays empty when unavailable. */
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
          onNavigationSelected: (index) {
            Navigator.of(context).pop();
            _navigate(index == 3 ? 4 : index);
          },
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
          location: widget.location,
          onNotificationsTap: _openNotifications,
          unreadNotifications: widget.notificationRepository?.unreadCount ?? 0,
          onNavigationSelected: (index) {
            Navigator.of(context).pop();
            _navigate(index == 3 ? 4 : index);
          },
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
          location: widget.location,
          onNotificationsTap: _openNotifications,
          onNavigationSelected: _handleScheduleNavigation,
        ),
      ),
    );
  }

  void _handleScheduleNavigation(int index) {
    if (index == 1) return;
    Navigator.of(context).pop();
    if (index == 0) return;
    _navigate(index == 3 ? 4 : index);
  }

  void _navigate(int i) {
    if (i == 0) {
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

  Widget _hero(bool online, int pendingCount) => Column(
    children: [
      WorkerReferenceHeader(
        location: widget.location,
        brandWidth: 190,
        brandAsset: 'assets/images/dashboard/reference_brand.png',
        onNotifications: _openNotifications,
        unread: widget.notificationRepository?.unreadCount ?? 0,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 14, 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: _openProfileSettings,
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Color(0x30FF8BB5), blurRadius: 12),
                      ],
                    ),
                    child:
                        widget.demoMode &&
                            (widget.profilePhotoPath?.isEmpty ?? true)
                        ? ClipOval(
                            child: Image.asset(
                              'assets/images/dashboard/reference_profile.png',
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                            ),
                          )
                        : WorkerProfilePhoto(
                            path: widget.profilePhotoPath,
                            size: 76,
                          ),
                  ),
                  if (widget.isApproved && !widget.demoMode)
                    const Positioned(
                      right: 0,
                      bottom: 2,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xFF00C768),
                          size: 21,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_greeting,',
                    style: const TextStyle(fontSize: 12, color: workerMuted),
                  ),
                  Text(
                    widget.workerName.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: workerInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    "Let's make today beautiful.",
                    style: TextStyle(fontSize: 10.5, color: workerMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: online
                      ? const Color(0xFF71E3A4)
                      : const Color(0xFFE6DDE4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    online ? "You're online" : "You're offline",
                    style: TextStyle(
                      fontSize: 10,
                      color: online ? const Color(0xFF008C3E) : workerMuted,
                    ),
                  ),
                  SizedBox(
                    width: 41,
                    height: 32,
                    child: Transform.scale(
                      scale: .65,
                      child: Switch(
                        value: online,
                        onChanged: _availabilityBusy
                            ? null
                            : _toggleAvailability,
                        activeTrackColor: const Color(0xFF00C36A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _earningsCard(int? paise) {
    final goal = widget.demoMode ? 300000 : null;
    final progress = goal == null || paise == null
        ? 0.0
        : (paise / goal).clamp(0.0, 1.0);
    return Container(
      height: 154,
      decoration: workerReferenceSurface(tinted: true),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: 0,
            width: 154,
            height: 118,
            child: Image.asset(
              'assets/images/dashboard/reference_lotus.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            right: 94,
            top: 75,
            width: 117,
            height: 40,
            child: CustomPaint(
              painter: _DashboardEarningsChart(
                values: List.generate(7, (index) {
                  final day = _now.subtract(Duration(days: 6 - index));
                  return _orders
                      .where(
                        (order) =>
                            order.completedAt != null &&
                            _sameDay(order.completedAt!.toLocal(), day),
                      )
                      .fold<double>(
                        0,
                        (sum, order) => sum + (order.compensationRupees ?? 0),
                      );
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's earnings",
                  style: TextStyle(fontSize: 14, color: workerMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  paise == null ? 'Unavailable' : formatCustomerPaise(paise),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: paise == null ? 30 : 44,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    color: workerInk,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFB4F5D2),
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 17,
                        color: Color(0xFF00AC61),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      widget.demoMode ? '+18% this week' : 'Confirmed earnings',
                      style: const TextStyle(fontSize: 12, color: workerInk),
                    ),
                  ],
                ),
                const Spacer(),
                const Divider(height: 12, color: Color(0xFFFFCEE0)),
                Row(
                  children: [
                    Text(
                      goal == null
                          ? 'Daily goal \u2014'
                          : 'Daily goal \u20b93,000',
                      style: const TextStyle(fontSize: 12, color: workerInk),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFFFB8D5),
                          color: workerPink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      goal == null || paise == null
                          ? '\u2014'
                          : '${(progress * 100).round()}%',
                      style: const TextStyle(fontSize: 12, color: workerInk),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Expanded(
    child: Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: workerReferenceSurface(radius: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: workerInk,
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(color: workerMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
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
              Text('View all', style: TextStyle(color: _pink, fontSize: 12)),
              Icon(Icons.chevron_right_rounded, color: _pink, size: 18),
            ],
          ),
        ),
    ],
  );

  Widget _offersSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final banner in _liveBanners)
        Card(
          child: ListTile(
            title: Text('${banner['name'] ?? ''}'),
            subtitle: Text('${banner['subtitle'] ?? ''}'),
          ),
        ),
    ],
  );

  Widget _dashboardImage(
    WorkerDashboardOrder order,
    double width,
    double height,
  ) {
    final name = order.service.toLowerCase();
    final asset = name.contains('facial')
        ? 'reference_facial.png'
        : name.contains('hair')
        ? 'reference_hair.png'
        : name.contains('bridal')
        ? 'reference_bridal.png'
        : null;
    if (widget.demoMode && asset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          'assets/images/dashboard/$asset',
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }
    return WorkerServiceImage(
      service: order.service,
      serviceId: order.serviceId,
      imageUrl: order.serviceImageUrl,
      demoMode: widget.demoMode,
      width: width,
      height: height,
    );
  }

  Widget _appointmentLine({required IconData icon, required String text}) =>
      Row(
        children: [
          Icon(icon, size: 15, color: workerInk),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: workerMuted,
              ),
            ),
          ),
        ],
      );

  Widget _appointmentCard(WorkerDashboardOrder? next, DateTime now) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Your next appointment', onSeeAll: _openBookings),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: workerReferenceSurface(),
        child: next == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'No upcoming appointment is scheduled yet.',
                  style: TextStyle(fontSize: 12, color: workerMuted),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE6F1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'UP NEXT \u00b7 ${next.time}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: workerPink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dashboardImage(next, 94, 76),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              next.service,
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: workerInk,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _appointmentLine(
                              icon: Icons.person_outline,
                              text: next.customer,
                            ),
                            _appointmentLine(
                              icon: Icons.access_time,
                              text:
                                  '${next.duration} | ${next.formattedCustomerPayable}',
                            ),
                            _appointmentLine(
                              icon: Icons.location_on_outlined,
                              text: next.location,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: FilledButton.icon(
                            onPressed: () => _openOrder(next),
                            icon: const Icon(Icons.near_me_rounded, size: 21),
                            label: const Text(
                              'Start Navigation',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: workerPink,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      SizedBox(
                        width: 52,
                        height: 38,
                        child: OutlinedButton(
                          onPressed: () => _openOrder(next),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: workerPink,
                            side: const BorderSide(color: workerPink),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Icon(Icons.call_rounded, size: 23),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    ],
  );

  Widget _activeServiceCard(WorkerDashboardOrder order) => Container(
    padding: const EdgeInsets.all(12),
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

  Widget _scheduleRow(WorkerDashboardOrder order) => SizedBox(
    height: 46,
    child: Row(
      children: [
        SizedBox(
          width: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Container(width: 1, color: const Color(0xFFFFB9D5)),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: workerPink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                onTap: () => _openOrder(order),
                borderRadius: BorderRadius.circular(11),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        order.time,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: workerInk,
                        ),
                      ),
                    ),
                    _dashboardImage(order, 58, 38),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.service,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: workerInk,
                            ),
                          ),
                          Text(
                            order.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: workerMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                        color: workerMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
    final todayCompletedOrders = orders
        .where(
          (order) =>
              completionDates[order.id] != null &&
              _sameDay(completionDates[order.id]!, now),
        )
        .toList();
    final earningsKnown =
        widget.orders != null &&
        completedIdsWithoutDate.isEmpty &&
        todayCompletedOrders.every((order) => order.compensationRupees != null);
    final todayEarnings = earningsKnown
        ? todayCompletedOrders.fold<int>(
            0,
            (total, order) => total + order.compensationRupees! * 100,
          )
        : null;
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(
          context,
        ).textTheme.apply(fontFamily: 'WorkerDashboardText'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBFD),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: widget.demoMode && (_storeLoading || _storeError != null)
                  ? Center(
                      child: _storeLoading
                          ? const CircularProgressIndicator(color: workerPink)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Could not load saved demo bookings.',
                                ),
                                TextButton(
                                  onPressed: _loadDemoStore,
                                  child: const Text('Retry loading'),
                                ),
                              ],
                            ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _hero(online, pendingCount),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _earningsCard(todayEarnings),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _overviewStat(
                                      icon: Icons.calendar_month_rounded,
                                      label: 'Bookings',
                                      value: '$todayCount',
                                      color: workerPink,
                                    ),
                                    const SizedBox(width: 7),
                                    _overviewStat(
                                      icon: Icons.check_circle,
                                      label: 'Completed',
                                      value:
                                          completedToday?.toString() ??
                                          '\u2014',
                                      color: const Color(0xFF00BE69),
                                    ),
                                    const SizedBox(width: 7),
                                    _overviewStat(
                                      icon: Icons.star_rounded,
                                      label: 'Rating',
                                      value: widget.demoMode ? '4.9' : '\u2014',
                                      color: const Color(0xFFFFA000),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (activeOrder != null) ...[
                                  _activeServiceCard(activeOrder),
                                  const SizedBox(height: 12),
                                ],
                                _appointmentCard(next, now),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        "Today's schedule",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: workerInk,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][now.weekday - 1]}, ${now.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][now.month - 1]}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: workerMuted,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        tooltip: 'My Schedule',
                                        onPressed: _openScheduleLeave,
                                        icon: const Icon(
                                          Icons.calendar_month_outlined,
                                          size: 19,
                                          color: workerMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (todaySchedule.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: workerReferenceSurface(),
                                    child: const Text(
                                      'No appointments scheduled for today.',
                                      style: TextStyle(
                                        color: workerMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                else
                                  for (final order
                                      in todaySchedule
                                          .where((item) => item.id != next?.id)
                                          .take(2))
                                    _scheduleRow(order),
                                _offersSection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        bottomNavigationBar: WorkerReferenceNav(
          selected: 0,
          onSelected: (index) => _navigate(index == 3 ? 4 : index),
        ),
      ),
    );
  }
}

/// Uses only confirmed compensation for the decorative earnings sparkline.
class _DashboardEarningsChart extends CustomPainter {
  const _DashboardEarningsChart({required this.values});
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final maximum = values.fold<double>(0, (a, b) => a > b ? a : b);
    if (maximum <= 0) return;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          i * size.width / (values.length - 1),
          size.height - 3 - values[i] / maximum * (size.height - 8),
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = workerPink.withValues(alpha: .06));
    canvas.drawPath(
      line,
      Paint()
        ..color = workerPink
        ..strokeWidth = 1.7
        ..style = PaintingStyle.stroke,
    );
    for (final point in points) {
      canvas.drawCircle(point, 2.3, Paint()..color = workerPink);
      canvas.drawCircle(point, 1.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardEarningsChart oldDelegate) => true;
}
