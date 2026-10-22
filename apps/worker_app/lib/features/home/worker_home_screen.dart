import '../../integration/worker_environment.dart';

import 'package:flutter/material.dart';

import '../login/worker_login_screen.dart';
import 'worker_dashboard_screen.dart';
import 'worker_profile_data.dart';
import 'worker_payout_data.dart';

/// The OTP route supplies the phone used to look up the local demo profile.
/// It is not evidence of a server-authenticated account.
class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({
    super.key,
    this.phoneNumber = '',
    this.demoMode = true,
    this.profileRepository,
    this.payoutRepository,
  });

  final String phoneNumber;
  final bool demoMode;
  final WorkerProfileRepository? profileRepository;
  final WorkerPayoutRepository? payoutRepository;

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  WorkerProfile? _profile;
  Object? _profileError;
  WorkerProfileRepository get _repository =>
      widget.profileRepository ?? WorkerProfileStore.repository;

  @override
  void initState() {
    super.initState();
    if (!WorkerEnvironment.developmentPreview) return;
    _repository.addListener(_profileChanged);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      await _repository.load(widget.phoneNumber);
      if (mounted) {
        setState(() {
          _profile = _repository.profileFor(widget.phoneNumber);
          _profileError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _profileError = error);
    }
  }

  void _profileChanged() {
    if (!mounted) return;
    setState(() => _profile = _repository.profileFor(widget.phoneNumber));
  }

  void _exitPreview() {
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => const WorkerLoginScreen(demoEnabled: WorkerEnvironment.developmentPreview),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _repository.removeListener(_profileChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!WorkerEnvironment.developmentPreview) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF9F5),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 52, color: Color(0xFFB20A50)),
                  SizedBox(height: 16),
                  Text(
                    'Worker access not configured',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF460621),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Secure worker authentication and admin approval are required before dashboard access.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_profileError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9F5),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load local worker profile.'),
                  const SizedBox(height: 8),
                  Text('$_profileError', textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _loadProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return WorkerDashboardScreen(
      demoMode: widget.demoMode,
      workerPhone: widget.phoneNumber,
      profileRepository: _repository,
      payoutRepository: widget.payoutRepository,
      workerName: _profile?.fullName.isNotEmpty == true
          ? _profile!.fullName
          : 'Worker',
      location: _profile?.cityOrArea.isNotEmpty == true
          ? _profile!.cityOrArea
          : 'Your service area',
      profilePhotoPath: _profile?.profilePhotoPath,
      onLogoutTap: _exitPreview,
    );
  }
}
