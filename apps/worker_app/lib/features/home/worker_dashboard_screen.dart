import '../widgets/worker_reference_widgets.dart';
import '../widgets/worker_auth_visuals.dart';
import '../widgets/worker_images.dart';
import '../schedule/worker_leave_repository.dart';

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

const _pink = Color(0xFFF52D7A);
const _deep = Color(0xFF210B35);
const _muted = Color(0xFF686080);
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
        onNotifications: _openNotifications,
        unread: widget.notificationRepository?.unreadCount ?? 0,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 14, 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: _openProfileSettings,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22F52D7A), blurRadius: 10),
                  ],
                ),
                child: WorkerProfilePhoto(
                  path: widget.profilePhotoPath,
                  size: 65,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_greeting,',
                    style: const TextStyle(color: workerMuted, fontSize: 12),
                  ),
                  Text(
                    widget.workerName.split(' ').first,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: workerInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Let\'s make today beautiful.',
                    style: TextStyle(fontSize: 10, color: workerMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    online ? "You're Online" : "You're Offline",
                    style: TextStyle(
                      fontSize: 10,
                      color: online ? const Color(0xFF00984B) : workerMuted,
                    ),
                  ),
                  SizedBox(
                    height: 31,
                    width: 70,
                    child: Transform.scale(
                      scale: .72,
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

  Widget _earningsCard(int? paise) => Container(
    decoration: workerReferenceSurface(tinted: true),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        const Positioned(
          right: -8,
          top: 2,
          width: 128,
          child: Opacity(opacity: .55, child: WorkerLotusArtwork()),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today\'s earnings',
                style: TextStyle(fontSize: 14, color: workerMuted),
              ),
              const SizedBox(height: 6),
              Text(
                paise == null ? 'Unavailable' : formatCustomerPaise(paise),
                style: const TextStyle(
                  fontSize: 42,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: workerInk,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFFFFD3E3), height: 10),
              Text(
                paise == null
                    ? 'Earnings awaiting confirmed compensation'
                    : 'Confirmed compensation from completed services',
                style: const TextStyle(
                  fontSize: 10,
                  color: workerMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _dashboardAction({
    Key? key,
    required IconData icon,
    required String label,
    required String detail,
    required VoidCallback onTap,
    int? badge,
    Color color = _pink,
  }) => SizedBox(
    width: (MediaQuery.sizeOf(context).width.clamp(0, 440) - 30) / 2,
    child: InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Badge(
              isLabelVisible: badge != null,
              label: Text('$badge'),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _deep,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _appointmentCard(WorkerDashboardOrder? next, DateTime now) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Your next appointment', onSeeAll: _openBookings),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
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
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE6F1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'UP NEXT | ${next.time}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: workerPink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WorkerServiceImage(
                        service: next.service,
                        serviceId: next.serviceId,
                        imageUrl: next.serviceImageUrl,
                        demoMode: widget.demoMode,
                        width: 90,
                        height: 85,
                      ),
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
                            const SizedBox(height: 5),
                            WorkerReferenceLine(
                              icon: Icons.person_outline,
                              text: next.customer,
                            ),
                            WorkerReferenceLine(
                              icon: Icons.access_time,
                              text:
                                  '${next.duration} | ${next.formattedCustomerPayable}',
                            ),
                            WorkerReferenceLine(
                              icon: Icons.location_on_outlined,
                              text: next.location,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => _openOrder(next),
                    icon: const Icon(Icons.near_me_rounded, size: 19),
                    label: const Text('View appointment'),
                    style: FilledButton.styleFrom(
                      backgroundColor: workerPink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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

  Widget _scheduleRow(WorkerDashboardOrder order) => InkWell(
    onTap: () => _openOrder(order),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: workerReferenceSurface(radius: 14),
      child: Row(
        children: [
          SizedBox(
            width: 53,
            child: Text(
              order.time,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: workerInk,
              ),
            ),
          ),
          const SizedBox(width: 8),
          WorkerServiceImage(
            service: order.service,
            serviceId: order.serviceId,
            imageUrl: order.serviceImageUrl,
            demoMode: widget.demoMode,
            width: 56,
            height: 43,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.service,
                  style: const TextStyle(
                    fontSize: 13,
                    color: workerInk,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  order.customer,
                  style: const TextStyle(fontSize: 11, color: workerMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: workerMuted),
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
      (total, order) =>
          total + (order.customerPayablePaise ?? order.customerPayable * 100),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: widget.demoMode && (_storeLoading || _storeError != null)
                ? Center(
                    child: _storeLoading
                        ? const CircularProgressIndicator(color: workerPink)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Could not load saved demo bookings.'),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                decoration: workerReferenceSurface(),
                                child: Row(
                                  children: [
                                    _overviewStat(
                                      icon: Icons.calendar_month_outlined,
                                      label: "Today's Bookings",
                                      value: '$todayCount',
                                      color: workerPink,
                                    ),
                                    _overviewStat(
                                      icon: Icons.check_circle_outline,
                                      label: 'Completed Today',
                                      value:
                                          completedToday?.toString() ??
                                          'Unavailable',
                                      color: const Color(0xFF00BE69),
                                    ),
                                    _overviewStat(
                                      icon: Icons.payments_outlined,
                                      label: 'Customer Payable',
                                      value: formatCustomerPaise(
                                        todayCustomerPayable,
                                      ),
                                      color: const Color(0xFFEF9B34),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (activeOrder != null) ...[
                                _activeServiceCard(activeOrder),
                                const SizedBox(height: 12),
                              ],
                              _appointmentCard(next, now),
                              const SizedBox(height: 14),
                              _sectionTitle(
                                "Today's Schedule",
                                onSeeAll: _openScheduleLeave,
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
                                for (final order in todaySchedule.take(3))
                                  _scheduleRow(order),
                              const SizedBox(height: 14),
                              _sectionTitle(
                                'Manage Your Work',
                                onSeeAll: _openBookings,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: workerReferenceSurface(),
                                child: Wrap(
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
                                    _dashboardAction(
                                      icon: Icons.calendar_today_outlined,
                                      label: 'My Schedule',
                                      detail:
                                          'View your daily schedule and leave',
                                      onTap: _openScheduleLeave,
                                    ),
                                    _dashboardAction(
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      label: 'Payouts & Earnings',
                                      detail: 'Track earnings and payouts',
                                      color: const Color(0xFF00A95C),
                                      onTap: _openPayouts,
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
                              const SizedBox(height: 14),
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
    );
  }
}
