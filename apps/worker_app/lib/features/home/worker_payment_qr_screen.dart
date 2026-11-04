import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../integration/worker_environment.dart';

import '../../integration/worker_mobile_operations_api.dart';
import 'worker_booking_data.dart';
import '../widgets/worker_design.dart';

class WorkerPaymentQrScreen extends StatefulWidget {
  const WorkerPaymentQrScreen({
    super.key,
    required this.order,
    required this.operationsApi,
    this.onCashCollection,
  });

  final WorkerDashboardOrder order;
  final WorkerMobileOperationsApi operationsApi;
  final VoidCallback? onCashCollection;

  @override
  State<WorkerPaymentQrScreen> createState() => _WorkerPaymentQrScreenState();
}

class _WorkerPaymentQrScreenState extends State<WorkerPaymentQrScreen> {
  String _activeTab = 'upi'; // 'upi', 'card', 'cash'
  bool _loading = false;
  String? _error;
  String? _imageUrl;
  int? _amountPaise;
  Timer? _paymentTimer;
  bool _checkingPayment = false;
  bool _paymentVerified = false;
  bool _paid = false;
  bool _completing = false;
  final _completionOtp = TextEditingController();
  final _cashReferenceController = TextEditingController();
  String? _paymentMessage;
  String? _cardPaymentUrl;
  bool _generatingLink = false;
  bool _simulating = false;
  bool _submittingCash = false;

  @override
  void initState() {
    super.initState();
    _paid =
        widget.order.paymentStatus == 'paid' &&
        widget.order.status.toLowerCase() == 'completed';
    _paymentVerified = widget.order.paymentStatus == 'paid';
    _checkPayment();
    _paymentTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkPayment(),
    );
  }

  @override
  void dispose() {
    _paymentTimer?.cancel();
    _completionOtp.dispose();
    _cashReferenceController.dispose();
    super.dispose();
  }

  Future<void> _checkPayment() async {
    if (_checkingPayment || _paid) return;
    _checkingPayment = true;
    try {
      final booking = await widget.operationsApi.fetchBookingDetails(
        widget.order.id,
      );
      if (!mounted) return;
      setState(() {
        _paymentVerified = booking?.paymentStatus == 'paid';
        _paid =
            booking?.paymentStatus == 'paid' &&
            booking?.status.toLowerCase() == 'completed';
        _paymentMessage = booking == null
            ? 'Unable to check payment. Keep this screen open or retry when connected.'
            : _paid
            ? 'Payment received. Service completed.'
            : _paymentVerified
            ? 'Payment verified. Complete service below.'
            : 'Awaiting verified payment from Razorpay.';
      });
      if (_paid) _paymentTimer?.cancel();
    } catch (_) {
      if (mounted) {
        setState(
          () => _paymentMessage =
              'Unable to check payment. Keep this screen open or retry when connected.',
        );
      }
    } finally {
      if (mounted) setState(() => _checkingPayment = false);
    }
  }

  Future<void> _generateQr() async {
    if (_loading || _paid || _paymentVerified) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.operationsApi.createBookingPaymentQr(
        widget.order.id,
      );
      final imageUrl = result['imageUrl'];
      final amount = int.tryParse('${result['amountPaise']}');
      final uri = Uri.tryParse('$imageUrl');
      if (imageUrl is! String ||
          uri == null ||
          uri.scheme != 'https' ||
          amount == null ||
          amount <= 0) {
        throw const FormatException(
          'The payment provider returned an invalid QR.',
        );
      }
      if (!mounted) return;
      setState(() {
        _imageUrl = imageUrl;
        _amountPaise = amount;
      });
      await _checkPayment();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _simulatePaymentSuccess() async {
    if (_simulating || _paid || _paymentVerified) return;
    setState(() {
      _simulating = true;
      _error = null;
    });
    try {
      await widget.operationsApi.simulatePaymentSuccess(widget.order.id);
      await _checkPayment();
    } catch (e) {
      if (mounted) setState(() => _error = 'Simulation failed: $e');
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  Future<void> _openPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (e) {
        if (mounted) setState(() => _error = 'Could not open checkout: $e');
      }
    }
  }

  Future<void> _generateCardLink() async {
    if (_generatingLink || _paid || _paymentVerified) return;
    if (_cardPaymentUrl != null && _cardPaymentUrl!.isNotEmpty) {
      await _openPaymentUrl(_cardPaymentUrl!);
      return;
    }
    setState(() {
      _generatingLink = true;
      _error = null;
    });
    try {
      final res = await widget.operationsApi.createBookingPaymentLink(
        widget.order.id,
      );
      final url = res['shortUrl']?.toString();
      if (url != null && url.isNotEmpty) {
        if (mounted) setState(() => _cardPaymentUrl = url);
        await _openPaymentUrl(url);
      } else {
        if (mounted) setState(() => _error = 'Could not generate card checkout link.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Card link generation failed: $e');
    } finally {
      if (mounted) setState(() => _generatingLink = false);
    }
  }

  Future<void> _confirmCashPayment() async {
    if (_submittingCash || _paid || _paymentVerified) return;
    setState(() {
      _submittingCash = true;
      _error = null;
    });
    try {
      final ref = _cashReferenceController.text.trim();
      await widget.operationsApi.confirmCashPayment(
        widget.order.id,
        reference: ref.isNotEmpty ? ref : 'Cash Collected on Site',
      );
      await _checkPayment();
    } catch (e) {
      if (mounted) setState(() => _error = 'Cash confirmation failed: $e');
    } finally {
      if (mounted) setState(() => _submittingCash = false);
    }
  }

  Future<void> _completeWithOtp() async {
    final otp = _completionOtp.text.trim();
    if (_completing || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Enter the 6-digit OTP from your administrator.');
      return;
    }
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      await widget.operationsApi.updateBookingProgress(
        bookingId: widget.order.id,
        action: 'complete',
        otp: otp,
      );
      if (!mounted) return;
      setState(() {
        _paid = true;
        _paymentVerified = true;
      });
      _paymentTimer?.cancel();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WorkerDesign.cream,
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
      ),
      title: const Text(
        'Payment Collection',
        style: TextStyle(
          color: WorkerDesign.deep,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Image.asset(
            'assets/images/logo/logo.png',
            height: 38,
            fit: BoxFit.contain,
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: _paid ? _completedContent(context) : _mainContent(context),
    ),
  );

  Widget _mainContent(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
    children: [
      _customerCard(),
      const SizedBox(height: 9),
      _amountCard(),
      const SizedBox(height: 12),
      _paymentMethods(context),
      const SizedBox(height: 12),
      if (_activeTab == 'upi')
        _qrCard()
      else if (_activeTab == 'card')
        _cardPaymentCard()
      else
        _cashPaymentCard(),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ],
      if (_paymentVerified && !_paid) ...[
        const SizedBox(height: 12),
        _completionOtpCard(),
      ],
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDF4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: WorkerDesign.pink, size: 20),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Payments are securely processed by Razorpay. Service completes automatically upon payment verification.',
                style: TextStyle(
                  color: WorkerDesign.muted,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _customerCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEFF5),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: WorkerDesign.border),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFFFFDCE9),
          backgroundImage: widget.order.customerPhotoUrl?.isNotEmpty == true
              ? NetworkImage(widget.order.customerPhotoUrl!)
              : null,
          child: widget.order.customerPhotoUrl?.isNotEmpty == true
              ? null
              : const Icon(
                  Icons.person_rounded,
                  color: WorkerDesign.pink,
                  size: 30,
                ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer',
                style: TextStyle(color: WorkerDesign.muted, fontSize: 11),
              ),
              Text(
                widget.order.customer,
                style: const TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((widget.order.customerPhone ?? '').isNotEmpty)
                Text(
                  widget.order.customerPhone ?? '',
                  style: const TextStyle(
                    color: WorkerDesign.muted,
                    fontSize: 11.5,
                  ),
                ),
              Text(
                widget.order.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WorkerDesign.muted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _amountCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: WorkerDesign.surface(radius: 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Amount to collect',
                style: TextStyle(color: WorkerDesign.muted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                formatCustomerPaise(
                  _amountPaise ?? widget.order.exactCustomerPayablePaise,
                ),
                style: const TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Final bill confirmed for this booking',
                style: TextStyle(color: WorkerDesign.muted, fontSize: 10),
              ),
            ],
          ),
        ),
        Image.asset(
          'assets/images/logo/logo.png',
          height: 52,
          fit: BoxFit.contain,
        ),
      ],
    ),
  );

  Widget _paymentMethods(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: WorkerDesign.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: _methodButton(
            icon: Icons.qr_code_2_rounded,
            label: 'UPI (QR)',
            selected: _activeTab == 'upi',
            onPressed: () => setState(() => _activeTab = 'upi'),
          ),
        ),
        Expanded(
          child: _methodButton(
            icon: Icons.credit_card_rounded,
            label: 'Card / Link',
            selected: _activeTab == 'card',
            onPressed: () {
              setState(() => _activeTab = 'card');
              if (_cardPaymentUrl == null) _generateCardLink();
            },
          ),
        ),
        Expanded(
          child: _methodButton(
            icon: Icons.payments_outlined,
            label: 'Cash',
            selected: _activeTab == 'cash',
            onPressed: () => setState(() => _activeTab = 'cash'),
          ),
        ),
      ],
    ),
  );

  Widget _methodButton({
    required IconData icon,
    required String label,
    bool selected = false,
    bool enabled = true,
    VoidCallback? onPressed,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: selected ? WorkerDesign.pink : WorkerDesign.muted,
        backgroundColor: selected ? const Color(0xFFFFE3ED) : Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Flexible(child: Text(label, maxLines: 1)),
        ],
      ),
    ),
  );

  /// Problem 2 Fix: Centered, Large, High-Contrast QR Code Card
  Widget _qrCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: WorkerDesign.surface(radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Scan & Pay using any UPI app',
                style: TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_imageUrl != null && !_paymentVerified)
              TextButton.icon(
                key: const Key('refresh-payment-qr'),
                onPressed: _loading ? null : _generateQr,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: WorkerDesign.pink,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_paymentVerified)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FAF2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF14965F).withOpacity(0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF14965F),
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Payment verified successfully! Appointment ready for completion.',
                    style: TextStyle(
                      color: Color(0xFF0F5A38),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Big Centered QR Box (260x260)
          Center(
            child: Container(
              width: 260,
              height: 260,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: WorkerDesign.border, width: 2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10C74776),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: _imageUrl == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          color: Color(0xFFB8B3C5),
                          size: 100,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap below to generate QR',
                          style: TextStyle(
                            color: WorkerDesign.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        kIsWeb
                            ? '${WorkerEnvironment.apiBaseUrl}/mobile/payments/razorpay/qr-image?url=${Uri.encodeComponent(_imageUrl!)}'
                            : _imageUrl!,
                        width: 240,
                        height: 240,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image_outlined,
                              color: WorkerDesign.muted,
                              size: 50,
                            ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0D8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFB85E00),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _imageUrl == null
                      ? 'Ready to generate payment'
                      : 'Waiting for payment (${formatCustomerPaise(_amountPaise ?? widget.order.exactCustomerPayablePaise)})',
                  style: const TextStyle(
                    color: Color(0xFFB85E00),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask customer to scan using Google Pay, PhonePe, Paytm, or BHIM UPI.',
            textAlign: TextAlign.center,
            style: TextStyle(color: WorkerDesign.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          if (_imageUrl == null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('generate-payment-qr-action'),
                onPressed: _loading ? null : _generateQr,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.qr_code_2_rounded),
                label: Text(_loading ? 'Generating…' : 'Generate QR Code'),
                style: FilledButton.styleFrom(
                  backgroundColor: WorkerDesign.pink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Problem 3 Fix: Simulation Button for Test Mode
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _simulating ? null : _simulatePaymentSuccess,
              icon: _simulating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.bolt_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
              label: const Text('⚡ Simulate Payment Success (Test Mode)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC05621),
                side: const BorderSide(color: Color(0xFFFBD38D), width: 1.5),
                backgroundColor: const Color(0xFFFFFAF0),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: _checkingPayment ? null : _checkPayment,
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Check payment status'),
            ),
          ),
          if (_paymentMessage != null)
            Text(
              _paymentMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: WorkerDesign.muted,
                fontSize: 11,
              ),
            ),
        ],
      ],
    ),
  );

  /// Problem 4 Fix: Full Card Payment Tab with Live Razorpay Link & Test Mode
  Widget _cardPaymentCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: WorkerDesign.surface(radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.credit_card_rounded,
          size: 54,
          color: WorkerDesign.pink,
        ),
        const SizedBox(height: 8),
        const Text(
          'Online Card & Netbanking Payment',
          style: TextStyle(
            color: WorkerDesign.deep,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Amount to collect: ${formatCustomerPaise(_amountPaise ?? widget.order.exactCustomerPayablePaise)}',
          style: const TextStyle(
            color: WorkerDesign.pink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (_paymentVerified)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FAF2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF14965F)),
                SizedBox(width: 8),
                Text(
                  'Card payment verified successfully!',
                  style: TextStyle(
                    color: Color(0xFF0F5A38),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        else ...[
          const Text(
            'Customer can pay using Debit/Credit Card, Netbanking, or Wallet via Razorpay Secure Checkout.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: WorkerDesign.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (_cardPaymentUrl != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openPaymentUrl(_cardPaymentUrl!),
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                label: const Text('Open Razorpay Card Checkout ↗'),
                style: FilledButton.styleFrom(
                  backgroundColor: WorkerDesign.pink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2DDF0)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: WorkerDesign.deep),
                      SizedBox(width: 6),
                      Text(
                        'Razorpay Test Mode Card Details:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: WorkerDesign.deep,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Card Number: 4111 • 1111 • 1111 • 1111\n• Expiry: 12/28 | CVV: 123 | OTP: 123456',
                    style: TextStyle(fontSize: 11.5, color: WorkerDesign.deep, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _cardPaymentUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment link copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: WorkerDesign.muted),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => _openPaymentUrl(_cardPaymentUrl!),
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Re-open Checkout', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: WorkerDesign.pink),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _generatingLink ? null : _generateCardLink,
                icon: _generatingLink
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.credit_card_rounded),
                label: Text(
                  _generatingLink ? 'Opening Checkout…' : 'Pay with Card / Online Checkout 💳',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: WorkerDesign.pink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _simulating ? null : _simulatePaymentSuccess,
              icon: _simulating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.bolt_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
              label: const Text('⚡ Simulate Card Payment (Test Mode)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC05621),
                side: const BorderSide(color: Color(0xFFFBD38D), width: 1.5),
                backgroundColor: const Color(0xFFFFFAF0),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  /// Problem 1 Fix: Embedded Cash Collection Tab on the Same Screen!
  Widget _cashPaymentCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: WorkerDesign.surface(radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.payments_outlined, color: Color(0xFF14965F), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cash Payment Collection',
                style: TextStyle(
                  color: WorkerDesign.deep,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE9FAF2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF14965F).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exact Cash Amount to Collect:',
                style: TextStyle(color: Color(0xFF0F5A38), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                formatCustomerPaise(
                  _amountPaise ?? widget.order.exactCustomerPayablePaise,
                ),
                style: const TextStyle(
                  color: Color(0xFF14965F),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_paymentVerified)
          const Text(
            '✅ Cash collected and verified.',
            style: TextStyle(
              color: Color(0xFF14965F),
              fontWeight: FontWeight.w700,
            ),
          )
        else ...[
          const Text(
            'Collection Reference / Receipt Note (Optional):',
            style: TextStyle(
              color: WorkerDesign.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _cashReferenceController,
            decoration: const InputDecoration(
              hintText: 'e.g. Received in cash from customer',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submittingCash ? null : _confirmCashPayment,
              icon: _submittingCash
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                _submittingCash ? 'Confirming…' : 'Confirm Cash Received',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF14965F),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _completionOtpCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: WorkerDesign.surface(radius: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complete this appointment',
          style: TextStyle(
            color: WorkerDesign.deep,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          key: const Key('service-completion-otp'),
          controller: _completionOtp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: '6-digit administrator OTP',
            hintText: 'Ask your administrator',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _completing ? null : _completeWithOtp,
            icon: _completing
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
              _completing ? 'Verifying OTP…' : 'Verify OTP & complete service',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: WorkerDesign.pink,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    ),
  );

  Widget _completedContent(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(15, 20, 15, 24),
    children: [
      const SizedBox(height: 25),
      const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF19B974),
        size: 96,
      ),
      const SizedBox(height: 18),
      const Text(
        'Service completed!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: WorkerDesign.deep,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Payment received and appointment completed.',
        textAlign: TextAlign.center,
        style: TextStyle(color: WorkerDesign.muted, fontSize: 14),
      ),
      const SizedBox(height: 8),
      Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFD8F9E9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Payment received · Service completed',
          style: TextStyle(
            color: Color(0xFF078B53),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFF5),
          border: Border.all(color: WorkerDesign.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.order.service,
              style: const TextStyle(
                color: WorkerDesign.deep,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _completedDetail(
              Icons.person_outline_rounded,
              widget.order.customer,
            ),
            _completedDetail(Icons.schedule_rounded, widget.order.duration),
            _completedDetail(Icons.location_on_outlined, widget.order.location),
            const Divider(color: WorkerDesign.border, height: 22),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total amount',
                        style: TextStyle(color: WorkerDesign.muted),
                      ),
                      Text(
                        formatCustomerPaise(
                          _amountPaise ??
                              widget.order.exactCustomerPayablePaise,
                        ),
                        style: const TextStyle(
                          color: WorkerDesign.deep,
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8F9E9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF078B53),
                        size: 19,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Paid',
                        style: TextStyle(
                          color: Color(0xFF078B53),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Back to booking'),
        style: OutlinedButton.styleFrom(
          foregroundColor: WorkerDesign.pink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: WorkerDesign.pink),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        icon: const Icon(Icons.home_rounded),
        label: const Text('Go to Home'),
        style: FilledButton.styleFrom(
          backgroundColor: WorkerDesign.pink,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ],
  );

  Widget _completedDetail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, color: WorkerDesign.deep, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: WorkerDesign.muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
