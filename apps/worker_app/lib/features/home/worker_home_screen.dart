
import 'package:flutter/material.dart';

import '../login/worker_login_screen.dart';
import 'worker_dashboard_screen.dart';
import 'worker_profile_data.dart';
import 'worker_payout_data.dart';

/// Worker home and operational dashboard screen.
class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({
    super.key,
    this.phoneNumber = '',
    this.demoMode = false,
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
        builder: (_) => const WorkerLoginScreen(demoEnabled: false),
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
    return WorkerDashboardScreen(
      demoMode: widget.demoMode,
      workerPhone: widget.phoneNumber,
      profileRepository: _repository,
      payoutRepository: widget.payoutRepository,
      workerName: _profile?.fullName.isNotEmpty == true
          ? _profile!.fullName
          : 'Hi Beauty Partner',
      location: _profile?.cityOrArea.isNotEmpty == true
          ? _profile!.cityOrArea
          : 'Latur',
      profilePhotoPath: _profile?.profilePhotoPath,
      onLogoutTap: _exitPreview,
    );
  }
}
