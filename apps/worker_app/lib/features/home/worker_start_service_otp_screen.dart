import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/worker_auth_visuals.dart';
import 'worker_booking_data.dart';
import '../../integration/worker_mobile_operations_api.dart';

const _pink = Color(0xFFFF1678);
const _deep = Color(0xFF210B35);
const _muted = Color(0xFF686080);
const _cream = Color(0xFFFFF8FB);
const _border = Color(0xFFFFDFEB);

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
    this.onContact,
  });

  final WorkerDashboardOrder order;
  final bool demoMode;
  final WorkerMobileOperationsApi? operationsApi;
  final VoidCallback? onContact;

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
  bool _showOtpError = false;
  bool _showOtpPage = false;
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _showOtpError = true);
      return;
    }
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
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: child,
  );

  void _continueToOtp() {
    if (_evidenceIds.isEmpty) {
      _notice('Capture and upload at least one product photo first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _showOtpPage = true);
  }

  void _returnToProductPhotos() {
    FocusScope.of(context).unfocus();
    setState(() => _showOtpPage = false);
  }

  Widget _buildOtpPage(WorkerDashboardOrder order) => Scaffold(
    backgroundColor: const Color(0xFFFFFBFD),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(17, 10, 17, 16),
            children: [
              Row(
                children: [
                  if (!_previewAllowed)
                    IconButton(
                      key: const Key('back-to-product-photos'),
                      tooltip: 'Back to product photos',
                      onPressed: _returnToProductPhotos,
                      color: _pink,
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 48),
                  const Expanded(
                    child: Center(
                      child: WorkerAuthBrand(subtitle: 'Worker App'),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 1.58,
                  child: Image.asset(
                    'assets/images/illustrations/worker_customer_otp_phone.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -.2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(19, 19, 19, 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF5F9), Color(0xFFFFEDF4)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter Customer OTP',
                        style: TextStyle(
                          color: _deep,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.55,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Ask the customer to share the $_otpLength-digit OTP sent to their mobile number.',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      if (_previewAllowed) ...[
                        const SizedBox(height: 7),
                        const Text(
                          'Development preview · Demo code: 2841',
                          style: TextStyle(
                            color: _pink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 68,
                        child: Stack(
                          children: [
                            Row(
                              children: List.generate(
                                _otpLength,
                                (index) => Expanded(
                                  child: Container(
                                    height: 66,
                                    margin: EdgeInsets.only(
                                      right: index == _otpLength - 1 ? 0 : 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _code.text.length > index
                                            ? _pink
                                            : const Color(0xFFFFCFE0),
                                        width: _code.text.length > index
                                            ? 1.5
                                            : 1,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0AFF1678),
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _code.text.length > index
                                          ? _code.text[index]
                                          : '',
                                      style: const TextStyle(
                                        color: _deep,
                                        fontSize: 31,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Opacity(
                                opacity: .01,
                                child: TextFormField(
                                  key: const Key('start-service-otp'),
                                  controller: _code,
                                  onChanged: (value) {
                                    if (value.length > _lastOtpInput.length ||
                                        (value.length == _lastOtpInput.length &&
                                            value != _lastOtpInput)) {
                                      HapticFeedback.lightImpact();
                                    }
                                    _lastOtpInput = value;
                                    setState(() => _showOtpError = false);
                                  },
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  textAlign: TextAlign.center,
                                  maxLength: _otpLength,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(
                                      _otpLength,
                                    ),
                                  ],
                                  style: const TextStyle(
                                    color: Colors.transparent,
                                    fontSize: 1,
                                  ),
                                  cursorColor: Colors.transparent,
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    errorStyle: TextStyle(
                                      fontSize: 0,
                                      height: 0,
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
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showOtpError)
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Text(
                            'Enter all digits to continue.',
                            style: TextStyle(
                              color: Color(0xFFB3261E),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('verify-start-service'),
                        onPressed:
                            !_checking &&
                                !_uploadingPhoto &&
                                (_previewAllowed || _evidenceIds.isNotEmpty)
                            ? _verify
                            : null,
                        icon: _checking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 23),
                        label: const Text('Verify & Start Service'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _pink,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFF2C0D2),
                          minimumSize: const Size.fromHeight(62),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed:
                            widget.onContact ??
                            () => _notice(
                              _previewAllowed
                                  ? 'For this preview, return to Booking Details and contact Pinkora support through the normal channel.'
                                  : 'Ask the customer to confirm the code and retry.',
                            ),
                        icon: Icon(
                          widget.onContact == null
                              ? Icons.support_agent_outlined
                              : Icons.call_rounded,
                          size: 22,
                        ),
                        label: Text(
                          widget.onContact == null
                              ? 'Need Help'
                              : 'Call Customer',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _pink,
                          side: const BorderSide(color: _pink),
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    if (_previewAllowed || _showOtpPage) {
      return _buildOtpPage(order);
    }

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        foregroundColor: _deep,
        centerTitle: true,
        toolbarHeight: 66,
        title: const WorkerAuthBrand(subtitle: 'Worker App'),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          height: 156,
                          child: _previewAllowed
                              ? Image.asset(
                                  'assets/images/illustrations/worker_customer_otp_phone.png',
                                  fit: BoxFit.cover,
                                  alignment: const Alignment(0, -.2),
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFFE8F0),
                                        Color(0xFFFFF7FA),
                                      ],
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        color: _pink,
                                        size: 38,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'A quick product check before you begin',
                                        style: TextStyle(
                                          color: _deep,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _previewAllowed
                            ? 'Enter Customer OTP'
                            : 'Photograph Service Products',
                        style: const TextStyle(
                          color: _deep,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _previewAllowed
                            ? 'Ask ${order.customer} to share the $_otpLength-digit code sent to their mobile number.'
                            : 'Capture up to 3 photos of the products you plan to use. Tap Next when you are ready to enter the customer OTP.',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      if (_previewAllowed) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAF1),
                            border: Border.all(color: _border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: _pink, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Development preview only. No real OTP is checked and no service is started on the server.',
                                  style: TextStyle(color: _deep, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
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
                                  fontSize: 19,
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
                      const SizedBox(height: 8),
                      _panel(
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFE8F0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.spa_outlined,
                                color: _pink,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.service,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _deep,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Booking ${order.id} · ${order.time}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_previewAllowed) ...[
                        const SizedBox(height: 8),
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
                              if (_evidenceIds.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${_evidenceIds.length} of 3 photos uploaded',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              const Text(
                                'Photograph the products you plan to use. At least one successful upload is required before you can continue.',
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
                        const SizedBox(height: 8),
                        _panel(
                          const Text(
                            'OTP entry unlocks after a product photo has uploaded successfully.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      ],
                      if (_previewAllowed) ...[
                        const SizedBox(height: 10),
                        _panel(
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Customer OTP',
                                        style: TextStyle(
                                          color: _deep,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 19,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.verified_user_outlined,
                                      color: _pink,
                                      size: 20,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter the $_otpLength-digit code shared by the customer.',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 70,
                                  child: Stack(
                                    children: [
                                      Row(
                                        children: List.generate(
                                          _otpLength,
                                          (index) => Expanded(
                                            child: Container(
                                              height: 66,
                                              margin: EdgeInsets.only(
                                                right: index == _otpLength - 1
                                                    ? 0
                                                    : 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color:
                                                      _code.text.length > index
                                                      ? _pink
                                                      : const Color(0xFFFFCFE0),
                                                  width:
                                                      _code.text.length > index
                                                      ? 1.5
                                                      : 1,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x0AFF1678),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                _code.text.length > index
                                                    ? '●'
                                                    : '',
                                                style: const TextStyle(
                                                  color: _deep,
                                                  fontSize: 22,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: .01,
                                          child: TextFormField(
                                            key: const Key('start-service-otp'),
                                            controller: _code,
                                            onChanged: (value) {
                                              if (value.length >
                                                      _lastOtpInput.length ||
                                                  (value.length ==
                                                          _lastOtpInput
                                                              .length &&
                                                      value != _lastOtpInput)) {
                                                HapticFeedback.lightImpact();
                                              }
                                              _lastOtpInput = value;
                                              setState(
                                                () => _showOtpError = false,
                                              );
                                            },
                                            keyboardType: TextInputType.number,
                                            textInputAction:
                                                TextInputAction.done,
                                            textAlign: TextAlign.center,
                                            obscureText: true,
                                            maxLength: _otpLength,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                _otpLength,
                                              ),
                                            ],
                                            style: const TextStyle(
                                              color: Colors.transparent,
                                              fontSize: 1,
                                            ),
                                            cursorColor: Colors.transparent,
                                            decoration: const InputDecoration(
                                              counterText: '',
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                              errorStyle: TextStyle(
                                                fontSize: 0,
                                                height: 0,
                                              ),
                                            ),
                                            validator: (value) =>
                                                value != null &&
                                                    value.length ==
                                                        _otpLength &&
                                                    RegExp(
                                                      r'^\d+$',
                                                    ).hasMatch(value)
                                                ? null
                                                : 'Enter all $_otpLength digits.',
                                            onFieldSubmitted: (_) => _verify(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_showOtpError)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Enter all digits to continue.',
                                      style: TextStyle(
                                        color: Color(0xFFB3261E),
                                        fontSize: 12,
                                      ),
                                    ),
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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFBFD),
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            widget.onContact ??
                            () => _notice(
                              _previewAllowed
                                  ? 'For this preview, return to Booking Details and contact Pinkora support through the normal channel.'
                                  : 'Ask the customer to confirm the code and retry.',
                            ),
                        icon: Icon(
                          widget.onContact == null
                              ? Icons.support_agent_outlined
                              : Icons.call_rounded,
                          size: 18,
                        ),
                        label: Text(
                          widget.onContact == null
                              ? 'Need Help'
                              : 'Call Customer',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _pink,
                          side: const BorderSide(color: _pink),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: Key(
                          _previewAllowed
                              ? 'verify-start-service'
                              : 'next-to-start-service-otp',
                        ),
                        onPressed:
                            !_checking &&
                                !_uploadingPhoto &&
                                (_previewAllowed || _evidenceIds.isNotEmpty)
                            ? _previewAllowed
                                  ? _verify
                                  : _continueToOtp
                            : null,
                        icon: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _previewAllowed
                                    ? Icons.check_circle_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _pink,
                          disabledBackgroundColor: const Color(0xFFF2C0D2),
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        label: Text(
                          _previewAllowed
                              ? 'Verify & Start Service'
                              : _evidenceIds.isEmpty
                              ? 'Add at least one photo'
                              : 'Next',
                          textAlign: TextAlign.center,
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
