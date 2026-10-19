import 'package:flutter/material.dart';
import 'worker_booking_data.dart';
import 'worker_demo_booking_store.dart';
import 'worker_booking_details_screen.dart';
import '../../app/slide_page_route.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

/// A read-only view of terminal bookings. Does not change booking or payment state.
/// The caller supplies authenticated worker-scoped bookings outside demo mode.
class WorkerServiceHistoryScreen extends StatefulWidget {
  const WorkerServiceHistoryScreen({
    super.key,
    required this.orders,
    this.demoMode = true,
    this.onOrderTap,
  });

  final List<WorkerDashboardOrder> orders;
  final bool demoMode;
  final ValueChanged<WorkerDashboardOrder>? onOrderTap;

  @override
  State<WorkerServiceHistoryScreen> createState() => _WorkerServiceHistoryScreenState();
}

/// Shared, side-effect-free filter usable by widget tests and future APIs.
List<WorkerDashboardOrder> filterWorkerServiceHistory(
  List<WorkerDashboardOrder> orders, {
  String filter = 'All',
  String query = '',
}) {
  final normalized = query.trim().toLowerCase();
  return orders.where((order) {
    final status = order.status.trim().toLowerCase();
    final completed = const {'completed', 'paid', 'closed', 'demo completed'}.contains(status);
    final cancelled = const {'cancelled', 'canceled'}.contains(status);
    if (!completed && !cancelled) return false;
    if (filter == 'Completed' && !completed) return false;
    if (filter == 'Cancelled' && !cancelled) return false;
    return normalized.isEmpty ||
        [order.id, order.customer, order.service, order.location, order.status]
            .any((part) => part.toLowerCase().contains(normalized));
  }).toList(growable: false);
}

class _WorkerServiceHistoryScreenState extends State<WorkerServiceHistoryScreen> {
  final _search = TextEditingController();
  String _filter = 'All';
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    if (widget.demoMode) {
      WorkerDemoBookingStore.repository.addListener(_refresh);
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await WorkerDemoBookingStore.initialize();
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = error; });
    }
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    if (widget.demoMode) WorkerDemoBookingStore.repository.removeListener(_refresh);
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _open(WorkerDashboardOrder order) {
    if (widget.onOrderTap != null) {
      widget.onOrderTap!(order);
      return;
    }
    Navigator.of(context).push<void>(SlidePageRoute<void>(
      page: WorkerBookingDetailsScreen(order: order, demoMode: widget.demoMode),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.demoMode && !_loading && _error == null
        ? WorkerDemoBookingStore.resolveAll(widget.orders)
        : widget.orders;
    final visible = filterWorkerServiceHistory(source, filter: _filter, query: _search.text);
    final all = filterWorkerServiceHistory(source);
    final completedCount = filterWorkerServiceHistory(source, filter: 'Completed').length;
    final cancelledCount = all.length - completedCount;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text('Service History', style: TextStyle(color: _deep, fontSize: 19, fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        foregroundColor: _deep,
      ),
      body: widget.demoMode && (_loading || _error != null)
          ? Center(child: _loading
              ? const CircularProgressIndicator(color: _pink)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, size: 38, color: _pink),
                    const SizedBox(height: 10),
                    const Text('Could not load saved demo history', style: TextStyle(fontWeight: FontWeight.w700, color: _deep)),
                    const SizedBox(height: 8),
                    Text('$_error', textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
                    TextButton(onPressed: _load, child: const Text('Retry loading')),
                  ]),
                ))
          : SafeArea(child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (widget.demoMode) ...[
                      const Text('DEVELOPMENT PREVIEW · No live bookings or verified payments',
                          style: TextStyle(fontSize: 10, color: _muted)),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      key: const Key('history-search'),
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Search service, customer or booking ID',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                        suffixIcon: _search.text.isEmpty ? null : IconButton(
                          tooltip: 'Clear search', onPressed: _search.clear,
                          icon: const Icon(Icons.close_rounded)),
                        filled: true, fillColor: Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      for (final name in const ['All', 'Completed', 'Cancelled']) ...[
                        Expanded(child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            key: Key('history-filter-$name'),
                            onTap: () => setState(() => _filter = name),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: _filter == name ? _pink : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _filter == name ? _pink : _border),
                              ),
                              child: Text(name, style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: _filter == name ? Colors.white : _muted,
                              )),
                            ),
                          ),
                        )),
                      ],
                    ]),
                    const SizedBox(height: 13),
                    Row(children: [
                      Expanded(child: Text('${visible.length} past service${visible.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: _deep, fontSize: 14, fontWeight: FontWeight.w800))),
                      Text('$completedCount completed  ·  $cancelledCount cancelled',
                          style: const TextStyle(color: _muted, fontSize: 10)),
                    ]),
                  ]),
                ),
                Expanded(child: visible.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.history_rounded, color: _pink, size: 45),
                          const SizedBox(height: 12),
                          Text(_search.text.trim().isNotEmpty ? 'No matching history' : 'No service history yet',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: _deep, fontSize: 16)),
                          const SizedBox(height: 7),
                          const Text('Completed and cancelled bookings appear here.',
                              textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12)),
                        ]),
                      ))
                    : ListView.separated(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final order = visible[index];
                          final isCancelled = const {'cancelled', 'canceled'}
                              .contains(order.status.trim().toLowerCase());
                          final color = isCancelled ? const Color(0xFF99606C) : const Color(0xFF14865E);
                          final date = order.appointmentDate;
                          final dateLabel = date == null
                              ? 'Date not available'
                              : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                          return Material(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15),
                                side: const BorderSide(color: _border)),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: Key('history-order-${order.id}'),
                              onTap: () => _open(order),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  Container(width: 56, height: 58,
                                    decoration: BoxDecoration(color: const Color(0xFFFFE6EF), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.spa_rounded, color: _pink, size: 27)),
                                  const SizedBox(width: 11),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(order.service, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: _deep, fontWeight: FontWeight.w800, fontSize: 13)),
                                    const SizedBox(height: 3),
                                    Text('${order.customer}  ·  ${order.id}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: _muted, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('$dateLabel  ·  ${order.time}',
                                        style: const TextStyle(color: _muted, fontSize: 10)),
                                    const SizedBox(height: 5),
                                    Text('Customer bill ${formatCustomerRupees(order.customerPayable)}',
                                        style: const TextStyle(color: _deep, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ])),
                                  const SizedBox(width: 5),
                                  Column(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                                      child: Text(isCancelled ? 'Cancelled' : 'Completed',
                                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                                    ),
                                    const SizedBox(height: 8),
                                    const Icon(Icons.chevron_right_rounded, color: _pink, size: 18),
                                  ]),
                                ]),
                              ),
                            ),
                          );
                        },
                      )),
              ]),
            ))),
    );
  }
}
