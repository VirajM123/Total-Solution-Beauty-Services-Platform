import '../../../integration/worker_environment.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UI-only simulation. A `true` result is never proof of phone ownership.
class WorkerRegistrationMobileOtpScreen extends StatefulWidget {
  const WorkerRegistrationMobileOtpScreen({super.key, required this.mobile});

  final String mobile;

  @override
  State<WorkerRegistrationMobileOtpScreen> createState() =>
      _WorkerRegistrationMobileOtpScreenState();
}

class _WorkerRegistrationMobileOtpScreenState
    extends State<WorkerRegistrationMobileOtpScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _busy = false;
  String _lastOtpInput = '';

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || !WorkerEnvironment.developmentPreview) return;
    if (_controller.text.length != 6) {
      setState(() => _error = 'Enter all six digits.');
      return;
    }
    setState(() => _error = 'No server-issued registration challenge is active.');
  }

  @override
  Widget build(BuildContext context) {
    const plum = Color(0xFF460621);
    const berry = Color(0xFFB20A50);
    const muted = Color(0xFF624352);
    const ivory = Color(0xFFFFF9F5);
    return Scaffold(
      backgroundColor: ivory,
      appBar: AppBar(
        backgroundColor: ivory,
        foregroundColor: plum,
        title: const Text(
          'Mobile verification',
          style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.phonelink_lock_rounded,
                    color: berry,
                    size: 48,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Verify your mobile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: plum,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Development preview for +91 ${widget.mobile}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBF2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'A server-issued verification code is required. '
                      'This screen does not accept local demo codes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: plum, fontSize: 12, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('registration-mobile-demo-otp'),
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      letterSpacing: 14,
                      color: plum,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      hintText: '••••••',
                      hintStyle: const TextStyle(
                        color: Color(0xFFBFA5B1),
                        letterSpacing: 14,
                      ),
                      errorText: _error,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE8C9CE)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: berry, width: 2),
                      ),
                    ),
                    onChanged: (_) {
                      final value = _controller.text;
                      if (value.length > _lastOtpInput.length ||
                          (value.length == _lastOtpInput.length &&
                              value != _lastOtpInput)) {
                        HapticFeedback.lightImpact();
                      }
                      _lastOtpInput = value;
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD41361), Color(0xFF750034)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: FilledButton(
                        onPressed: _busy || !WorkerEnvironment.developmentPreview ? null : _verify,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                        ),
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Verify demo code',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Real SMS verification will be implemented later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 12),
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
