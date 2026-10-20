import 'package:flutter/material.dart';
import 'worker_booking_data.dart';
import 'worker_demo_booking_store.dart';
import 'worker_booking_details_screen.dart';
import 'worker_booking_session.dart';
import '../../app/slide_page_route.dart';
import '../widgets/worker_design.dart';

const _pink = WorkerDesign.pink;
const _deep = WorkerDesign.deep;
const _muted = WorkerDesign.muted;
const _cream = WorkerDesign.cream;
const _border = WorkerDesign.border;

/// Frontend-only bookings view. No booking state transition or payment is made.
class WorkerBookingsScreen extends StatefulWidget {
  const WorkerBookingsScreen({
    super.key,
    required this.orders,
    this.demoMode = true,
    this.onOrderTap,
  });

  final List<WorkerDashboardOrder> orders;
  final bool demoMode;
  final ValueChanged<WorkerDashboardOrder>? onOrderTap;

  @override
  State<WorkerBookingsScreen> createState() => _WorkerBookingsScreenState();
}

class _WorkerBookingsScreenState extends State<WorkerBookingsScreen> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'All';
  static const _filters = [
    'All',
    'Upcoming',
    'Ongoing',
    'Completed',
    'Cancelled',
  ];
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

  bool _matches(WorkerDashboardOrder order) {
    final s = order.status.toLowerCase().trim();
    final statusMatches = switch (_filter) {
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
    final q = _search.text.trim().toLowerCase();
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentOrders = widget.demoMode && !_loading && _storeError == null
        ? WorkerDemoBookingStore.resolveAll(widget.orders)
        : widget.orders;
    final visible = currentOrders.where(_matches).toList();
    final total = visible.fold<int>(
      0,
      (sum, order) => sum + order.customerPayable,
    );
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text(
          'Bookings',
          style: TextStyle(
            color: _deep,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: _cream,
        foregroundColor: _deep,
        surfaceTintColor: _cream,
        centerTitle: true,
      ),
      body: widget.demoMode && (_loading || _storeError != null)
          ? SafeArea(
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator(color: _pink)
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Could not load saved demo bookings'),
                            Text('$_storeError', textAlign: TextAlign.center),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _storeError = null;
                                });
                                _loadStore();
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
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(17, 10, 17, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const WorkerPageBanner(
                              eyebrow: 'Your workday',
                              title: 'My Bookings',
                              subtitle:
                                  'Every appointment, beautifully organized.',
                              icon: Icons.calendar_month_outlined,
                              photo: true,
                            ),
                            const SizedBox(height: 15),
                            if (widget.demoMode) ...[
                              const Text(
                                'DEVELOPMENT PREVIEW · Sample bookings · No live dispatch or payments',
                                style: TextStyle(color: _muted, fontSize: 10),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText:
                                    'Search customer, service or booking ID',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: _muted,
                                ),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: _search.clear,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 19,
                                        ),
                                      ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: _border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: _border),
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final name in _filters) ...[
                                    ChoiceChip(
                                      label: Text(name),
                                      selected: _filter == name,
                                      selectedColor: const Color(0xFFFFDAE8),
                                      backgroundColor: Colors.white,
                                      labelStyle: TextStyle(
                                        color: _filter == name ? _pink : _deep,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                      side: BorderSide(
                                        color: _filter == name
                                            ? _pink
                                            : _border,
                                      ),
                                      showCheckmark: false,
                                      onSelected: (_) =>
                                          setState(() => _filter = name),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${visible.length} booking${visible.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: _deep,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Customer payable',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      formatCustomerRupees(total),
                                      style: const TextStyle(
                                        color: _deep,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(30),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.event_busy_outlined,
                                        color: _pink,
                                        size: 46,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _search.text.isNotEmpty
                                            ? 'No matching bookings'
                                            : 'No $_filter bookings',
                                        style: const TextStyle(
                                          color: _deep,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Try a different search or booking status.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextButton(
                                        onPressed: () {
                                          _search.clear();
                                          setState(() => _filter = 'All');
                                        },
                                        child: const Text('Show all bookings'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.fromLTRB(
                                  17,
                                  4,
                                  17,
                                  20,
                                ),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 11),
                                itemBuilder: (context, index) {
                                  final o = visible[index];
                                  final statusColor = _statusColor(o.status);
                                  final running =
                                      widget.demoMode &&
                                      WorkerDemoBookingStore.session(
                                            o.id,
                                          )?.serviceStage ==
                                          WorkerServiceStage.inProgress;
                                  return Material(
                                    color: Colors.white,
                                    elevation: 3,
                                    shadowColor: const Color(0x18C74776),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: const BorderSide(color: _border),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _open(o),
                                      child: Padding(
                                        padding: const EdgeInsets.all(15),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    o.id,
                                                    style: const TextStyle(
                                                      color: _muted,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withValues(
                                                          alpha: 0.10,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  child: Text(
                                                    o.status,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 54,
                                                  height: 58,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFFE4EE,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          13,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.spa_rounded,
                                                    color: _pink,
                                                    size: 27,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        o.service,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: _deep,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        o.customer,
                                                        style: const TextStyle(
                                                          color: _muted,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 7),
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.access_time,
                                                            size: 14,
                                                            color: _pink,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              '${o.time}  ·  ${o.duration}',
                                                              style:
                                                                  const TextStyle(
                                                                    color:
                                                                        _muted,
                                                                    fontSize:
                                                                        11,
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
                                            const SizedBox(height: 11),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 15,
                                                  color: _pink,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    o.location,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: _muted,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Divider(
                                              height: 1,
                                              color: _border,
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Customer payable',
                                                        style: TextStyle(
                                                          color: _muted,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        formatCustomerRupees(
                                                          o.customerPayable,
                                                        ),
                                                        style: const TextStyle(
                                                          color: _deep,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 17,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  running
                                                      ? 'Resume Service'
                                                      : 'View details',
                                                  style: const TextStyle(
                                                    color: _pink,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                const Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: _pink,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
