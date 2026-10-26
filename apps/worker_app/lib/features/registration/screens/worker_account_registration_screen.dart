import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../integration/worker_api.dart';
import '../../../integration/worker_mobile_auth_api.dart';
import 'worker_application_status_screen.dart';

class WorkerAccountRegistrationScreen extends StatefulWidget {
  const WorkerAccountRegistrationScreen({
    super.key,
    required this.phone,
    required this.registrationToken,
    required this.authApi,
  });

  final String phone;
  final String registrationToken;
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
    if (_busy || _name.text.trim().length < 2) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authApi.completeRegistration(
        registrationToken: widget.registrationToken,
        fullName: _name.text,
        email: _email.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const WorkerApplicationStatusScreen(
            stage: WorkerApplicationStage.preview,
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
                'Mobile number verified',
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
                    : const Text('Create worker account'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
