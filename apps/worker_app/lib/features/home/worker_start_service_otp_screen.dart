import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'worker_booking_data.dart';
import '../../integration/worker_mobile_operations_api.dart';

const _pink = Color(0xFFE91368);
const _deep = Color(0xFF460621);
const _muted = Color(0xFF735866);
const _cream = Color(0xFFFFF9F7);
const _border = Color(0xFFF0D6DF);

class WorkerStartServiceInput {
  const WorkerStartServiceInput({required this.otp, required this.evidenceIds});

  final String otp;
  final List<String> evidenceIds;
}

/// UI-only start-service verification. NO server verification is performed.
/// True means the *demo* code matched, never a production authorization.
class WorkerStartServiceOtpScreen extends StatefulWidget {
  const WorkerStartServiceOtpScreen({
    super.key,
    required this.order,
    this.demoMode = true,
    this.operationsApi,
  });

  final WorkerDashboardOrder order;
  final bool demoMode;
  final WorkerMobileOperationsApi? operationsApi;

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
  bool _uploadingPhoto = false;
  String _lastOtpInput = '';
  final List<String> _evidenceIds = [];
  final List<Uint8List> _photoPreviews = [];
  final ImagePicker _picker = ImagePicker();

  bool get _previewAllowed => kDebugMode && widget.demoMode;
  int get _otpLength => _previewAllowed ? 4 : 6;

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
    if (_checking) return;
    if (!_previewAllowed && _evidenceIds.isEmpty) {
      _notice('Capture and upload at least one product photo first.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_previewAllowed) {
      Navigator.of(context).pop(
        WorkerStartServiceInput(
          otp: _code.text.trim(),
          evidenceIds: List.unmodifiable(_evidenceIds),
        ),
      );
      return;
    }
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

  Future<void> _captureProductPhoto() async {
    if (_uploadingPhoto || _evidenceIds.length >= 3) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image == null || !mounted) return;
      setState(() => _uploadingPhoto = true);
      final bytes = await image.readAsBytes();
      final evidence =
          await (widget.operationsApi ?? WorkerMobileOperationsApi())
              .uploadProductEvidence(
                bookingId: widget.order.id,
                bytes: bytes,
                fileName:
                    'product-${DateTime.now().microsecondsSinceEpoch}.jpg',
              );
      final evidenceId = '${evidence['_id'] ?? ''}';
      if (evidenceId.isEmpty) {
        throw StateError('The server did not confirm the uploaded photo.');
      }
      if (!mounted) return;
      setState(() {
        _evidenceIds.add(evidenceId);
        _photoPreviews.add(bytes);
      });
    } catch (error) {
      if (mounted) _notice('Could not upload the product photo: $error');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
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
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: _pink, size: 19),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _previewAllowed
                                    ? 'DEVELOPMENT PREVIEW ONLY · No real customer OTP is checked and no service is started on the server.'
                                    : 'Enter the 6-digit code provided by the customer. The server verifies it before service starts.',
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
                                  formatCustomerPaise(
                                    order.customerPayablePaise ??
                                        order.customerPayable * 100,
                                  ),
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
                              'Customer payable — ${formatCustomerPaise(order.customerPayablePaise ?? order.customerPayable * 100)}',
                            ),
                          ],
                        ),
                      ),
                      if (!_previewAllowed) ...[
                        const SizedBox(height: 15),
                        _panel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Products for this service',
                                style: TextStyle(
                                  color: _deep,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Photograph the products you plan to use. At least one successful private upload is required before OTP entry.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final preview in _photoPreviews)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        preview,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                ],
                              ),
                              if (_photoPreviews.isNotEmpty)
                                const SizedBox(height: 10),
                              OutlinedButton.icon(
                                key: const Key('product-evidence-camera'),
                                onPressed:
                                    _uploadingPhoto || _evidenceIds.length >= 3
                                    ? null
                                    : _captureProductPhoto,
                                icon: _uploadingPhoto
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt_outlined),
                                label: Text(
                                  _uploadingPhoto
                                      ? 'Uploading…'
                                      : 'Take photo (${_evidenceIds.length}/3)',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (!_previewAllowed && _evidenceIds.isEmpty) ...[
                        const SizedBox(height: 15),
                        _panel(
                          const Text(
                            'OTP entry unlocks after a product photo has uploaded successfully.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      ],
                      if (_previewAllowed || _evidenceIds.isNotEmpty) ...[
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
                                Text(
                                  'At the customer location, ask the customer for the $_otpLength-digit start-service code.',
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
                                  maxLength: _otpLength,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(
                                      _otpLength,
                                    ),
                                  ],
                                  style: TextStyle(
                                    color: _deep,
                                    fontSize: 27,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: _otpLength == 4 ? 13 : 8,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: _otpLength == 4
                                        ? '••••'
                                        : '••••••',
                                    hintStyle: const TextStyle(
                                      fontSize: 25,
                                      letterSpacing: 8,
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
                                      value != null &&
                                          value.length == _otpLength &&
                                          RegExp(r'^\d+$').hasMatch(value)
                                      ? null
                                      : 'Enter all $_otpLength digits.',
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
                                Text(
                                  _previewAllowed
                                      ? 'The real app will verify this code using the server. This preview does not prove the worker is at the customer location.'
                                      : 'The server verifies this code before starting the service.',
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
                          _previewAllowed
                              ? 'For this preview, return to Booking Details and contact Pinkora support through the normal channel.'
                              : 'Ask the customer to confirm the code and retry.',
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
                          onPressed:
                              !_checking &&
                                  !_uploadingPhoto &&
                                  (_previewAllowed || _evidenceIds.isNotEmpty)
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
                          child: Text(
                            _previewAllowed
                                ? 'Verify & Start Service'
                                : 'Verify Code & Start Service',
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
