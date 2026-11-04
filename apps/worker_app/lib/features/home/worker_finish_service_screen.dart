import 'package:flutter/material.dart';

import 'worker_booking_data.dart';
import 'worker_extra_service_item.dart';
import '../widgets/worker_auth_visuals.dart';
import '../widgets/worker_images.dart';

const _pink = Color(0xFFFF1678);
const _deep = Color(0xFF210B35);
const _muted = Color(0xFF686080);
const _cream = Color(0xFFFFF8FB);
const _border = Color(0xFFFFDFEB);

/// Reviews the service and bill before opening the payment collection flow.
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
  bool _saving = false;
  late final List<WorkerExtraServiceItem> _extraServices = List.unmodifiable(
    widget.extraServices,
  );

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

  Future<void> _continueToPayment() async {
    if (!_confirmed || _saving) return;
    final onComplete = widget.onComplete;
    if (onComplete == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment collection is unavailable for this booking.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await onComplete();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const Text(
                  'Finish Service',
                  style: TextStyle(
                    color: _deep,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Review services provided and the final amount before continuing.',
                  style: TextStyle(color: _muted, fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 12),
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
                      const Text(
                        'Services provided',
                        style: TextStyle(
                          color: _deep,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
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
                                style: TextStyle(color: _muted, fontSize: 12),
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
                    ],
                  ),
                ),
                if (order.customerNote?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer notes',
                          style: TextStyle(
                            color: _deep,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.customerNote!,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment collection',
                        style: TextStyle(
                          color: _deep,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Customer can pay via UPI (QR) or Cash.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _moneyRow('Service amount', order.customerPayable),
                      if (_extrasTotal > 0)
                        _moneyRow('Additional services', _extrasTotal),
                      const Divider(color: _border, height: 16),
                      _moneyRow(
                        'Amount to collect',
                        _customerTotal,
                        strong: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _panel(
                  CheckboxListTile(
                    key: const Key('finish-review-confirmation'),
                    value: _confirmed,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _confirmed = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I confirm the services provided and amount to collect.',
                      style: TextStyle(
                        color: _deep,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('finish-service-continue'),
                    onPressed: _confirmed && !_saving
                        ? _continueToPayment
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
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      _saving
                          ? 'Opening payment collection…'
                          : 'Continue to payment collection',
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
      ),
    );
  }
}
