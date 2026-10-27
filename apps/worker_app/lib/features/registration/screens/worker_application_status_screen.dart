import 'package:flutter/material.dart';

import '../../../integration/worker_api.dart';
import '../../../integration/worker_mobile_auth_api.dart';
import '../../home/worker_home_screen.dart';

// Hi Beauty worker application status UI.
// Connected to backend status checks for live admin verification updates.

enum WorkerApplicationStage {
  preview,
  submitted,
  underReview,
  adminVerification,
  actionRequired,
  approved,
  rejected,
}

class WorkerApplicationStatusScreen extends StatefulWidget {
  const WorkerApplicationStatusScreen({
    super.key,
    this.stage = WorkerApplicationStage.preview,
    this.submittedAt,
    this.applicationReference,
    this.reviewMessage,
    this.onBackToLogin,
    this.authApi,
    this.workerPhone,
  });

  final WorkerApplicationStage stage;
  final DateTime? submittedAt;
  final String? applicationReference;
  final String? reviewMessage;
  final VoidCallback? onBackToLogin;
  final WorkerAuthApi? authApi;
  final String? workerPhone;

  @override
  State<WorkerApplicationStatusScreen> createState() =>
      _WorkerApplicationStatusScreenState();
}

class _WorkerApplicationStatusScreenState
    extends State<WorkerApplicationStatusScreen> {
  late WorkerApplicationStage _stage;
  bool _checking = false;
  String? _message;

  static const _plum = Color(0xFF460621);
  static const _berry = Color(0xFFB20A50);
  static const _muted = Color(0xFF755B67);
  static const _ivory = Color(0xFFFFF9F5);
  static const _line = Color(0xFFEEDCE2);

  @override
  void initState() {
    super.initState();
    _stage = widget.stage;
    _message = widget.reviewMessage;
  }

  bool get _isPreview => _stage == WorkerApplicationStage.preview;

  int get _progress {
    switch (_stage) {
      case WorkerApplicationStage.preview:
        return -1;
      case WorkerApplicationStage.submitted:
        return 0;
      case WorkerApplicationStage.underReview:
        return 1;
      case WorkerApplicationStage.adminVerification:
        return 2;
      case WorkerApplicationStage.actionRequired:
        return 1;
      case WorkerApplicationStage.approved:
        return 3;
      case WorkerApplicationStage.rejected:
        return 2;
    }
  }

  String get _headline {
    switch (_stage) {
      case WorkerApplicationStage.preview:
        return 'Almost there!';
      case WorkerApplicationStage.submitted:
      case WorkerApplicationStage.underReview:
      case WorkerApplicationStage.adminVerification:
        return 'Application Submitted!';
      case WorkerApplicationStage.actionRequired:
        return 'Action Required';
      case WorkerApplicationStage.approved:
        return 'You’re Approved!';
      case WorkerApplicationStage.rejected:
        return 'Application Update';
    }
  }

  String get _subtitle {
    switch (_stage) {
      case WorkerApplicationStage.preview:
        return 'This is a preview of your application status screen. Complete registration to submit.';
      case WorkerApplicationStage.submitted:
      case WorkerApplicationStage.underReview:
      case WorkerApplicationStage.adminVerification:
        return _message ?? 'Thank you for joining Hi Beauty. Your application is under admin review.';
      case WorkerApplicationStage.actionRequired:
        return _message ?? 'Some information needs updating before review can continue.';
      case WorkerApplicationStage.approved:
        return 'Your partner registration has been approved by the Hi Beauty team. You can now access your dashboard and start accepting bookings!';
      case WorkerApplicationStage.rejected:
        return _message ?? 'Your application could not be approved at this time.';
    }
  }

  String? get _dateText {
    final date = widget.submittedAt;
    if (date == null || _isPreview) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute $ampm';
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final auth = widget.authApi ?? WorkerMobileAuthApi();
      if (auth is WorkerMobileAuthApi) {
        final statusData = await auth.checkWorkerStatus();
        final serverStatus = '${statusData['status'] ?? ''}';
        if (!mounted) return;
        if (serverStatus == 'approved') {
          setState(() {
            _stage = WorkerApplicationStage.approved;
            _message = null;
          });
        } else if (serverStatus == 'pending') {
          setState(() {
            _stage = WorkerApplicationStage.underReview;
            _message = 'Application is currently under review by our admin team.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application is still pending admin review.')),
          );
        } else if (serverStatus == 'rejected') {
          setState(() {
            _stage = WorkerApplicationStage.rejected;
            _message = 'Your application was rejected by the administration.';
          });
        }
      } else {
        final identity = await auth.currentIdentity();
        if (!mounted) return;
        if (identity.approval == WorkerApproval.approved) {
          setState(() => _stage = WorkerApplicationStage.approved);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _goToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => WorkerHomeScreen(
          phoneNumber: widget.workerPhone ?? '',
          demoMode: false,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = _stage != WorkerApplicationStage.rejected &&
        _stage != WorkerApplicationStage.actionRequired;
    final isApproved = _stage == WorkerApplicationStage.approved;

    return Scaffold(
      backgroundColor: _ivory,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                    children: [
                      const SizedBox(height: 8),
                      _hero(isPositive: isPositive),
                      const SizedBox(height: 12),
                      Text(
                        _headline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _plum,
                          fontFamily: 'Georgia',
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                      if (_isPreview) ...[
                        const SizedBox(height: 14),
                        _previewBanner(),
                      ],
                      if (widget.applicationReference != null && !_isPreview) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Application ID: ${widget.applicationReference}',
                              style: const TextStyle(
                                color: _berry,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _timeline(),
                      const SizedBox(height: 22),
                      _notificationInfo(),
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: _ivory,
                    border: Border(top: BorderSide(color: _line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isApproved) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD41361), Color(0xFF750034)],
                              ),
                              borderRadius: BorderRadius.circular(27),
                            ),
                            child: FilledButton(
                              onPressed: _goToDashboard,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(27),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Go to Partner Dashboard',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _checking ? null : _checkStatus,
                            icon: _checking
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 19),
                            label: Text(
                              _checking ? 'Checking Status…' : 'Check Review Status',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _berry,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: widget.onBackToLogin ?? () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _plum,
                            side: const BorderSide(color: Color(0xFFF0B8C9)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(27),
                            ),
                          ),
                          child: const Text('Back to Login',
                              style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _hero({required bool isPositive}) {
    return SizedBox(
      height: 145,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 15,
            left: 25,
            child: Transform.rotate(
              angle: -.35,
              child: const Icon(Icons.spa_rounded,
                  color: Color(0xFF97AA80), size: 54),
            ),
          ),
          Positioned(
            top: 37,
            right: 20,
            child: Transform.rotate(
              angle: .45,
              child: const Icon(Icons.local_florist_rounded,
                  color: Color(0xFFEAA0B5), size: 54),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 73,
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFFEAC073), size: 21),
          ),
          Positioned(
            top: 12,
            right: 79,
            child: const Icon(Icons.favorite,
                color: Color(0xFFF6B2CA), size: 17),
          ),
          Container(
            width: 125,
            height: 142,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF6F9), Color(0xFFF3C4D5)],
              ),
              border: Border.all(color: const Color(0xFFEBAFC2), width: 2),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(color: Color(0x23A60C52), blurRadius: 20, offset: Offset(0, 9)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_rounded,
                    color: Color(0xFFD786A3), size: 46),
                const SizedBox(height: 3),
                Container(
                  width: 75,
                  height: 75,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFEB3D85), Color(0xFF9C084C)],
                    ),
                    boxShadow: [BoxShadow(
                        color: Color(0x44B20A50), blurRadius: 14, offset: Offset(0, 4))],
                  ),
                  child: Icon(
                    isPositive ? Icons.check_rounded : Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF2),
        border: Border.all(color: const Color(0xFFF0CAD7)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, color: _berry, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'UI preview only · Not submitted · No documents uploaded',
              style: TextStyle(color: _plum, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline() {
    final labels = <String>[
      'Submitted',
      'Under Review',
      'Admin Verification',
      'Approved',
    ];
    final captions = <String>[
      _isPreview ? 'Waiting for registration submission' : (_dateText ?? 'Application received'),
      'Our team is checking your details.',
      'Document and profile verification.',
      'You’ll receive a notification.',
    ];
    return Column(
      children: List.generate(labels.length, (index) {
        final completed = _progress >= index;
        final active = _progress == index;
        final last = index == labels.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 37,
                child: Column(
                  children: [
                    Container(
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: completed && !active ? _berry :
                          active ? const Color(0xFFFFF1F5) : const Color(0xFFC4B9BE),
                        shape: BoxShape.circle,
                        border: active ? Border.all(color: _berry, width: 2) : null,
                      ),
                      child: Icon(
                        completed && !active ? Icons.check_rounded :
                          active ? Icons.access_time_rounded : Icons.circle,
                        size: completed && !active ? 17 : active ? 16 : 9,
                        color: completed && !active ? Colors.white :
                          active ? _berry : Colors.white,
                      ),
                    ),
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 2,
                          constraints: const BoxConstraints(minHeight: 25),
                          color: completed && !active ? _berry : _line,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 0 : 18, top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labels[index], style: const TextStyle(
                          color: _plum, fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(captions[index], style: const TextStyle(
                          color: _muted, fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _notificationInfo() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF1),
        borderRadius: BorderRadius.circular(17),
      ),
      padding: const EdgeInsets.all(13),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: Color(0xFFFFD9E6),
            child: Icon(Icons.notifications_active_outlined, color: _berry),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Once approved by the admin team, your account will be enabled to accept customer appointments.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
