import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/slide_page_route.dart';
import '../../home/worker_profile_data.dart';
import 'worker_application_status_screen.dart';
import '../../../integration/worker_api.dart';
import '../../../integration/worker_mobile_auth_api.dart';
import 'worker_document_verification_screen.dart';

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
    this.authApi,
    this.identityDocument,
    this.certificateDocument,
    this.catalogServices = const [],
    this.catalogAreas = const [],
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
  final WorkerAuthApi? authApi;
  final WorkerSelectedDocument? identityDocument;
  final WorkerSelectedDocument? certificateDocument;
  final List<Map<String, dynamic>> catalogServices;
  final List<Map<String, dynamic>> catalogAreas;

  @override
  State<WorkerReviewSubmitScreen> createState() =>
      _WorkerReviewSubmitScreenState();
}

class _WorkerReviewSubmitScreenState extends State<WorkerReviewSubmitScreen> {
  bool _confirmedAccurate = false;
  bool _termsAgreed = false;
  bool _understandsDemo = false;
  bool _savingPreview = false;
  bool _submitting = false;
  bool get _isLiveSubmission => widget.identityDocument != null;

  Future<void> _previewSubmission() async {
    if (_savingPreview) return;
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

  Future<void> _submitApplication() async {
    if (_submitting) return;
    if (!_confirmedAccurate || !_termsAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm both statements before submitting.')),
      );
      return;
    }
    if (widget.identityDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identity proof file is missing.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final auth = widget.authApi ?? WorkerMobileAuthApi();

    try {
      // 1. Upload identity document to backend
      final doc = widget.identityDocument!;
      final mime = doc.isImage
          ? (doc.extension.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg')
          : 'application/pdf';

      final mediaAssetId = await auth.uploadDocument(
        bytes: doc.bytes,
        fileName: doc.name,
        mimeType: mime,
      );

      // 2. Resolve service IDs & service area IDs
      var serviceIds = <String>[];
      if (widget.catalogServices.isNotEmpty) {
        for (final sName in widget.services) {
          final match = widget.catalogServices.firstWhere(
            (s) => s['name'] == sName,
            orElse: () => <String, dynamic>{},
          );
          final id = match['id'] ?? match['_id'];
          if (id != null && id.toString().isNotEmpty) {
            serviceIds.add(id.toString());
          }
        }
      }
      if (serviceIds.isEmpty) {
        final fetchedServices = await auth.fetchServices();
        for (final sName in widget.services) {
          final match = fetchedServices.firstWhere(
            (s) => s['name'] == sName,
            orElse: () => <String, dynamic>{},
          );
          final id = match['id'] ?? match['_id'];
          if (id != null && id.toString().isNotEmpty) {
            serviceIds.add(id.toString());
          }
        }
        if (serviceIds.isEmpty && fetchedServices.isNotEmpty) {
          final firstId = fetchedServices.first['id'] ?? fetchedServices.first['_id'];
          if (firstId != null) serviceIds.add(firstId.toString());
        }
      }

      var serviceAreaIds = <String>[];
      if (widget.catalogAreas.isNotEmpty) {
        for (final a in widget.catalogAreas) {
          final id = a['_id'] ?? a['id'];
          if (id != null && id.toString().isNotEmpty) {
            serviceAreaIds.add(id.toString());
          }
        }
      }
      if (serviceAreaIds.isEmpty) {
        final fetchedAreas = await auth.fetchServiceAreas();
        if (fetchedAreas.isNotEmpty) {
          final firstId = fetchedAreas.first['_id'] ?? fetchedAreas.first['id'];
          if (firstId != null) serviceAreaIds.add(firstId.toString());
        }
      }

      // 3. Submit registration to backend
      final identity = await auth.submitRegistration(
        experienceYears: widget.yearsOfExperience,
        serviceIds: serviceIds,
        serviceAreaIds: serviceAreaIds,
        identityMediaAssetId: mediaAssetId,
      );

      if (!mounted) return;

      // 4. Navigate to WorkerApplicationStatusScreen
      Navigator.of(context).pushAndRemoveUntil(
        SlidePageRoute<void>(
          page: WorkerApplicationStatusScreen(
            stage: WorkerApplicationStage.underReview,
            applicationReference: identity.workerId.isNotEmpty ? identity.workerId : null,
            authApi: auth,
            workerPhone: widget.mobile,
            reviewMessage: 'Your application has been received and is pending admin verification.',
          ),
        ),
        (_) => false,
      );
    } on WorkerAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ' + e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
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
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                      const SizedBox(height: 14),
                      const Text(
                        'Almost there, beautiful',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          color: _plum,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
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
                      if (!_isLiveSubmission)
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
                        )
                      else
                        CheckboxListTile(
                          value: _termsAgreed,
                          onChanged: (value) =>
                              setState(() => _termsAgreed = value ?? false),
                          activeColor: _berry,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'I agree to the partner verification terms and review process.',
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 9),
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
                          minimumSize: const Size(76, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD41361), Color(0xFF750034)],
                              ),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: !_isLiveSubmission
                                ? FilledButton.icon(
                                    onPressed: _savingPreview ? null : _previewSubmission,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
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
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : FilledButton.icon(
                                    onPressed: _submitting ? null : _submitApplication,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                    icon: _submitting
                                        ? const SizedBox.square(
                                            dimension: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check_circle_outline_rounded,
                                            size: 19,
                                          ),
                                    label: Text(
                                      _submitting
                                          ? 'Submitting Application…'
                                          : 'Submit Application',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
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
