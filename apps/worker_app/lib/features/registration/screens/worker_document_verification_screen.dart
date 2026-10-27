import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../app/slide_page_route.dart';
import '../../../integration/worker_api.dart';
import 'worker_personal_details_screen.dart';
import 'worker_professional_details_screen.dart';
import 'worker_review_submit_screen.dart';

// Pinkora Worker Registration - Page 3 of 4.
// LOCAL UI PREVIEW ONLY. Documents are NOT uploaded, saved to device storage,
// sent to an administrator, or checked for authenticity by this screen.
// Never describe selected files as verified or approved.

const _plum = Color(0xFF460621);
const _berry = Color(0xFFB20A50);
const _muted = Color(0xFF624352);
const _ivory = Color(0xFFFFF9F5);
const _line = Color(0xFFE8C9CE);

class WorkerSelectedDocument {
  const WorkerSelectedDocument({
    required this.name,
    required this.bytes,
    required this.extension,
  });

  final String name;
  final Uint8List bytes;
  final String extension;
  int get sizeBytes => bytes.lengthInBytes;
  bool get isImage => extension == 'jpg' || extension == 'jpeg' || extension == 'png';
}

class WorkerDocumentVerificationDetails {
  const WorkerDocumentVerificationDetails({
    required this.identityType,
    required this.identityDocument,
    this.professionalCertificate,
    required this.consentToReview,
  });

  final String identityType;
  final WorkerSelectedDocument identityDocument;
  final WorkerSelectedDocument? professionalCertificate;
  final bool consentToReview;
}

class WorkerDocumentVerificationScreen extends StatefulWidget {
  const WorkerDocumentVerificationScreen({
    super.key,
    this.onContinue,
    this.authApi,
    this.personalDetails,
    this.professionalDetails,
    this.catalogServices = const [],
    this.catalogAreas = const [],
  });

  final ValueChanged<WorkerDocumentVerificationDetails>? onContinue;
  final WorkerAuthApi? authApi;
  final WorkerPersonalDetails? personalDetails;
  final WorkerProfessionalDetails? professionalDetails;
  final List<Map<String, dynamic>> catalogServices;
  final List<Map<String, dynamic>> catalogAreas;

  @override
  State<WorkerDocumentVerificationScreen> createState() =>
      _WorkerDocumentVerificationScreenState();
}

class _WorkerDocumentVerificationScreenState
    extends State<WorkerDocumentVerificationScreen> {
  static const int _maxFileBytes = 5 * 1024 * 1024;
  static const _types = <String>[
    'Aadhaar (masked copy)',
    'Driving licence',
    'Voter ID',
    'Passport',
    'PAN card',
  ];

  String? _identityType;
  WorkerSelectedDocument? _identity;
  WorkerSelectedDocument? _certificate;
  bool _consent = false;
  bool _busy = false;
  String? _identityError;
  String? _consentError;

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
Future<WorkerSelectedDocument?> _selectDocument() async {
  try {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (file == null) return null;

    final ext = (file.extension ?? '').toLowerCase();

    if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext)) {
      _notice('Choose a JPG, PNG or PDF file.');
      return null;
    }

    // Check size before loading the entire document into memory.
    final fileSize = await file.length();

    if (fileSize == null ||
        fileSize <= 0 ||
        fileSize > _maxFileBytes) {
      _notice('Choose a valid file smaller than 5 MB.');
      return null;
    }

    final data = await file.readAsBytes();

    if (data.isEmpty || data.lengthInBytes > _maxFileBytes) {
      _notice('File must be smaller than 5 MB.');
      return null;
    }

    // Basic file signature validation.
    final pdf = data.length >= 5 &&
        data[0] == 0x25 &&
        data[1] == 0x50 &&
        data[2] == 0x44 &&
        data[3] == 0x46 &&
        data[4] == 0x2D;

    final jpg = data.length >= 3 &&
        data[0] == 0xFF &&
        data[1] == 0xD8 &&
        data[2] == 0xFF;

    final png = data.length >= 8 &&
        data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47 &&
        data[4] == 0x0D &&
        data[5] == 0x0A &&
        data[6] == 0x1A &&
        data[7] == 0x0A;

    final validFormat =
        (ext == 'pdf' && pdf) ||
        ((ext == 'jpg' || ext == 'jpeg') && jpg) ||
        (ext == 'png' && png);

    if (!validFormat) {
      _notice('This file does not match its declared format.');
      return null;
    }

    return WorkerSelectedDocument(
      name: file.name,
      bytes: data,
      extension: ext,
    );
  } catch (_) {
    _notice('Unable to open the selected file. Please try again.');
    return null;
  }
}

  Future<void> _pick(String slot) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final selected = await _selectDocument();
      if (!mounted || selected == null) return;
      setState(() {
        switch (slot) {
          case 'identity':
            _identity = selected;
            _identityError = null;
            break;
          case 'certificate':
            _certificate = selected;
            break;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(String slot) {
    setState(() {
      switch (slot) {
        case 'identity':
          _identity = null;
          break;
        case 'certificate':
          _certificate = null;
          break;
      }
    });
  }

  void _preview(WorkerSelectedDocument file) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _plum)),
              const SizedBox(height: 12),
              if (file.isImage)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .62),
                  child: Image.memory(file.bytes, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('Image preview unavailable. Choose another file.'),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 35),
                  child: Column(children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 56, color: _berry),
                    SizedBox(height: 8),
                    Text('PDF selected. In-app PDF rendering is not available in this preview.',
                      textAlign: TextAlign.center, style: TextStyle(color: _muted)),
                  ]),
                ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => Navigator.pop(context),
                child: const Text('Close preview')),
            ],
          ),
        ),
      ),
    );
  }

  void _continue() {
    setState(() {
      _identityError = _identityType == null
          ? 'Select an identity document type.'
          : _identity == null ? 'Upload your identity proof to continue.' : null;
      _consentError = _consent ? null : 'Consent is required to proceed.';
    });
    if (_identityError != null || _consentError != null) {
      _notice('Complete the required identity proof and consent.');
      return;
    }
    final details = WorkerDocumentVerificationDetails(
      identityType: _identityType!,
      identityDocument: _identity!,
      professionalCertificate: _certificate,
      consentToReview: _consent,
    );
    final callback = widget.onContinue;
    if (callback != null) {
      callback(details);
      return;
    }
    final personal = widget.personalDetails;
    final professional = widget.professionalDetails;
    if (personal == null || professional == null) {
      _notice('Registration details missing. Please restart from Step 1.');
      return;
    }
    Navigator.of(context).push(
      SlidePageRoute<void>(
        page: WorkerReviewSubmitScreen(
          authApi: widget.authApi,
          fullName: personal.fullName,
          mobile: personal.mobile,
          email: personal.email,
          dateOfBirth: personal.dateOfBirth,
          cityOrArea: personal.cityOrArea,
          profilePhotoBytes: personal.profilePhotoBytes,
          primaryCategory: professional.primaryCategory,
          services: professional.services,
          yearsOfExperience: professional.yearsOfExperience,
          workMode: professional.workMode,
          travelRadiusKm: professional.travelRadiusKm,
          languages: professional.languages,
          about: professional.about,
          certificateDetails: professional.certificateDetails,
          identityType: details.identityType,
          identityDocument: details.identityDocument,
          certificateDocument: details.professionalCertificate,
          identityFileFormat: details.identityDocument.extension,
          professionalCertificateFormat: details.professionalCertificate?.extension,
          catalogServices: widget.catalogServices,
          catalogAreas: widget.catalogAreas,
        ),
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle, {bool required = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(child: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _plum))),
        if (required) const Text(' *', style: TextStyle(color: _berry, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4)),
    ]);
  }

  Widget _uploadCard({
    required String slot,
    required String title,
    required String emptyHint,
    required WorkerSelectedDocument? file,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: file == null ? _line : const Color(0xFFB6909F)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(11),
      child: file == null
          ? InkWell(
              onTap: _busy ? null : () => _pick(slot),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFF9E6EC),
                      borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.cloud_upload_outlined, color: _berry, size: 25)),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(color: _plum,
                    fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(emptyHint, textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 11.5)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(slot),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Choose file'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _berry,
                      side: const BorderSide(color: _line)),
                  ),
                ]),
              ),
            )
          : Column(children: [
              Row(children: [
                Container(width: 45, height: 45,
                  decoration: BoxDecoration(color: const Color(0xFFF9E6EC),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(file.isImage ? Icons.image_outlined
                    : Icons.picture_as_pdf_outlined, color: _berry)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _plum, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Text('${(file.sizeBytes / 1024).toStringAsFixed(0)} KB • Selected, not verified',
                    style: const TextStyle(color: _muted, fontSize: 11.5)),
                ])),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                TextButton.icon(onPressed: () => _preview(file),
                    icon: const Icon(Icons.visibility_outlined, size: 17), label: const Text('Preview')),
                const Spacer(),
                TextButton(onPressed: _busy ? null : () => _pick(slot), child: const Text('Replace')),
                IconButton(tooltip: 'Remove file', onPressed: () => _remove(slot),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20)),
              ]),
            ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ivory,
      appBar: AppBar(
        title: const Text('Join Hi Beauty',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 20,
            fontWeight: FontWeight.w700, color: _plum)),
        centerTitle: true,
        backgroundColor: _ivory,
        foregroundColor: _plum,
        surfaceTintColor: _ivory,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Expanded(child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                children: [
                  const Row(children: [
                    Expanded(child: Text('STEP 3 OF 4',
                      style: TextStyle(color: _berry, fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 1.1))),
                    Text('75% complete', style: TextStyle(color: _muted, fontSize: 12)),
                  ]),
                  const SizedBox(height: 9),
                  ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(
                      value: .75, minHeight: 5,
                      backgroundColor: Color(0xFFF3DFE5), color: _berry)),
                  const SizedBox(height: 13),
                  const Text('Your documents, securely',
                    style: TextStyle(fontFamily: 'Georgia', color: _plum,
                      fontWeight: FontWeight.w700, fontSize: 22, height: 1.15)),
                  const SizedBox(height: 7),
                  const Text('Share your identity proof for manual review by the Hi Beauty team.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.3)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: const Color(0xFFF8E9EF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line)),
                    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.shield_outlined, color: _berry, size: 20),
                      SizedBox(width: 9),
                      Expanded(child: Text(
                        'Manual review only • No documents are uploaded in this preview. '
                        'Your application is not approved or verified yet.',
                        style: TextStyle(color: _plum, fontSize: 12, height: 1.4))),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  _sectionHeading('Identity proof',
                    'Required • Choose one government-issued ID. A clear, readable document is needed.',
                    required: true),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _identityType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.badge_outlined, color: _muted),
                      hintText: 'Select identity proof type',
                      filled: true, fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: _identityError == null ? _line : Colors.redAccent)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    items: _types.map((name) => DropdownMenuItem(value: name,
                      child: Text(name))).toList(),
                    onChanged: (value) => setState(() {
                      if (value != _identityType) _identity = null;
                      _identityType = value;
                      _identityError = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (_identityType == 'Aadhaar (masked copy)') ...[
                    const SizedBox(height: 10),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.privacy_tip_outlined, color: _berry, size: 16),
                        SizedBox(width: 7),
                        Expanded(child: Text(
                          'Use a masked Aadhaar copy. Hide the first eight digits and show only the last four. '
                          'Other accepted ID types remain available.',
                          style: TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  _uploadCard(slot: 'identity', title: 'Add identity document',
                    emptyHint: 'JPG, PNG or PDF • Maximum 5 MB', file: _identity),
                  if (_identityError != null) ...[
                    const SizedBox(height: 7),
                    Text(_identityError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 25),
                  _sectionHeading('Professional certificate',
                    'Optional • Upload training or beauty certification if available.'),
                  const SizedBox(height: 12),
                  _uploadCard(slot: 'certificate', title: 'Add certificate',
                    emptyHint: 'JPG, PNG or PDF • Maximum 5 MB', file: _certificate),
                  const SizedBox(height: 22),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: (v) => setState(() { _consent = v ?? false; _consentError = null; }),
                    activeColor: _berry,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('I agree to share these documents with Hi Beauty for worker application review.',
                      style: TextStyle(color: _plum, fontSize: 12.5, height: 1.35)),
                    subtitle: const Text('Consent is for the planned review process. No upload occurs in this preview.',
                      style: TextStyle(color: _muted, fontSize: 11.5)),
                  ),
                  if (_consentError != null)
                    Text(_consentError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              )),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
                decoration: const BoxDecoration(color: _ivory,
                  border: Border(top: BorderSide(color: _line))),
                child: Row(children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _plum,
                      side: const BorderSide(color: _line),
                      minimumSize: const Size(82, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: SizedBox(height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFD41361), Color(0xFF750034)]),
                        borderRadius: BorderRadius.circular(26)),
                      child: FilledButton(
                        onPressed: _busy ? null : _continue,
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                          SizedBox(width: 7),
                          Icon(Icons.arrow_forward_rounded, size: 19),
                        ]),
                      ),
                    ),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
