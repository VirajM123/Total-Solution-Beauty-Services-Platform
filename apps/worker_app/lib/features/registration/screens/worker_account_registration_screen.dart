import '../../widgets/worker_auth_visuals.dart';
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

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFFFF1678)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFFFCEE0)),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFFCFD),
    appBar: AppBar(
      title: const WorkerAuthBrand(subtitle: 'Beauty Services, Brighter You'),
      toolbarHeight: 60,
      backgroundColor: const Color(0xFFFFFCFD),
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              const WorkerAuthHero(height: 210),
              const SizedBox(height: 18),
              const Text(
                'CREATE YOUR ACCOUNT',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: Color(0xFFFF1678),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join Hi Beauty\nas a Worker',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF210B35),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Showcase your skills, connect with clients and grow your beauty career.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF686080),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFF5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFDCE9)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 1 of 4',
                      style: TextStyle(
                        color: Color(0xFFFF1678),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF210B35),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Let’s start with your basic details.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF686080)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('worker-account-full-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: _decoration('Full name', Icons.person_outline),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('worker-account-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration('Email (optional)', Icons.mail_outline),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: _decoration('Mobile number', Icons.phone_outlined),
                child: Text(
                  '+91 ${widget.phone}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF210B35),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF237C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: _busy ? null : _register,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.registrationToken == null
                            ? 'Verify mobile and continue'
                            : 'Continue to Partner Application',
                        textAlign: TextAlign.center,
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
