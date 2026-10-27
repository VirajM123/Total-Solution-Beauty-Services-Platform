import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../integration/worker_api.dart';
import '../../../integration/worker_mobile_auth_api.dart';
import '../../../app/slide_page_route.dart';
import '../../otp/worker_otp_screen.dart';
import 'worker_personal_details_screen.dart';

class WorkerAccountRegistrationScreen extends StatefulWidget {
  const WorkerAccountRegistrationScreen({
    super.key,
    required this.phone,
    this.registrationToken,
    required this.authApi,
  });

  final String phone;
  final String? registrationToken;
  final WorkerAuthApi authApi;

  @override
  State<WorkerAccountRegistrationScreen> createState() =>
      _WorkerAccountRegistrationScreenState();
}

class _WorkerAccountRegistrationScreenState
    extends State<WorkerAccountRegistrationScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(
        () => _error = 'Enter a valid email address or leave this blank.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.registrationToken == null) {
        await widget.authApi.requestOtp(widget.phone, forRegistration: true);
        if (!mounted) return;
        await Navigator.of(context).push(
          SlidePageRoute<void>(
            page: WorkerOtpScreen(
              phone: widget.phone,
              authApi: widget.authApi,
              registrationName: name,
              registrationEmail: email,
            ),
          ),
        );
        return;
      }
      await widget.authApi.completeRegistration(
        registrationToken: widget.registrationToken!,
        fullName: name,
        email: email,
      );
      if (!mounted) return;
      // Seamlessly transition to Personal & Professional application details
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => WorkerPersonalDetailsScreen(
            initialName: name,
            initialMobile: widget.phone,
            initialEmail: email,
            verifiedMobile: widget.phone,
            authApi: widget.authApi,
          ),
        ),
        (_) => false,
      );
    } on WorkerAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complete worker account')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Create worker account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('+91 ${widget.phone}'),
              const SizedBox(height: 20),
              TextField(
                key: const Key('worker-account-full-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              TextField(
                key: const Key('worker-account-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _register,
                child: _busy
                    ? const CircularProgressIndicator()
                    : Text(
                        widget.registrationToken == null
                            ? 'Verify mobile and continue'
                            : 'Continue to Partner Application',
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
