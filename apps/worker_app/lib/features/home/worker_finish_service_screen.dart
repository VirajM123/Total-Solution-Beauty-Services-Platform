import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'worker_booking_data.dart';
import 'worker_booking_session.dart';
import 'worker_booking_state_repository.dart';
import 'worker_demo_booking_store.dart';
import 'worker_extra_service_item.dart';
import 'worker_waiting_customer_payment_screen.dart';
import '../../app/slide_page_route.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

/// A read-only review and simulated finish action.
/// It does NOT finish the real booking, charge the customer, or verify payment.
class WorkerFinishServiceScreen extends StatefulWidget {
  const WorkerFinishServiceScreen({
    super.key,
    required this.order,
    required this.extraServices,
    required this.demoStartedAt,
    this.demoMode = true,
  });

  final WorkerDashboardOrder order;
  final List<WorkerExtraServiceItem> extraServices;
  final DateTime demoStartedAt;
  final bool demoMode;

  @override
  State<WorkerFinishServiceScreen> createState() =>
      _WorkerFinishServiceScreenState();
}

class _WorkerFinishServiceScreenState extends State<WorkerFinishServiceScreen> {
  bool _confirmed = false;
  bool _simulatedFinished = false;
  bool _saving = false;
  DateTime? _savedFinishedAt;

  @override
  void initState() {
    super.initState();
    final saved = WorkerDemoBookingStore.session(widget.order.id);
    if (saved?.serviceStage == WorkerServiceStage.finished) {
      _simulatedFinished = true;
      _savedFinishedAt = saved!.finishedAt;
    }
  }

  bool get _previewAllowed => kDebugMode && widget.demoMode;
  int get _extrasTotal => widget.extraServices.fold<int>(
    0,
    (total, extra) => total + extra.customerPrice,
  );
  int get _customerTotal => widget.order.customerPayable + _extrasTotal;

  String get _durationText {
    final diff = DateTime.now().difference(widget.demoStartedAt);
    final duration = diff.isNegative ? Duration.zero : diff;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${duration.inMinutes} min';
  }

  Widget _panel(Widget child, {Color color = Colors.white}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _moneyRow(String label, int price, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? _deep : _muted,
              fontSize: strong ? 15 : 13,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          formatCustomerRupees(price),
          style: TextStyle(
            color: strong ? _pink : _deep,
            fontSize: strong ? 19 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Future<void> _finishPreview() async {
    if (!_previewAllowed || _simulatedFinished || !_confirmed || _saving)
      return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preview finish service?'),
        content: const Text(
          'This will show a local Payment Pending preview only. '
          'No real service is finished, no customer has approved extras, '
          'and no payment request is sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simulate finish'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() => _saving = true);
    try {
      final session = await WorkerDemoBookingStore.repository.finishService(
        bookingId: widget.order.id,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _simulatedFinished = true;
        _savedFinishedAt = session.finishedAt;
      });
      await _openWaitingPaymentPreview();
    } on WorkerBookingStateException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save finished service. Please retry.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openWaitingPaymentPreview() async {
    if (!_previewAllowed ||
        !_simulatedFinished ||
        !mounted ||
        _saving && _savedFinishedAt == null)
      return;
    final session = WorkerDemoBookingStore.session(widget.order.id);
    final DateTime? finishedAt = session?.finishedAt;
    if (session?.serviceStage != WorkerServiceStage.finished ||
        finishedAt == null) {
      return;
    }
    await Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerWaitingCustomerPaymentScreen(
          order: widget.order,
          extraServices: widget.extraServices,
          demoFinishedAt: finishedAt,
          demoMode: widget.demoMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text(
          'Finish Service',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        foregroundColor: _deep,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(17, 10, 17, 22),
                    children: [
                      _panel(
                        Row(
                          children: [
                            Icon(
                              _simulatedFinished
                                  ? Icons.hourglass_top_rounded
                                  : Icons.fact_check_outlined,
                              size: 28,
                              color: _pink,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _simulatedFinished
                                        ? 'Payment Pending · Demo'
                                        : 'Review completed work',
                                    style: const TextStyle(
                                      color: _deep,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _simulatedFinished
                                        ? 'Local preview only. No actual payment was requested.'
                                        : 'Verify the customer bill before finishing the service.',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        color: const Color(0xFFFFEDF3),
                      ),
                      const SizedBox(height: 14),
                      if (_previewAllowed) ...[
                        const Text(
                          'DEVELOPMENT PREVIEW · No live service or payment changes',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customer,
                              style: const TextStyle(
                                color: _deep,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Booking ${order.id} · ${order.service}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 11),
                            Row(
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: _pink,
                                  size: 17,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'Elapsed service time: $_durationText',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Final Customer Bill · Preview',
                              style: TextStyle(
                                color: _deep,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 11),
                            _moneyRow(order.service, order.customerPayable),
                            if (widget.extraServices.isNotEmpty) ...[
                              const Divider(color: _border),
                              const Padding(
                                padding: EdgeInsets.only(top: 4, bottom: 2),
                                child: Text(
                                  'Selected extra services (unapproved demo)',
                                  style: TextStyle(color: _muted, fontSize: 11),
                                ),
                              ),
                              for (final extra in widget.extraServices)
                                _moneyRow(extra.name, extra.customerPrice),
                            ],
                            const Divider(color: _border),
                            _moneyRow('Extra services total', _extrasTotal),
                            const Divider(color: _border),
                            _moneyRow(
                              'Total customer payable',
                              _customerTotal,
                              strong: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _panel(
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user_outlined, color: _pink),
                            SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'Extra-service selection is not real customer approval. '
                                'In production the customer must approve new charges in '
                                'their own app before the final bill is locked.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _panel(
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.credit_card_outlined, color: _pink),
                            SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'After finishing the physical service, the customer pays '
                                'through the Pinkora Customer App. Payment verification '
                                'and order closure are separate later steps.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_simulatedFinished) ...[
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: _confirmed,
                          onChanged: _previewAllowed
                              ? (value) =>
                                    setState(() => _confirmed = value ?? false)
                              : null,
                          activeColor: _pink,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'I have reviewed the displayed service items and demo total.',
                            style: TextStyle(color: _deep, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(17, 10, 17, 15),
                  decoration: const BoxDecoration(
                    color: _cream,
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving || !_previewAllowed
                          ? null
                          : _simulatedFinished
                          ? _openWaitingPaymentPreview
                          : _confirmed
                          ? _finishPreview
                          : null,
                      icon: Icon(
                        _simulatedFinished
                            ? Icons.hourglass_empty_rounded
                            : Icons.flag_outlined,
                      ),
                      label: Text(
                        _simulatedFinished
                            ? 'View Payment Status · Demo'
                            : 'Confirm Finish · Demo',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFF5CBD9),
                        disabledForegroundColor: _deep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
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
