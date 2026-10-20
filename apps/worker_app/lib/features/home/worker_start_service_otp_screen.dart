import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'worker_booking_data.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

/// UI-only start-service verification. NO server verification is performed.
/// True means the *demo* code matched, never a production authorization.
class WorkerStartServiceOtpScreen extends StatefulWidget {
  const WorkerStartServiceOtpScreen({
    super.key,
    required this.order,
    this.demoMode = true,
  });

  final WorkerDashboardOrder order;
  final bool demoMode;

  @override
  State<WorkerStartServiceOtpScreen> createState() =>
      _WorkerStartServiceOtpScreenState();
}

class _WorkerStartServiceOtpScreenState
    extends State<WorkerStartServiceOtpScreen> {
  static const _demoCode = '2841';
  final _code = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _checking = false;
  String _lastOtpInput = '';

  bool get _previewAllowed => kDebugMode && widget.demoMode;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _verify() async {
    if (_checking || !_previewAllowed) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _checking = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      if (_code.text != _demoCode) {
        _notice('Incorrect demo code. Check the preview code below.');
        return;
      }
      FocusScope.of(context).unfocus();
      // Returns only a local UI-preview result to the Booking Details page.
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _pink),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        foregroundColor: _deep,
        centerTitle: true,
        title: const Text(
          'Start Service',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(17, 8, 17, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEAF1),
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: _pink, size: 19),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'DEVELOPMENT PREVIEW ONLY · No real customer OTP is checked and no service is started on the server.',
                                style: TextStyle(color: _deep, fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 17),
                      _panel(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 27,
                              backgroundColor: const Color(0xFFFFE2EC),
                              child: Text(
                                order.customer.isEmpty
                                    ? 'C'
                                    : order.customer[0],
                                style: const TextStyle(
                                  color: _pink,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
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
                                  const SizedBox(height: 3),
                                  Text(
                                    'Booking ${order.id}',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.person_outline, color: _pink),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: 62,
                                  width: 62,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE8EF),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                    Icons.spa_rounded,
                                    color: _pink,
                                    size: 31,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Text(
                                    order.service,
                                    style: const TextStyle(
                                      color: _deep,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatCustomerRupees(order.customerPayable),
                                  style: const TextStyle(
                                    color: _deep,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            const Divider(color: _border),
                            const SizedBox(height: 11),
                            _line(
                              Icons.access_time_rounded,
                              '${order.time} · ${order.duration}',
                            ),
                            _line(Icons.place_outlined, order.location),
                            _line(
                              Icons.receipt_long_outlined,
                              'Customer payable — ${formatCustomerRupees(order.customerPayable)}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(color: _border),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Start-service OTP',
                                style: TextStyle(
                                  color: _deep,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 19,
                                ),
                              ),
                              const SizedBox(height: 7),
                              const Text(
                                'At the customer location, ask the customer for the 4-digit start-service code.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 17),
                              TextFormField(
                                key: const Key('start-service-otp'),
                                controller: _code,
                                onChanged: (value) {
                                  if (value.length > _lastOtpInput.length ||
                                      (value.length == _lastOtpInput.length &&
                                          value != _lastOtpInput)) {
                                    HapticFeedback.lightImpact();
                                  }
                                  _lastOtpInput = value;
                                },
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                textAlign: TextAlign.center,
                                obscureText: true,
                                obscuringCharacter: '●',
                                maxLength: 4,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                style: const TextStyle(
                                  color: _deep,
                                  fontSize: 27,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 13,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '••••',
                                  hintStyle: const TextStyle(
                                    fontSize: 25,
                                    letterSpacing: 12,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: _border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: _border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: _pink,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    RegExp(r'^\d{4}$').hasMatch(value ?? '')
                                    ? null
                                    : 'Enter all 4 digits.',
                                onFieldSubmitted: (_) => _verify(),
                              ),
                              if (_previewAllowed) ...[
                                const SizedBox(height: 7),
                                const Text(
                                  'Demo code: 2841',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _pink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Text(
                                'The real app will verify this code using the server. This preview does not prove the worker is at the customer location.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
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
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _notice(
                          'For this preview, return to Booking Details and contact Pinkora support through the normal channel.',
                        ),
                        icon: const Icon(
                          Icons.support_agent_outlined,
                          size: 18,
                        ),
                        label: const Text('Need Help'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _pink,
                          side: const BorderSide(color: _pink),
                          minimumSize: const Size(0, 49),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: const Key('verify-start-service'),
                          onPressed: _previewAllowed && !_checking
                              ? _verify
                              : null,
                          style: FilledButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: _pink,
                            disabledBackgroundColor: const Color(0xFFF2C0D2),
                            minimumSize: const Size(0, 49),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Verify & Start Service',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
    );
  }
}
