import '../widgets/worker_reference_widgets.dart';
import '../widgets/worker_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../integration/worker_api.dart';
import 'worker_booking_data.dart';
import 'worker_demo_booking_store.dart';
import 'worker_booking_details_screen.dart';
import 'worker_booking_session.dart';
import '../../app/slide_page_route.dart';
import '../widgets/worker_design.dart';

const _pink = WorkerDesign.pink;
const _border = WorkerDesign.border;

/// Frontend-only bookings view. No booking state transition or payment is made.
class WorkerBookingsScreen extends StatefulWidget {
  const WorkerBookingsScreen({
    super.key,
    required this.orders,
    this.demoMode = true,
    this.onOrderTap,
    this.operationsApi,
    this.location,
    this.onNotificationsTap,
    this.unreadNotifications = 0,
    this.onNavigationSelected,
  });

  final List<WorkerDashboardOrder> orders;
  final bool demoMode;
  final ValueChanged<WorkerDashboardOrder>? onOrderTap;
  final WorkerOperationsApi? operationsApi;
  final String? location;
  final VoidCallback? onNotificationsTap;
  final int unreadNotifications;
  final ValueChanged<int>? onNavigationSelected;

  @override
  State<WorkerBookingsScreen> createState() => _WorkerBookingsScreenState();
}

class _WorkerBookingsScreenState extends State<WorkerBookingsScreen> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'All';
  DateTime? _selectedDate;
  bool _searchOpen = false;
  bool _loading = true;
  Object? _storeError;

  Future<void> _loadStore() async {
    try {
      await WorkerDemoBookingStore.initialize();
      if (mounted) {
        setState(() {
          _loading = false;
          _storeError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _storeError = error;
        });
      }
    }
  }

  void _storeUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.addListener(_storeUpdated);
      _loadStore();
    } else {
      _loading = false;
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (widget.demoMode)
      WorkerDemoBookingStore.repository.removeListener(_storeUpdated);
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  bool _matches(
    WorkerDashboardOrder order, {
    String? filter,
    bool includeSearch = true,
  }) {
    final s = order.status.toLowerCase().trim();
    final statusMatches = switch (filter ?? _filter) {
      'Upcoming' => [
        'scheduled',
        'accepted',
        'upcoming',
        'confirmed',
        'assigned',
      ].contains(s),
      'Ongoing' => [
        'ongoing',
        'in progress',
        'in_progress',
        'arrived',
        'travelling',
        'traveling',
        'service_started',
        'payment pending',
      ].contains(s),
      'Completed' => [
        'completed',
        'paid',
        'closed',
        'demo completed',
      ].contains(s),
      'Cancelled' => ['cancelled', 'canceled'].contains(s),
      _ => true,
    };
    final q = includeSearch ? _search.text.trim().toLowerCase() : '';
    return statusMatches &&
        (q.isEmpty ||
            [
              order.id,
              order.customer,
              order.service,
              order.location,
              order.status,
            ].any((value) => value.toLowerCase().contains(q)));
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (['completed', 'paid', 'closed', 'demo completed'].contains(s))
      return const Color(0xFF16865E);
    if (s == 'cancelled' || s == 'canceled') return const Color(0xFF9B606A);
    if ([
      'ongoing',
      'in progress',
      'in_progress',
      'arrived',
      'travelling',
      'traveling',
      'service_started',
      'payment pending',
    ].contains(s)) {
      return const Color(0xFFB96F15);
    }
    return _pink;
  }

  void _open(WorkerDashboardOrder order) {
    if (widget.demoMode && (_loading || _storeError != null)) return;
    if (widget.onOrderTap != null) {
      widget.onOrderTap!(order);
      return;
    }
    // Always open the live Details route, which has the repository-backed
    // Resume Demo Service action for saved in-progress sessions.
    Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerBookingDetailsScreen(
          order: widget.demoMode
              ? WorkerDemoBookingStore.resolve(order)
              : order,
          demoMode: widget.demoMode,
          operationsApi: widget.operationsApi,
        ),
      ),
    );
  }

  bool _onDate(WorkerDashboardOrder order) {
    final date = order.appointmentDate?.toLocal();
    return _selectedDate == null ||
        (date != null && DateUtils.isSameDay(date, _selectedDate));
  }

  Widget _calendar() {
    final today = DateUtils.dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            Builder(
              builder: (context) {
                final date = monday.add(Duration(days: i));
                final selected = DateUtils.isSameDay(date, _selectedDate);
                return InkWell(
                  onTap: () =>
                      setState(() => _selectedDate = selected ? null : date),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: workerReferenceSurface(
                      tinted: selected,
                      radius: 12,
                    ).copyWith(color: selected ? workerPink : Colors.white),
                    child: Column(
                      children: [
                        Text(
                          weekdays[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: selected ? Colors.white : workerMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}'.padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : workerInk,
                          ),
                        ),
                        Text(
                          months[date.month - 1],
                          style: TextStyle(
                            fontSize: 10,
                            color: selected ? Colors.white : workerMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (i < 6) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _bookingCard(WorkerDashboardOrder order) {
    final statusColor = _statusColor(order.status);
    final running =
        widget.demoMode &&
        WorkerDemoBookingStore.session(order.id)?.serviceStage ==
            WorkerServiceStage.inProgress;
    return Container(
      decoration: workerReferenceSurface(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(order),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkerServiceImage(
                  service: order.service,
                  serviceId: order.serviceId,
                  imageUrl: order.serviceImageUrl,
                  demoMode: widget.demoMode,
                  width: MediaQuery.sizeOf(context).width < 350 ? 76 : 102,
                  height: 112,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              order.service,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: workerInk,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              running ? 'In progress' : order.status,
                              style: TextStyle(
                                fontSize: 8,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      WorkerReferenceLine(
                        icon: Icons.person_outline,
                        text: order.customer,
                      ),
                      WorkerReferenceLine(
                        icon: Icons.access_time,
                        text: order.time,
                      ),
                      WorkerReferenceLine(
                        icon: Icons.location_on_outlined,
                        text: order.location.isEmpty
                            ? 'Address unavailable'
                            : order.location,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: WorkerReferenceLine(
                              icon: Icons.currency_rupee,
                              text: order.formattedCustomerPayable.replaceFirst(
                                '\u20b9',
                                '',
                              ),
                              strong: true,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _open(order),
                            icon: const Icon(Icons.chevron_right, size: 14),
                            label: const Text(
                              'Details',
                              style: TextStyle(fontSize: 10),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: workerPink,
                              minimumSize: const Size(0, 27),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentOrders = widget.demoMode && !_loading && _storeError == null
        ? WorkerDemoBookingStore.resolveAll(widget.orders)
        : widget.orders;
    final visible = currentOrders
        .where((order) => _matches(order) && _onDate(order))
        .toList();
    final totalPaise = visible.fold<int>(
      0,
      (sum, order) => sum + order.exactCustomerPayablePaise,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: widget.demoMode && (_loading || _storeError != null)
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator(color: workerPink)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Could not load saved demo bookings'),
                              TextButton(
                                onPressed: _loadStore,
                                child: const Text('Retry loading'),
                              ),
                            ],
                          ),
                  )
                : Column(
                    children: [
                      WorkerReferenceHeader(
                        location: widget.location,
                        onNotifications: widget.onNotificationsTap,
                        unread: widget.unreadNotifications,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'My Bookings',
                                    style: TextStyle(
                                      fontSize: 28,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                      color: workerInk,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Search bookings',
                                  onPressed: () => setState(
                                    () => _searchOpen = !_searchOpen,
                                  ),
                                  icon: const Icon(
                                    Icons.search,
                                    size: 21,
                                    color: workerMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Manage and track all your appointments.',
                              style: TextStyle(
                                fontSize: 12,
                                color: workerMuted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: workerReferenceSurface(tinted: true),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final name in [
                                      'Upcoming',
                                      'Ongoing',
                                      'Completed',
                                      'All',
                                      'Cancelled',
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: ChoiceChip(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(name),
                                              Text(
                                                ' (${currentOrders.where((order) => _matches(order, filter: name, includeSearch: false)).length})',
                                              ),
                                            ],
                                          ),
                                          showCheckmark: false,
                                          selected: _filter == name,
                                          selectedColor: workerPink,
                                          backgroundColor: Colors.transparent,
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                          ),
                                          labelStyle: TextStyle(
                                            fontSize: 11,
                                            color: _filter == name
                                                ? Colors.white
                                                : workerInk,
                                          ),
                                          onSelected: (_) {
                                            HapticFeedback.lightImpact();
                                            setState(() => _filter = name);
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _calendar(),
                            const SizedBox(height: 10),
                            if (_searchOpen || _search.text.isNotEmpty)
                              TextField(
                                controller: _search,
                                textInputAction: TextInputAction.search,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search customer, service or booking ID',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 19,
                                    color: workerMuted,
                                  ),
                                  suffixIcon: _search.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: _search.clear,
                                          icon: const Icon(
                                            Icons.close,
                                            size: 17,
                                          ),
                                        ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: _border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: _border,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${visible.length} booking${visible.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: workerMuted,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Payable  ${formatCustomerPaise(totalPaise)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: workerInk,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.demoMode)
                              const Text(
                                'DEVELOPMENT PREVIEW - Sample bookings',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: workerMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.event_busy_outlined,
                                      color: workerPink,
                                      size: 30,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _search.text.isNotEmpty
                                          ? 'No matching bookings'
                                          : 'No $_filter bookings',
                                      style: const TextStyle(color: workerInk),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _search.clear();
                                        setState(() {
                                          _filter = 'All';
                                          _selectedDate = null;
                                        });
                                      },
                                      child: const Text('Show all bookings'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  14,
                                  18,
                                ),
                                itemCount: visible.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) =>
                                    _bookingCard(visible[index]),
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: widget.onNavigationSelected == null
          ? null
          : WorkerReferenceNav(
              selected: 1,
              onSelected: (index) {
                if (index != 1) widget.onNavigationSelected!(index);
              },
            ),
    );
  }
}
