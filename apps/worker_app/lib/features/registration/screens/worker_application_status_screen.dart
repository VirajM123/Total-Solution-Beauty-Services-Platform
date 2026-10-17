import 'package:flutter/material.dart';

// Pinkora worker application status UI.
// Preview mode is the default: never represent local form completion as a
// submitted or approved application. Production status must come from backend.

enum WorkerApplicationStage {
  preview,
  submitted,
  underReview,
  adminVerification,
  actionRequired,
  approved,
  rejected,
}

class WorkerApplicationStatusScreen extends StatelessWidget {
  const WorkerApplicationStatusScreen({
    super.key,
    this.stage = WorkerApplicationStage.preview,
    this.submittedAt,
    this.applicationReference,
    this.reviewMessage,
    this.onBackToLogin,
  });

  final WorkerApplicationStage stage;
  final DateTime? submittedAt;
  final String? applicationReference;
  final String? reviewMessage;
  final VoidCallback? onBackToLogin;

  static const _plum = Color(0xFF460621);
  static const _berry = Color(0xFFB20A50);
  static const _muted = Color(0xFF755B67);
  static const _ivory = Color(0xFFFFF9F5);
  static const _line = Color(0xFFEEDCE2);

  bool get _isPreview => stage == WorkerApplicationStage.preview;

  int get _progress {
    switch (stage) {
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
    switch (stage) {
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
    switch (stage) {
      case WorkerApplicationStage.preview:
        return 'This is a preview of your application status screen. No application has been sent yet.';
      case WorkerApplicationStage.submitted:
      case WorkerApplicationStage.underReview:
      case WorkerApplicationStage.adminVerification:
        return 'Thank you for joining Pinkora. We’ll notify you after admin review.';
      case WorkerApplicationStage.actionRequired:
        return reviewMessage ?? 'Some information needs updating before review can continue.';
      case WorkerApplicationStage.approved:
        return 'Your registration has been approved by the Pinkora team.';
      case WorkerApplicationStage.rejected:
        return reviewMessage ?? 'Your application could not be approved at this time.';
    }
  }

  String? get _dateText {
    final date = submittedAt;
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

  @override
  Widget build(BuildContext context) {
    final isPositive = stage != WorkerApplicationStage.rejected &&
        stage != WorkerApplicationStage.actionRequired;
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
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
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
                          fontSize: 29,
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
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      if (_isPreview) ...[
                        const SizedBox(height: 14),
                        _previewBanner(),
                      ],
                      if (applicationReference != null && !_isPreview) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'Application: $applicationReference',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
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
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: onBackToLogin ?? () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _plum,
                        backgroundColor: const Color(0xFFFFE9F0),
                        side: const BorderSide(color: Color(0xFFF0B8C9)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: const Text('Back to Login',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
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
      height: 195,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 15,
            left: 25,
            child: Transform.rotate(
              angle: -.35,
              child: const Icon(Icons.spa_rounded,
                  color: Color(0xFF97AA80), size: 70),
            ),
          ),
          Positioned(
            top: 37,
            right: 20,
            child: Transform.rotate(
              angle: .45,
              child: const Icon(Icons.local_florist_rounded,
                  color: Color(0xFFEAA0B5), size: 70),
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
      _isPreview ? 'Waiting for real backend submission' : (_dateText ?? 'Application received'),
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
                      width: 26,
                      height: 26,
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
                  padding: EdgeInsets.only(bottom: last ? 0 : 27, top: 2),
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
              'Once notifications are connected, we’ll update you about your application by the available channels.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
