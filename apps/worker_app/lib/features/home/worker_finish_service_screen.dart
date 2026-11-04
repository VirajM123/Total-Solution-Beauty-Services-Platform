import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'worker_booking_data.dart';
import 'worker_booking_session.dart';
import 'worker_booking_state_repository.dart';
import 'worker_demo_booking_store.dart';
import 'worker_extra_service_item.dart';
import 'worker_add_extra_service_screen.dart';
import '../widgets/worker_auth_visuals.dart';
import '../widgets/worker_images.dart';
import 'worker_waiting_customer_payment_screen.dart';
import '../../app/slide_page_route.dart';

const _pink = Color(0xFFFF1678);
const _deep = Color(0xFF210B35);
const _muted = Color(0xFF686080);
const _cream = Color(0xFFFFF8FB);
const _border = Color(0xFFFFDFEB);

/// A read-only review and simulated finish action.
/// It does NOT finish the real booking, charge the customer, or verify payment.
class WorkerFinishServiceScreen extends StatefulWidget {
  const WorkerFinishServiceScreen({
    super.key,
    required this.order,
    required this.extraServices,
    required this.demoStartedAt,
    this.demoMode = true,
    this.liveMode = false,
    this.onComplete,
  });

  final WorkerDashboardOrder order;
  final List<WorkerExtraServiceItem> extraServices;
  final DateTime demoStartedAt;
  final bool demoMode;
  final bool liveMode;
  final Future<void> Function()? onComplete;

  @override
  State<WorkerFinishServiceScreen> createState() =>
      _WorkerFinishServiceScreenState();
}

class _WorkerFinishServiceScreenState extends State<WorkerFinishServiceScreen> {
  bool _confirmed = false;
  bool _simulatedFinished = false;
  bool _saving = false;
  DateTime? _savedFinishedAt;
  late List<WorkerExtraServiceItem> _extraServices;

  @override
  void initState() {
    super.initState();
    _extraServices = List.unmodifiable(widget.extraServices);
    final saved = WorkerDemoBookingStore.session(widget.order.id);
    if (saved?.serviceStage == WorkerServiceStage.finished) {
      _simulatedFinished = true;
      _savedFinishedAt = saved!.finishedAt;
    }
  }

  bool get _previewAllowed => kDebugMode && widget.demoMode && !widget.liveMode;
  int get _extrasTotal => _extraServices.fold<int>(
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
    padding: const EdgeInsets.all(12),
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

  Widget _customerDetail(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: _muted, size: 15),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 11.5),
        ),
      ),
    ],
  );

  Widget _serviceRow({
    required String name,
    required String duration,
    required int price,
    String? imageUrl,
    String? serviceId,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: WorkerServiceImage(
            service: name,
            serviceId: serviceId,
            imageUrl: imageUrl,
            demoMode: widget.demoMode,
            width: 76,
            height: 66,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _deep,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: _muted, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      duration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            formatCustomerRupees(price),
            style: const TextStyle(
              color: _deep,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _addExtraService() async {
    if (!_previewAllowed || _saving) return;
    final updated = await Navigator.of(context)
        .push<List<WorkerExtraServiceItem>>(
          SlidePageRoute<List<WorkerExtraServiceItem>>(
            page: WorkerAddExtraServiceScreen(
              order: widget.order,
              initialExtras: _extraServices,
              demoMode: widget.demoMode,
            ),
          ),
        );
    if (!mounted || updated == null) return;
    try {
      await WorkerDemoBookingStore.repository.updateExtras(
        bookingId: widget.order.id,
        extras: updated
            .map(
              (item) => WorkerExtraSnapshot(
                id: item.id,
                name: item.name,
                customerPrice: item.customerPrice,
                durationMinutes: item.durationMinutes,
              ),
            )
            .toList(growable: false),
      );
      if (mounted) setState(() => _extraServices = List.unmodifiable(updated));
    } on WorkerBookingStateException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update demo services.')),
        );
      }
    }
  }

  Future<void> _finishPreview() async {
    if (!_previewAllowed || _simulatedFinished || !_confirmed || _saving) {
      return;
    }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save finished service. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openWaitingPaymentPreview() async {
    if (!_previewAllowed ||
        !_simulatedFinished ||
        !mounted ||
        _saving && _savedFinishedAt == null) {
      return;
    }
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
          extraServices: _extraServices,
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
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        title: const WorkerAuthBrand(subtitle: 'Worker App'),
        centerTitle: false,
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      Text(
                        _simulatedFinished
                            ? 'Service Finished'
                            : 'Finish Service',
                        style: const TextStyle(
                          color: _deep,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _simulatedFinished
                            ? 'Review the payment status for this preview.'
                            : 'Review services provided and complete this appointment.',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_previewAllowed) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAF2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'DEMO PREVIEW · No live service or payment changes',
                            style: TextStyle(
                              color: _pink,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _panel(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: const Color(0xFFFFDCE9),
                              backgroundImage: widget.demoMode
                                  ? const AssetImage(
                                      'assets/images/dashboard/reference_customer.png',
                                    )
                                  : null,
                              child: widget.demoMode
                                  ? null
                                  : const Icon(
                                      Icons.person_rounded,
                                      color: _pink,
                                      size: 36,
                                    ),
                            ),
                            const SizedBox(width: 12),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  _customerDetail(
                                    Icons.call_outlined,
                                    order.customerPhone?.isNotEmpty == true
                                        ? order.customerPhone!
                                        : 'Phone unavailable',
                                  ),
                                  const SizedBox(height: 4),
                                  _customerDetail(
                                    Icons.location_on_outlined,
                                    order.location,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        color: const Color(0xFFFFF0F5),
                      ),
                      const SizedBox(height: 10),
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Services provided',
                                    style: TextStyle(
                                      color: _deep,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (_previewAllowed)
                                  OutlinedButton.icon(
                                    key: const Key('finish-add-extra-service'),
                                    onPressed: _saving
                                        ? null
                                        : _addExtraService,
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Add Service'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _pink,
                                      side: const BorderSide(color: _pink),
                                      minimumSize: const Size(0, 34),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            _serviceRow(
                              name: order.service,
                              duration: order.duration,
                              price: order.customerPayable,
                              imageUrl: order.serviceImageUrl,
                              serviceId: order.serviceId,
                            ),
                            for (final extra in _extraServices)
                              _serviceRow(
                                name: extra.name,
                                duration: '${extra.durationMinutes} min',
                                price: extra.customerPrice,
                              ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    color: _muted,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Total service duration',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _durationText,
                                    style: const TextStyle(
                                      color: _deep,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: _border, height: 20),
                            _moneyRow(
                              widget.liveMode
                                  ? 'Booked service amount'
                                  : 'Total amount',
                              _customerTotal,
                              strong: true,
                            ),
                            if (_previewAllowed)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Demo extras are not customer-approved or billable.',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            if (widget.liveMode)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'The final collection amount is confirmed in the payment step.',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  color: _pink,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Customer notes',
                                  style: TextStyle(
                                    color: _deep,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                order.customerNote?.trim().isNotEmpty == true
                                    ? order.customerNote!
                                    : order.itemsDescription
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                    ? order.itemsDescription!
                                    : 'No special requests noted for this appointment.',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: _pink,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Payment collection',
                                  style: TextStyle(
                                    color: _deep,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.payment_rounded,
                                    color: _pink,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Collected at next step',
                                          style: TextStyle(
                                            color: _deep,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          'Customer can pay via UPI (QR), Card / Link, or Cash.',
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    border: Border.all(color: _border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12C74776),
                        blurRadius: 12,
                        offset: Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_previewAllowed && !_simulatedFinished)
                          Material(
                            color: Colors.white,
                            child: CheckboxListTile(
                              key: const Key('finish-review-confirmation'),
                              value: _confirmed,
                              onChanged: _previewAllowed
                                  ? (value) => setState(
                                      () => _confirmed = value ?? false,
                                    )
                                  : null,
                              activeColor: _pink,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text(
                                'I have reviewed the services and demo total.',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                            ),
                          ),
                        SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('finish-service-continue'),
                            onPressed: _saving
                                ? null
                                : widget.liveMode
                                ? widget.onComplete
                                : !_previewAllowed
                                ? null
                                : _simulatedFinished
                                ? _openWaitingPaymentPreview
                                : _confirmed
                                ? _finishPreview
                                : null,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _simulatedFinished
                                        ? Icons.hourglass_top_rounded
                                        : Icons.check_circle_outline_rounded,
                                  ),
                            label: Text(
                              widget.liveMode
                                  ? 'Complete Service & Collect Payment'
                                  : _simulatedFinished
                                  ? 'View Payment Collection · Demo'
                                  : 'Complete Service',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _pink,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFF5CBD9),
                              disabledForegroundColor: _deep,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
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
