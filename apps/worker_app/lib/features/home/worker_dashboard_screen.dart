import 'package:flutter/material.dart';
import 'worker_booking_data.dart';
import 'worker_demo_booking_store.dart';
import 'worker_booking_session.dart';
import 'worker_bookings_screen.dart';
import 'worker_incoming_booking_screen.dart';
import 'worker_booking_details_screen.dart';
import '../../app/slide_page_route.dart';

// Preserve the original public model import path for existing callers.
export 'worker_booking_data.dart' show WorkerDashboardOrder;

// Pinkora worker dashboard — frontend preview only.
// Do not use this local toggle or sample booking data for production dispatch.
// Backend must enforce worker approval, online status and active-service locks.

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    super.key,
    this.workerName = 'Priya',
    this.location = 'Your service area',
    this.isApproved = false,
    this.activeService = false,
    this.demoMode = true,
    this.orders = const [],
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
  /// Must come from authenticated, backend-verified account state in production.
  final bool isApproved;
  /// Must come from server-side booking state in production.
  final bool activeService;
  /// Only true for development previews; no actual dispatch occurs.
  final bool demoMode;
  final List<WorkerDashboardOrder> orders;
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
      if (mounted) setState(() { _storeLoading = false; _storeError = null; });
    } catch (error) {
      if (mounted) setState(() { _storeLoading = false; _storeError = error; });
    }
  }

  void _onStoreChanged() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    if (widget.demoMode) WorkerDemoBookingStore.repository.removeListener(_onStoreChanged);
    super.dispose();
  }

  List<WorkerDashboardOrder> get _orders {
    final source = widget.demoMode && widget.orders.isEmpty
        ? previewWorkerOrders : widget.orders;
    if (!widget.demoMode || _storeLoading || _storeError != null) return source;
    return WorkerDemoBookingStore.resolveAll(source);
  }

  bool get _isOnline => widget.demoMode ? _previewOnline : false;

  String _rupees(int amount) => formatCustomerRupees(amount);

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
    if (!desired && (widget.activeService || (widget.demoMode && WorkerDemoBookingStore.repository.hasActivePhysicalService))) {
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
        _notice(accepted
            ? 'Request accepted. Refreshing backend availability is required.'
            : 'The server did not accept the availability change.');
      }
    } catch (_) {
      _notice('Unable to update availability. Please retry.');
    } finally {
      if (mounted) setState(() => _availabilityBusy = false);
    }
  }

  void _openOrder(WorkerDashboardOrder order) {
    if (widget.demoMode && (_storeLoading || _storeError != null)) {
      _notice('Booking state is not loaded. Retry loading before opening a booking.');
      return;
    }
    if (widget.onOrderTap != null) {
      widget.onOrderTap!(order);
      return;
    }
    Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerBookingDetailsScreen(order: order, demoMode: widget.demoMode),
      ),
    );
  }

  void _openBookings() {
    if (widget.demoMode && (_storeLoading || _storeError != null)) {
      _notice('Booking state is not loaded. Retry loading before opening bookings.');
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

  Future<void> _previewIncomingOffer() async {
    if (!widget.demoMode || _storeLoading || _storeError != null) return;
    if (!_previewOnline) {
      _notice('Go Online first to preview a booking offer.');
      return;
    }
    final source = _orders.isEmpty ? previewWorkerOrders : _orders;
    if (source.isEmpty) {
      _notice('No sample order available for preview.');
      return;
    }
    final chosen = source.firstWhere(
      (item) => item.status.toLowerCase() == 'scheduled',
      orElse: () => source.first,
    );
    final result = await Navigator.of(context).push<WorkerOfferDecision>(
      MaterialPageRoute(builder: (_) => WorkerIncomingBookingScreen(
        order: chosen,
        ongoingService: widget.activeService || WorkerDemoBookingStore.repository.hasActivePhysicalService,
      )),
    );
    if (!mounted || result == null) return;
    switch (result.type) {
      case WorkerOfferDecisionType.accepted:
        _notice('Demo acceptance only — no booking was assigned.');
      case WorkerOfferDecisionType.rejected:
        _notice('Demo rejection: ${result.rejection?.reason ?? 'reason unavailable'}. No penalty.');
      case WorkerOfferDecisionType.expired:
        _notice('Demo offer expired. No booking was changed.');
    }
  }

  void _navigate(int i) {
    if (i == 0) { setState(() => _navIndex = 0); return; }
    if (i == 1) { _openBookings(); return; }
    final handlers = <VoidCallback?>[
      null, widget.onBookingsTap, widget.onPayoutsTap,
      widget.onNotificationsTap, widget.onProfileTap,
    ];
    if (handlers[i] == null) {
      _notice('${['Home', 'Bookings', 'Payouts', 'Notifications', 'Profile'][i]} screen is not connected yet.');
    } else {
      handlers[i]!();
    }
  }

  Widget _panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(16)}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: const [BoxShadow(color: Color(0x0CE91368), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: child,
      );

  Widget _heading(String text, {VoidCallback? action}) => Row(children: [
    Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _deep))),
    if (action != null) TextButton(onPressed: action, child: const Text('View All  ›', style: TextStyle(color: _pink, fontWeight: FontWeight.w700))),
  ]);

  Widget _metric(IconData icon, String label, String value, Color color) =>
      Expanded(child: _panel(Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 13),
          Text(value, style: const TextStyle(color: _deep, fontSize: 21, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.2), maxLines: 2),
        ]),
      ), padding: const EdgeInsets.all(12)));

  Widget _orderRow(WorkerDashboardOrder item) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => _openOrder(item),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 76, child: Text(item.time, style: const TextStyle(color: _deep, fontSize: 11.5, fontWeight: FontWeight.w700))),
        Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4, right: 12), decoration: const BoxDecoration(color: _pink, shape: BoxShape.circle)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.service, style: const TextStyle(color: _deep, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 2),
          Text(item.customer, style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(item.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11)),
        ])),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_rupees(item.customerPayable), style: const TextStyle(color: _deep, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 3),
          Text(item.status, style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
        const Icon(Icons.chevron_right, color: _pink, size: 18),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    final payable = orders.fold<int>(0, (a, b) => a + b.customerPayable);
    final completed = orders.where((o) => <String>{'completed', 'demo completed'}.contains(o.status.toLowerCase())).length;
    final upcoming = orders.where((o) => !<String>{'completed','demo completed','cancelled','payment pending','in progress'}.contains(o.status.toLowerCase()));
    final next = upcoming.isEmpty ? null : upcoming.first;
    final online = _isOnline;
    return Scaffold(
      backgroundColor: _cream,
      body: widget.demoMode && (_storeLoading || _storeError != null)
          ? SafeArea(child: Center(child: _storeLoading
              ? const CircularProgressIndicator(color: _pink)
              : Padding(padding: const EdgeInsets.all(24), child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load saved demo bookings.',
                        style: TextStyle(color: _deep, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text('$_storeError', textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted)),
                    TextButton(onPressed: () {setState(() {_storeLoading = true; _storeError = null;}); _loadDemoStore();},
                      child: const Text('Retry loading')),
                  ],
                ))))
          : SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 18, 17, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.spa_rounded, color: _pink, size: 33),
                const SizedBox(width: 7),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pinkora', style: TextStyle(color: _pink, fontSize: 27, fontWeight: FontWeight.w900, height: 1.05)),
                  Text('Beauty at Your Doorstep', style: TextStyle(color: _muted, fontSize: 11)),
                ])),
                IconButton(onPressed: () => _navigate(3), icon: const Icon(Icons.notifications_none_outlined, color: _deep), tooltip: 'Notifications'),
              ]),
              const SizedBox(height: 23),
              Row(children: [
                CircleAvatar(radius: 25, backgroundColor: const Color(0xFFFFE4ED), child: Text(widget.workerName.isEmpty ? 'W' : widget.workerName[0].toUpperCase(), style: const TextStyle(fontSize: 23, color: _pink, fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Good morning,', style: TextStyle(color: _muted, fontSize: 12)),
                  Text(widget.workerName, style: const TextStyle(color: _deep, fontSize: 20, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(widget.location, style: const TextStyle(color: _muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(online ? 'Online' : 'Offline', style: TextStyle(fontSize: 12, color: online ? const Color(0xFF138552) : _muted, fontWeight: FontWeight.bold)),
                    Switch.adaptive(value: online, activeColor: const Color(0xFF118B56), onChanged: _availabilityBusy ? null : _toggleAvailability),
                  ]),
                  Text(online ? 'Available for requests' : 'New requests paused', style: const TextStyle(fontSize: 10, color: _muted)),
                ]),
              ]),
              if (widget.demoMode) ...[
                const SizedBox(height: 12),
                const Text('DEVELOPMENT PREVIEW · Sample orders · No live availability or payment data', style: TextStyle(fontSize: 10, color: _muted)),
              ],
              if (widget.demoMode) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _previewIncomingOffer,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Test incoming booking offer'),
                  style: OutlinedButton.styleFrom(foregroundColor: _pink),
                ),
              ],
               if (widget.demoMode) ...[
                 Builder(builder: (context) {
                   final activeSessions = WorkerDemoBookingStore.repository.sessions
                       .where((session) =>
                           session.serviceStage == WorkerServiceStage.inProgress)
                       .toList(growable: false);
                   final active = activeSessions.isEmpty ? null : activeSessions.first;
                   if (active == null) return const SizedBox.shrink();
                   WorkerDashboardOrder? activeOrder;
                   for (final order in orders) {
                     if (order.id == active.bookingId) {
                       activeOrder = order;
                       break;
                     }
                   }
                   if (activeOrder == null) {
                     return _panel(Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text('Active demo session needs attention',
                             style: TextStyle(color: _deep, fontWeight: FontWeight.w800)),
                         Text('Booking ${active.bookingId} is saved but not present in the current list.',
                             style: const TextStyle(color: _muted, fontSize: 12)),
                       ],
                     ));
                   }
                   final order = activeOrder;
                   return Padding(
                     padding: const EdgeInsets.only(bottom: 16),
                     child: _panel(Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Row(children: [
                           Icon(Icons.play_circle_outline_rounded, color: _pink),
                           SizedBox(width: 8),
                           Text('Service in progress',
                               style: TextStyle(color: _deep, fontWeight: FontWeight.w800)),
                         ]),
                         const SizedBox(height: 7),
                         Text('${order.service} · ${order.customer}',
                             style: const TextStyle(color: _muted, fontSize: 12)),
                         const SizedBox(height: 12),
                         SizedBox(
                           width: double.infinity,
                           child: FilledButton.icon(
                             onPressed: () => _openOrder(order),
                             icon: const Icon(Icons.play_arrow_rounded),
                             label: const Text('Resume Active Service'),
                             style: FilledButton.styleFrom(
                               backgroundColor: _pink,
                               foregroundColor: Colors.white,
                             ),
                           ),
                         ),
                       ],
                     )),
                   );
                 }),
               ],
              const SizedBox(height: 18),
              Row(children: [
                _metric(Icons.calendar_month_outlined, "Today's Orders", '${orders.length}', _pink),
                const SizedBox(width: 8),
                _metric(Icons.credit_card_rounded, 'Customer Payable', _rupees(payable), const Color(0xFF189978)),
                const SizedBox(width: 8),
                _metric(Icons.verified_outlined, 'Completed Today', '$completed', const Color(0xFFD79525)),
              ]),
              const SizedBox(height: 19),
              _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _heading('Next Appointment'),
                const SizedBox(height: 8),
                if (next == null)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('No upcoming appointments.', style: TextStyle(color: _muted)))
                else ...[
                  Row(children: [
                    Container(width: 60, height: 66, decoration: BoxDecoration(color: const Color(0xFFFFE8EF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.spa, color: _pink, size: 30)),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(next.customer, style: const TextStyle(color: _deep, fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(next.service, style: const TextStyle(color: _deep, fontSize: 13)),
                      Text('${next.time}  ·  ${next.duration}', style: const TextStyle(color: _muted, fontSize: 11)),
                      Text(next.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11)),
                    ])),
                    Text(_rupees(next.customerPayable), style: const TextStyle(fontWeight: FontWeight.w800, color: _deep)),
                  ]),
                  const SizedBox(height: 13),
                  SizedBox(width: double.infinity, child: FilledButton(
                    onPressed: () => _openOrder(next),
                    style: FilledButton.styleFrom(backgroundColor: _pink, foregroundColor: Colors.white, minimumSize: const Size(0, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                    child: const Text('View Booking  ›'),
                  )),
                ],
              ])),
              const SizedBox(height: 18),
              _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _heading("Today's Orders", action: () => _navigate(1)),
                if (orders.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('No orders assigned for today.', style: TextStyle(color: _muted)))
                else ...[
                  for (var i = 0; i < orders.length; i++) ...[
                    _orderRow(orders[i]),
                    if (i != orders.length - 1) const Divider(height: 1, color: _border),
                  ],
                ],
              ])),
              const SizedBox(height: 18),
              _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('How a booking works', style: TextStyle(color: _deep, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 9, children: const [
                  _StepPill('1', 'Accept'), _StepPill('2', 'Travel'), _StepPill('3', 'Start OTP'),
                  _StepPill('4', 'Finish service'), _StepPill('5', 'Customer pays'),
                ]),
              ])),
              const SizedBox(height: 18),
              _panel(const Row(children: [
                Icon(Icons.payment_rounded, color: _pink, size: 30), SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Customer payment after service', style: TextStyle(color: _deep, fontWeight: FontWeight.w800, fontSize: 13)),
                  SizedBox(height: 5),
                  Text('The customer pays in the customer app after the worker finishes the service. Payment must be verified by the backend.', style: TextStyle(color: _muted, fontSize: 11, height: 1.4)),
                ])),
              ])),
              const SizedBox(height: 20),
            ]),
          )),
        ]),
      ))),
      bottomNavigationBar: SafeArea(top: false, child: NavigationBar(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE2EC),
        selectedIndex: _navIndex,
        onDestinationSelected: _navigate,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: _pink), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Payouts'),
          NavigationDestination(icon: Icon(Icons.notifications_none_outlined), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      )),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill(this.step, this.label);
  final String step;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFFFFEDF3), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(radius: 10, backgroundColor: _pink, child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 10))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: _deep, fontWeight: FontWeight.w600)),
    ]),
  );
}
