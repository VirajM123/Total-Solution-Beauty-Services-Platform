import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'worker_booking_data.dart';
import 'worker_booking_state_repository.dart';
import 'worker_demo_booking_store.dart';
import 'worker_extra_service_item.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);
const _green = Color(0xFF12875A);

/// Payment STATUS PREVIEW only. No request, charge, webhook or order mutation.
/// A local 'paid' visualization must never be used for real authorization.
class WorkerWaitingCustomerPaymentScreen extends StatefulWidget {
  const WorkerWaitingCustomerPaymentScreen({
    super.key,
    required this.order,
    required this.extraServices,
    required this.demoFinishedAt,
    this.demoMode = true,
  });

  final WorkerDashboardOrder order;
  final List<WorkerExtraServiceItem> extraServices;
  final DateTime demoFinishedAt;
  final bool demoMode;

  @override
  State<WorkerWaitingCustomerPaymentScreen> createState() =>
      _WorkerWaitingCustomerPaymentScreenState();
}

class _WorkerWaitingCustomerPaymentScreenState
    extends State<WorkerWaitingCustomerPaymentScreen> {
  bool _simulatedPaid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _simulatedPaid =
        WorkerDemoBookingStore.session(widget.order.id)?.demoPaidAt != null;
  }

  bool _returningHome = false;

  bool get _canPreview => kDebugMode && widget.demoMode;
  int get _extrasTotal => widget.extraServices.fold<int>(
    0,
    (sum, item) => sum + item.customerPrice,
  );
  int get _customerTotal => widget.order.customerPayable + _extrasTotal;

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

  Widget _moneyRow(String label, int amount, {bool total = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: total ? _deep : _muted,
              fontSize: total ? 14 : 12.5,
              fontWeight: total ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          formatCustomerRupees(amount),
          style: TextStyle(
            color: total ? _pink : _deep,
            fontSize: total ? 19 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Future<void> _simulateCustomerPayment() async {
    if (!_canPreview || _simulatedPaid || _saving) return;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Simulate customer payment?'),
        content: const Text(
          'This will only change the screen to a DEMO paid appearance. '
          'No money is transferred, no payment is verified, and no order is closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simulate only'),
          ),
        ],
      ),
    );
    if (!mounted || agreed != true) return;
    setState(() => _saving = true);
    try {
      await WorkerDemoBookingStore.repository.simulatePayment(
        bookingId: widget.order.id,
      );
      if (mounted) setState(() => _simulatedPaid = true);
    } on WorkerBookingStateException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save demo payment. Please retry.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _returnToDashboard() {
    if (!_canPreview || !_simulatedPaid || _returningHome || _saving) return;
    _returningHome = true;
    // Preview only: clear the completed route stack. No payment is verified,
    // and no real booking status is changed here.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final finishTime = TimeOfDay.fromDateTime(
      widget.demoFinishedAt,
    ).format(context);
    return PopScope(
      canPop: !_simulatedPaid,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          title: const Text(
            'Customer Payment',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
          backgroundColor: _cream,
          foregroundColor: _deep,
          surfaceTintColor: _cream,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(17, 10, 17, 24),
                      children: [
                        if (_canPreview) ...[
                          const Text(
                            'DEVELOPMENT PREVIEW · NO PAYMENT REQUEST SENT',
                            style: TextStyle(fontSize: 10, color: _muted),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _panel(
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: _simulatedPaid
                                    ? const Color(0xFFE2F8ED)
                                    : const Color(0xFFFFE2ED),
                                child: Icon(
                                  _simulatedPaid
                                      ? Icons.check_circle_outline
                                      : Icons.hourglass_top_rounded,
                                  color: _simulatedPaid ? _green : _pink,
                                  size: 35,
                                ),
                              ),
                              const SizedBox(height: 13),
                              Text(
                                _simulatedPaid
                                    ? 'Demo Payment Completed'
                                    : 'Waiting for Customer Payment',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _deep,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _simulatedPaid
                                    ? 'This is a local UI simulation only. No payment '
                                          'was received or verified, and the booking remains unchanged.'
                                    : 'Physical service finished in this preview. '
                                          'The real customer will pay in the Pinkora Customer App '
                                          'after a real payment request is created.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Chip(
                                label: Text(
                                  _simulatedPaid
                                      ? 'SIMULATED PAID · NOT VERIFIED'
                                      : 'PAYMENT PENDING · NOT SENT',
                                ),
                                backgroundColor: _simulatedPaid
                                    ? const Color(0xFFE2F8ED)
                                    : const Color(0xFFFFE7F0),
                                side: BorderSide.none,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                  color: _simulatedPaid ? _green : _pink,
                                ),
                              ),
                            ],
                          ),
                          color: const Color(0xFFFFF0F5),
                        ),
                        const SizedBox(height: 14),
                        _panel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.order.customer,
                                style: const TextStyle(
                                  color: _deep,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Booking ${widget.order.id} · Finished preview at $finishTime',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Divider(color: _border),
                              const SizedBox(height: 7),
                              _moneyRow(
                                widget.order.service,
                                widget.order.customerPayable,
                              ),
                              for (final extra in widget.extraServices)
                                _moneyRow(extra.name, extra.customerPrice),
                              const Divider(color: _border),
                              _moneyRow(
                                'Total customer payable',
                                _customerTotal,
                                total: true,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Customer bill only · No worker payout information.',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _panel(
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lock_outline_rounded, color: _pink),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'In production, this screen can show Paid only after '
                                  'the backend verifies the customer payment. '
                                  'Workers cannot confirm payment themselves.',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(17, 10, 17, 15),
                    decoration: const BoxDecoration(
                      color: _cream,
                      border: Border(top: BorderSide(color: _border)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_canPreview && !_simulatedPaid)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : _simulateCustomerPayment,
                              icon: const Icon(Icons.science_outlined),
                              label: const Text('Simulate Customer Payment'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _pink,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        if (_canPreview && !_simulatedPaid)
                          const SizedBox(height: 9),
                        SizedBox(
                          width: double.infinity,
                          height: 47,
                          child: _simulatedPaid
                              ? FilledButton.icon(
                                  onPressed:
                                      _canPreview && !_returningHome && !_saving
                                      ? _returnToDashboard
                                      : null,
                                  icon: const Icon(Icons.home_outlined),
                                  label: const Text(
                                    'Done · Return to Dashboard (Demo)',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _pink,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _pink,
                                    side: const BorderSide(color: _border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Back to Finish Service'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
