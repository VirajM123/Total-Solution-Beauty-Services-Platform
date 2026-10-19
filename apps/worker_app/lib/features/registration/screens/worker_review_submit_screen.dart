import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/slide_page_route.dart';
import '../../home/worker_profile_data.dart';
import 'worker_application_status_screen.dart';

// Step 4 is intentionally a DEBUG-ONLY local review preview.
// No application, identity document or verification result is transmitted.
const _plum = Color(0xFF460621);
const _berry = Color(0xFFB20A50);
const _muted = Color(0xFF624352);
const _ivory = Color(0xFFFFF9F5);
const _line = Color(0xFFE8C9CE);

class WorkerReviewSubmitScreen extends StatefulWidget {
  const WorkerReviewSubmitScreen({
    super.key,
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.dateOfBirth,
    required this.cityOrArea,
    required this.primaryCategory,
    required this.services,
    required this.yearsOfExperience,
    required this.workMode,
    required this.travelRadiusKm,
    required this.languages,
    required this.about,
    required this.certificateDetails,
    required this.identityType,
    required this.identityFileFormat,
    this.professionalCertificateFormat,
    this.profilePhotoBytes,
    this.profileRepository,
  });

  final String fullName;
  final String mobile;
  final String email;
  final DateTime dateOfBirth;
  final String cityOrArea;
  final Uint8List? profilePhotoBytes;
  final WorkerProfileRepository? profileRepository;
  final String primaryCategory;
  final List<String> services;
  final int yearsOfExperience;
  final String workMode;
  final int travelRadiusKm;
  final List<String> languages;
  final String about;
  final String certificateDetails;
  final String identityType;
  final String identityFileFormat;
  final String? professionalCertificateFormat;

  @override
  State<WorkerReviewSubmitScreen> createState() =>
      _WorkerReviewSubmitScreenState();
}

class _WorkerReviewSubmitScreenState extends State<WorkerReviewSubmitScreen> {
  bool _confirmedAccurate = false;
  bool _understandsDemo = false;
  bool _savingPreview = false;

  Future<void> _previewSubmission() async {
    if (!kDebugMode || _savingPreview) return;
    if (!_confirmedAccurate || !_understandsDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm both statements first.')),
      );
      return;
    }
    setState(() => _savingPreview = true);
    try {
      await (widget.profileRepository ?? WorkerProfileStore.repository)
          .saveRegistration(
            WorkerProfile(
              mobile: widget.mobile,
              fullName: widget.fullName,
              email: widget.email,
              dateOfBirth: widget.dateOfBirth,
              cityOrArea: widget.cityOrArea,
              primaryCategory: widget.primaryCategory,
              services: List.unmodifiable(widget.services),
              yearsOfExperience: widget.yearsOfExperience,
              workMode: widget.workMode,
              travelRadiusKm: widget.travelRadiusKm,
              languages: List.unmodifiable(widget.languages),
              about: widget.about,
              certificateDetails: widget.certificateDetails,
            ),
            profilePhotoBytes: widget.profilePhotoBytes,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save local preview profile: $error'),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _savingPreview = false);
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: const WorkerApplicationStatusScreen(
          stage: WorkerApplicationStage.preview,
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _plum,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _section({
    required IconData icon,
    required String heading,
    required List<Widget> children,
    String? note,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9E7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _berry, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                heading,
                style: const TextStyle(
                  color: _plum,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: _line),
        const SizedBox(height: 7),
        ...children,
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: const TextStyle(color: _muted, fontSize: 11.5)),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(widget.dateOfBirth);
    return Scaffold(
      backgroundColor: _ivory,
      appBar: AppBar(
        title: const Text(
          'Join Hi Beauty',
          style: TextStyle(
            fontFamily: 'Georgia',
            color: _plum,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: _ivory,
        foregroundColor: _plum,
        surfaceTintColor: _ivory,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'STEP 4 OF 4',
                              style: TextStyle(
                                color: _berry,
                                fontSize: 11,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            'Review',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          value: 1,
                          minHeight: 5,
                          backgroundColor: Color(0xFFF3DFE5),
                          color: _berry,
                        ),
                      ),
                      const SizedBox(height: 23),
                      const Text(
                        'Almost there, beautiful',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          color: _plum,
                          fontWeight: FontWeight.w700,
                          fontSize: 27,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Review your information before the final application process.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 17),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8E9EF),
                          border: Border.all(color: _line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: _berry,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'DEVELOPMENT PREVIEW ONLY. Contact OTPs are simulated. '
                                'Nothing on this page will be submitted or approved.',
                                style: TextStyle(
                                  color: _plum,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 19),
                      _section(
                        icon: Icons.person_outline,
                        heading: 'Personal details',
                        children: [
                          if (widget.profilePhotoBytes != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundImage: MemoryImage(
                                  widget.profilePhotoBytes!,
                                ),
                              ),
                            ),
                          _detail('Full name', widget.fullName),
                          _detail('Mobile', '+91 ${widget.mobile}'),
                          _detail('Email', widget.email),
                          _detail('Date of birth', date),
                          _detail('City / area', widget.cityOrArea),
                        ],
                        note:
                            'Mobile and email have only been tested using demo codes.',
                      ),
                      _section(
                        icon: Icons.auto_awesome_outlined,
                        heading: 'Professional details',
                        children: [
                          _detail('Expertise', widget.primaryCategory),
                          _detail('Services', widget.services.join(', ')),
                          _detail(
                            'Experience',
                            '${widget.yearsOfExperience} year(s)',
                          ),
                          _detail('Work mode', widget.workMode),
                          if (widget.workMode != 'Salon-based')
                            _detail(
                              'Travel radius',
                              '${widget.travelRadiusKm} km',
                            ),
                          _detail('Languages', widget.languages.join(', ')),
                          if (widget.about.isNotEmpty)
                            _detail('About', widget.about),
                          if (widget.certificateDetails.isNotEmpty)
                            _detail('Training', widget.certificateDetails),
                        ],
                      ),
                      _section(
                        icon: Icons.description_outlined,
                        heading: 'Documents',
                        children: [
                          _detail('Identity proof', widget.identityType),
                          _detail(
                            'Selected format',
                            widget.identityFileFormat.toUpperCase(),
                          ),
                          _detail(
                            'Certificate',
                            widget.professionalCertificateFormat == null
                                ? 'Not added (optional)'
                                : '${widget.professionalCertificateFormat!.toUpperCase()} selected',
                          ),
                        ],
                        note:
                            'Selected locally; documents are not uploaded or verified. '
                            'Sensitive filenames and ID numbers are intentionally not displayed.',
                      ),
                      const SizedBox(height: 3),
                      CheckboxListTile(
                        value: _confirmedAccurate,
                        onChanged: (value) =>
                            setState(() => _confirmedAccurate = value ?? false),
                        activeColor: _berry,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'I confirm the entered information is accurate.',
                          style: TextStyle(color: _plum, fontSize: 12.5),
                        ),
                      ),
                      CheckboxListTile(
                        value: _understandsDemo,
                        onChanged: (value) =>
                            setState(() => _understandsDemo = value ?? false),
                        activeColor: _berry,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'I understand this is a demo, not a real submission.',
                          style: TextStyle(color: _plum, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'To edit earlier information, use Back to Documents, then Back '
                        'through Professional Details to Personal Details. '
                        'Selected document files remain in memory while Page 3 is open.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                  decoration: const BoxDecoration(
                    color: _ivory,
                    border: Border(top: BorderSide(color: _line)),
                  ),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _plum,
                          side: const BorderSide(color: _line),
                          minimumSize: const Size(90, 50),
                        ),
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD41361), Color(0xFF750034)],
                              ),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: FilledButton.icon(
                              onPressed: kDebugMode && !_savingPreview
                                  ? _previewSubmission
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                              ),
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 19,
                              ),
                              label: Text(
                                _savingPreview
                                    ? 'Saving local profile…'
                                    : 'Preview submission',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
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
