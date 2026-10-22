import '../../../integration/worker_environment.dart';
import 'dart:async';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _plum = Color(0xFF460621);
const _berry = Color(0xFFB20A50);
const _muted = Color(0xFF624352);
const _ivory = Color(0xFFFFF9F5);
const _line = Color(0xFFE8C9CE);

/// Development-only email-code preview. No email is delivered, and a successful
/// result MUST NOT be used as proof of ownership or grant registration access.
class WorkerRegistrationEmailOtpScreen extends StatefulWidget {
  const WorkerRegistrationEmailOtpScreen({super.key, required this.email});

  final String email;

  @override
  State<WorkerRegistrationEmailOtpScreen> createState() =>
      _WorkerRegistrationEmailOtpScreenState();
}

class _WorkerRegistrationEmailOtpScreenState
    extends State<WorkerRegistrationEmailOtpScreen> {
  final _codeController = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = 30;
  String? _error;
  bool _verifying = false;
  String _lastOtpInput = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verify() async {
    if (_verifying) return;
    if (!WorkerEnvironment.developmentPreview) {
      setState(
        () => _error = 'Demo verification is unavailable in this build.',
      );
      return;
    }
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the complete 6-digit demo code.');
      return;
    }
    if (code != '654321') {
      setState(() => _error = 'Incorrect development email code.');
      return;
    }
    setState(() {
      _error = null;
      _verifying = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ivory,
      appBar: AppBar(
        backgroundColor: _ivory,
        foregroundColor: _plum,
        title: const Text(
          'Email verification',
          style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFBE4EE),
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 42,
                        color: _berry,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _plum,
                      fontFamily: 'Georgia',
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Development preview for',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _plum,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '6-digit development code',
                    style: TextStyle(color: _plum, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('worker-registration-email-code'),
                    controller: _codeController,
                    enabled: WorkerEnvironment.developmentPreview && !_verifying,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      color: _plum,
                      fontSize: 24,
                      letterSpacing: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      errorText: _error,
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _berry, width: 1.6),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (value) {
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
                  const SizedBox(height: 22),
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
                        onPressed: !WorkerEnvironment.developmentPreview || _verifying ? null : _verify,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _verifying
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _secondsRemaining > 0
                        ? 'Demo timer: ${_secondsRemaining}s'
                        : 'Demo timer finished',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: !WorkerEnvironment.developmentPreview || _secondsRemaining > 0
                          ? null
                          : _startTimer,
                      child: const Text('Restart demo timer'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE9F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'DEVELOPMENT ONLY  •  Code: 654321\n'
                      'No email is sent. Success is a UI preview, not real verification.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _plum, fontSize: 12, height: 1.5),
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
