import '../../../integration/worker_environment.dart';
import '../../../integration/worker_api.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show instantiateImageCodec;

import 'package:flutter/foundation.dart';

import '../../../app/slide_page_route.dart';
import 'worker_registration_mobile_otp_screen.dart';
import 'worker_registration_email_otp_screen.dart';
import 'worker_professional_details_screen.dart';
import 'worker_document_verification_screen.dart';
import 'worker_review_submit_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

const _plum = Color(0xFF460621);
const _berry = Color(0xFFB20A50);
const _muted = Color(0xFF624352);
const _ivory = Color(0xFFFFF9F5);
const _line = Color(0xFFE8C9CE);

/// Page 1 of worker registration. UI + local validation only.
///
/// Verification callbacks MUST start real backend-controlled verification.
/// [verifiedMobile] and [verifiedEmail] must be set only using trusted
/// backend results, never immediately after pressing a verification button.
class WorkerPersonalDetailsScreen extends StatefulWidget {
  const WorkerPersonalDetailsScreen({
    super.key,
    this.initialName = '',
    this.initialMobile = '',
    this.initialEmail = '',
    this.initialCity = '',
    this.verifiedMobile,
    this.verifiedEmail,
    this.profileImage,
    this.onVerifyMobile,
    this.onVerifyEmail,
    this.onChoosePhoto,
    this.onContinue,
    this.authApi,
  });

  final String initialName;
  final String initialMobile;
  final String initialEmail;
  final String initialCity;
  final String? verifiedMobile;
  final String? verifiedEmail;
  final ImageProvider? profileImage;
  final Future<void> Function(String mobile)? onVerifyMobile;
  final Future<void> Function(String email)? onVerifyEmail;
  final VoidCallback? onChoosePhoto;
  final ValueChanged<WorkerPersonalDetails>? onContinue;
  final WorkerAuthApi? authApi;

  @override
  State<WorkerPersonalDetailsScreen> createState() =>
      _WorkerPersonalDetailsScreenState();
}

class WorkerPersonalDetails {
  const WorkerPersonalDetails({
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.dateOfBirth,
    required this.cityOrArea,
    this.profilePhotoBytes,
  });

  final String fullName;
  final String mobile;
  final String email;
  final DateTime dateOfBirth;
  final String cityOrArea;
  /// Selected photo, held in memory only until a backend upload is implemented.
  final Uint8List? profilePhotoBytes;
}

class _WorkerPersonalDetailsScreenState
    extends State<WorkerPersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _city;
  DateTime? _dob;
  bool _sendingMobile = false;
  String? _demoVerifiedMobile;
  bool _sendingEmail = false;
  String? _demoVerifiedEmail;
  bool _selectingPhoto = false;
  Uint8List? _selectedPhoto;
  final ImagePicker _imagePicker = ImagePicker();
  static const int _maxPhotoBytes = 5 * 1024 * 1024;

  // Draft fields are stored in platform-backed secure storage, NOT preferences.
  // Photo bytes and demo OTP outcomes are deliberately never persisted.
  static const _draftKey = 'pinkora.worker.registration.personal.v1';
  final FlutterSecureStorage _draftStorage = const FlutterSecureStorage();
  Timer? _saveDebounce;
  Future<void> _pendingWrite = Future<void>.value();
  bool _restoringDraft = true;
  bool _draftBusy = false;
  bool _draftAvailable = false;
  String? _draftStatus;
  bool _discarding = false;

  void _onDraftChanged() {
    if (_restoringDraft || _discarding) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 550), _saveDraft);
  }

  String _makeDraftJson() => jsonEncode({
    'version': 1,
    'fullName': _name.text.trim(),
    'mobile': _mobile.text.trim(),
    'email': _email.text.trim(),
    'cityOrArea': _city.text.trim(),
    'dateOfBirth': _dob?.toIso8601String(),
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  });

  bool get _hasEnteredDraft =>
      _name.text.trim().isNotEmpty || _mobile.text.trim().isNotEmpty ||
      _email.text.trim().isNotEmpty || _city.text.trim().isNotEmpty || _dob != null;

  Future<void> _saveDraft() async {
    if (_restoringDraft || _discarding) return;
    final value = _makeDraftJson();
    final shouldSave = _hasEnteredDraft;
    // Serialize writes, including deletion, to avoid an older write arriving last.
    _pendingWrite = _pendingWrite.catchError((Object _) {}).then((_) async {
      if (shouldSave) {
        await _draftStorage.write(key: _draftKey, value: value);
      } else {
        await _draftStorage.delete(key: _draftKey);
      }
    });
    try {
      await _pendingWrite;
      if (mounted && !_discarding) {
        setState(() {
          _draftAvailable = shouldSave;
          _draftStatus = shouldSave ? 'Draft saved on this device' : null;
        });
      }
    } catch (_) {
      if (mounted && !_discarding) {
        setState(() => _draftStatus = 'Draft could not be saved on this device');
      }
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final raw = await _draftStorage.read(key: _draftKey);
      if (raw == null || !mounted) return;
      final data = jsonDecode(raw);
      if (data is! Map || data['version'] != 1) return;
      final storedMobile = (data['mobile'] as String? ?? '').trim();
      final suppliedMobile = widget.initialMobile.trim();
      // Never populate one phone number's draft into a different login context.
      if (suppliedMobile.isNotEmpty &&
          storedMobile.isNotEmpty && suppliedMobile != storedMobile) return;
      String read(String key) => data[key] is String ? data[key] as String : '';
      _name.text = read('fullName');
      _mobile.text = storedMobile.isEmpty ? suppliedMobile : storedMobile;
      _email.text = read('email');
      _city.text = read('cityOrArea');
      final date = DateTime.tryParse(read('dateOfBirth'));
      if (date != null && !date.isAfter(DateTime.now())) _dob = date;
      if (mounted) {
        setState(() {
          _draftAvailable = true;
          _draftStatus = 'Previous draft restored';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _draftStatus = 'Draft unavailable on this device');
    } finally {
      _restoringDraft = false;
    }
  }

  Future<void> _discardDraft() async {
    if (_draftBusy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard your draft?'),
        content: const Text('This clears the saved personal details and the selected photo on this device. Your OTP demos will also reset.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep draft')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() { _draftBusy = true; _discarding = true; });
    _saveDebounce?.cancel();
    _pendingWrite = _pendingWrite.catchError((Object _) {}).then((_) => _draftStorage.delete(key: _draftKey));
    try {
      await _pendingWrite;
      if (!mounted) return;
      _name.clear();
      _mobile.clear();
      _email.clear();
      _city.clear();
      setState(() {
        _dob = null;
        _selectedPhoto = null;
        _demoVerifiedMobile = null;
        _demoVerifiedEmail = null;
        _draftAvailable = false;
        _draftStatus = 'Draft discarded';
      });
    } catch (_) {
      if (mounted) _notice('Could not remove the saved draft. Please try again.');
    } finally {
      if (mounted) setState(() { _draftBusy = false; _discarding = false; });
    }
  }


  ImageProvider? get _photoPreview => _selectedPhoto != null
      ? MemoryImage(_selectedPhoto!)
      : widget.profileImage;

  Future<void> _choosePhoto() async {
    if (_selectingPhoto) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Profile photograph'),
                subtitle: Text('Choose a clear photo of your face'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || source == null) return;
    setState(() => _selectingPhoto = true);
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.lengthInBytes > _maxPhotoBytes) {
        if (mounted) _notice('Choose an image smaller than 5 MB.');
        return;
      }
      // Validate that the selected bytes can actually be decoded as an image.
      try {
        final codec = await instantiateImageCodec(bytes);
        codec.dispose();
      } catch (_) {
        if (mounted) _notice('Please choose a valid image file.');
        return;
      }
      if (!mounted) return;
      setState(() => _selectedPhoto = bytes);
    } catch (_) {
      if (mounted) _notice('Could not access photos. Check permissions and try again.');
    } finally {
      if (mounted) setState(() => _selectingPhoto = false);
    }
  }


  bool get _mobileVerified =>
      (widget.verifiedMobile != null && widget.verifiedMobile == _mobile.text.trim()) ||
      (widget.initialMobile.isNotEmpty && widget.initialMobile == _mobile.text.trim()) ||
      _demoMobileMatches;

  bool get _demoMobileMatches =>
      WorkerEnvironment.developmentPreview && _demoVerifiedMobile == _mobile.text.trim();

  bool get _demoEmailMatches =>
      WorkerEnvironment.developmentPreview &&
      _demoVerifiedEmail != null &&
      _demoVerifiedEmail!.toLowerCase() == _email.text.trim().toLowerCase();

  bool get _emailVerified =>
      widget.verifiedEmail != null &&
      widget.verifiedEmail!.toLowerCase() ==
          _email.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _mobile = TextEditingController(text: widget.initialMobile);
    _email = TextEditingController(text: widget.initialEmail);
    _city = TextEditingController(text: widget.initialCity);
    for (final controller in [_name, _mobile, _email, _city]) {
      controller.addListener(_onDraftChanged);
    }
    _restoreDraft();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // Flush the latest field snapshot when navigating away.
    if (!_restoringDraft && !_discarding) unawaited(_saveDraft());
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _city.dispose();
    super.dispose();
  }

  bool _adult(DateTime birth) {
    final today = DateUtils.dateOnly(DateTime.now());
    var age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return age >= 18;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1940),
      lastDate: now,
      initialDate: _dob ?? DateTime(now.year - 22),
      helpText: 'Select your date of birth',
    );
    if (!mounted || selected == null) return;
    setState(() => _dob = selected);
    _onDraftChanged();
  }

  void _notice(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _verifyMobile() async {
    final value = _mobile.text.trim();
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
      _notice('Enter a valid 10-digit Indian mobile number first.');
      return;
    }
    final callback = widget.onVerifyMobile;
    if (callback == null) {
      if (!WorkerEnvironment.developmentPreview) {
        _notice('Mobile OTP verification is not connected yet.');
        return;
      }
      final result = await Navigator.of(context).push<bool>(
        SlidePageRoute<bool>(
          page: WorkerRegistrationMobileOtpScreen(mobile: value),
        ),
      );
      if (!mounted) return;
      if (result == true && _mobile.text.trim() == value) {
        setState(() => _demoVerifiedMobile = value);
        _notice('Demo code accepted. Real mobile verification is still required.');
      }
      return;
    }
    setState(() => _sendingMobile = true);
    try {
      await callback(value);
    } catch (_) {
      if (mounted) _notice('Could not start mobile verification. Try again.');
    } finally {
      if (mounted) setState(() => _sendingMobile = false);
    }
  }

  Future<void> _verifyEmail() async {
    final value = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      _notice('Enter a valid email address first.');
      return;
    }
    final callback = widget.onVerifyEmail;
    if (callback == null) {
      if (!WorkerEnvironment.developmentPreview) {
        _notice('Email verification is not connected yet.');
        return;
      }
      final result = await Navigator.of(context).push<bool>(
        SlidePageRoute<bool>(
          page: WorkerRegistrationEmailOtpScreen(email: value),
        ),
      );
      if (!mounted) return;
      if (result == true &&
          _email.text.trim().toLowerCase() == value.toLowerCase()) {
        setState(() => _demoVerifiedEmail = value);
        _notice('Demo email code accepted. Real email verification is still required.');
      }
      return;
    }
    setState(() => _sendingEmail = true);
    try {
      await callback(value);
    } catch (_) {
      if (mounted) _notice('Could not start email verification. Try again.');
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  // Development-only UI preview. Never sends or submits registration data.
  // Demo codes do not change verifiedMobile/verifiedEmail or onContinue.
  Future<void> _previewProfessionalDetails() async {
    if (!WorkerEnvironment.developmentPreview) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dob == null || !_adult(_dob!)) {
      _notice('Workers must be at least 18 years old.');
      return;
    }
    if (!_demoMobileMatches || !_demoEmailMatches) {
      _notice('Complete both demo OTP screens before previewing Step 2.');
      return;
    }
    // All three previous routes stay mounted during review. This is a UI-only
    // debug preview, never a server-authorized registration flow.
    final navigation = Navigator.of(context);
    await navigation.push<void>(
      SlidePageRoute<void>(
        page: WorkerProfessionalDetailsScreen(
          onContinue: (professional) {
            navigation.push<void>(
              SlidePageRoute<void>(
                page: WorkerDocumentVerificationScreen(
                  onContinue: (documents) {
                    navigation.push<void>(
                      SlidePageRoute<void>(
                        page: WorkerReviewSubmitScreen(
                          fullName: _name.text.trim(),
                          mobile: _mobile.text.trim(),
                          email: _email.text.trim(),
                          dateOfBirth: _dob!,
                          cityOrArea: _city.text.trim(),
                          profilePhotoBytes: _selectedPhoto,
                          primaryCategory: professional.primaryCategory,
                          services: professional.services,
                          yearsOfExperience: professional.yearsOfExperience,
                          workMode: professional.workMode,
                          travelRadiusKm: professional.travelRadiusKm,
                          languages: professional.languages,
                          about: professional.about,
                          certificateDetails: professional.certificateDetails,
                          identityType: documents.identityType,
                          identityFileFormat: documents.identityDocument.extension,
                          professionalCertificateFormat:
                              documents.professionalCertificate?.extension,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dob == null || !_adult(_dob!)) {
      _notice('Workers must be at least 18 years old.');
      return;
    }
    if (!_mobileVerified) {
      _notice('Verify your mobile number to continue.');
      return;
    }
    final details = WorkerPersonalDetails(
      fullName: _name.text.trim(),
      mobile: _mobile.text.trim(),
      email: _email.text.trim(),
      dateOfBirth: _dob!,
      cityOrArea: _city.text.trim(),
      profilePhotoBytes: _selectedPhoto,
    );
    final callback = widget.onContinue;
    if (callback != null) {
      callback(details);
      return;
    }
    Navigator.of(context).push(
      SlidePageRoute<void>(
        page: WorkerProfessionalDetailsScreen(
          authApi: widget.authApi,
          personalDetails: details,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8C737E), fontSize: 14),
        prefixIcon: Icon(icon, color: _muted, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.96),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _berry, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _plum)),
      );

  Widget _verifiedMarker(bool verified, VoidCallback onVerify,
      {required bool loading}) {
    if (verified) {
      return const Padding(
        padding: EdgeInsets.only(right: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, size: 17, color: Color(0xFF208454)),
          SizedBox(width: 4),
          Text('Verified',
              style: TextStyle(fontSize: 11, color: Color(0xFF208454),
                  fontWeight: FontWeight.w700)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: TextButton(
        onPressed: loading ? null : onVerify,
        style: TextButton.styleFrom(
          foregroundColor: _berry,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(54, 40),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Verify',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ivory,
      appBar: AppBar(
        backgroundColor: _ivory,
        foregroundColor: _plum,
        elevation: 0,
        title: const Text('Join Hi Beauty',
            style: TextStyle(fontFamily: 'Georgia',
                fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('STEP 1 OF 4',
                                style: TextStyle(color: _berry, fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1))),
                            Text('25% complete',
                                style: TextStyle(color: _muted.withValues(alpha: .9),
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: const LinearProgressIndicator(
                            minHeight: 5,
                            value: .25,
                            backgroundColor: Color(0xFFF3DFE5),
                            color: _berry,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: Text(
                            _draftStatus ?? 'Your details are saved locally as you type',
                            style: const TextStyle(fontSize: 11, color: _muted),
                          )),
                          TextButton.icon(
                            onPressed: (_draftBusy || !_draftAvailable) ? null : _discardDraft,
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const Text('Discard', style: TextStyle(fontSize: 11)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        const Text('Tell us about yourself',
                            style: TextStyle(fontFamily: 'Georgia',
                                fontSize: 23, fontWeight: FontWeight.w700,
                                color: _plum)),
                        const SizedBox(height: 6),
                        const Text('Create your professional profile to apply as a Hi Beauty partner.',
                            style: TextStyle(fontSize: 13.5,
                                height: 1.45, color: _muted)),
                        const SizedBox(height: 14),
                        _label('Full name *'),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _fieldDecoration('Enter name as on your ID', Icons.person_outline),
                          validator: (v) => (v?.trim().length ?? 0) < 2
                              ? 'Enter your full name.' : null,
                        ),
                        const SizedBox(height: 17),
                        _label('Mobile number *'),
                        TextFormField(
                          controller: _mobile,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10)],
                          onChanged: (_) => setState(() {}),
                          decoration: _fieldDecoration('10-digit mobile number', Icons.phone_outlined)
                              .copyWith(prefixText: '+91  ',
                                prefixStyle: const TextStyle(color: _plum,
                                    fontWeight: FontWeight.w700),
                                suffixIconConstraints: const BoxConstraints(minWidth: 62),
                                suffixIcon: _demoMobileMatches && !_mobileVerified
                                    ? const Tooltip(
                                        message: 'Demo only; not identity verified',
                                        child: Padding(
                                          padding: EdgeInsets.only(right: 9),
                                          child: Center(
                                            widthFactor: 1,
                                            child: Text('Demo ✓', style: TextStyle(
                                              color: _berry, fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                        ),
                                      )
                                    : _verifiedMarker(_mobileVerified,
                                        _verifyMobile, loading: _sendingMobile)),
                          validator: (v) => RegExp(r'^[6-9][0-9]{9}$').hasMatch(v?.trim() ?? '')
                              ? null : 'Enter a valid Indian mobile number.',
                        ),
                        const SizedBox(height: 17),
                        _label('Email address (Optional)'),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: _fieldDecoration('you@example.com', Icons.mail_outline)
                              .copyWith(suffixIconConstraints: const BoxConstraints(minWidth: 62),
                                suffixIcon: _demoEmailMatches && !_emailVerified
                                     ? const Tooltip(
                                         message: 'Demo only; email ownership not verified',
                                         child: Padding(
                                           padding: EdgeInsets.only(right: 9),
                                           child: Center(
                                             widthFactor: 1,
                                             child: Text('Demo ✓',
                                               style: TextStyle(
                                                 color: _berry,
                                                 fontWeight: FontWeight.bold,
                                                 fontSize: 11,
                                               ),
                                             ),
                                           ),
                                         ),
                                       )
                                     : _verifiedMarker(_emailVerified,
                                         _verifyEmail, loading: _sendingEmail)),
                          validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v?.trim() ?? '')
                              ? null : 'Enter a valid email address.',
                        ),
                        const SizedBox(height: 8),
                        const Row(children: [
                          Icon(Icons.lock_outline_rounded, size: 14, color: _muted),
                          SizedBox(width: 5),
                          Expanded(child: Text('Mobile number is verified for partner registration security.',
                              style: TextStyle(color: _muted, fontSize: 11.5))),
                        ]),
                        const SizedBox(height: 18),
                        _label('Date of birth *'),
                        InkWell(
                          onTap: _pickDob,
                          borderRadius: BorderRadius.circular(13),
                          child: InputDecorator(
                            decoration: _fieldDecoration('Select date of birth', Icons.calendar_today_outlined),
                            child: Text(_dob == null ? 'Select date of birth'
                              : MaterialLocalizations.of(context).formatMediumDate(_dob!),
                              style: TextStyle(fontSize: 14,
                                  color: _dob == null ? _muted : _plum)),
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text('You must be 18 or older to apply.',
                            style: TextStyle(fontSize: 11.5, color: _muted)),
                        const SizedBox(height: 17),
                        _label('City / residential area *'),
                        TextFormField(
                          controller: _city,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          decoration: _fieldDecoration('Enter your city and area', Icons.location_on_outlined),
                          validator: (v) => (v?.trim().length ?? 0) < 2
                              ? 'Enter your city or residential area.' : null,
                        ),
                        const SizedBox(height: 19),
                        _label('Profile photograph'),
                         Row(children: [
                           CircleAvatar(
                             radius: 27,
                             backgroundColor: const Color(0xFFF4DDE5),
                             foregroundImage: _photoPreview,
                             child: _photoPreview == null
                                 ? const Icon(Icons.person_outline, color: _berry, size: 31)
                                 : null,
                           ),
                           const SizedBox(width: 14),
                           Expanded(child: OutlinedButton.icon(
                             onPressed: _selectingPhoto ? null : _choosePhoto,
                             icon: _selectingPhoto
                                 ? const SizedBox.square(
                                     dimension: 17,
                                     child: CircularProgressIndicator(strokeWidth: 2),
                                   )
                                 : const Icon(Icons.add_a_photo_outlined, size: 18),
                             label: Text(_selectedPhoto == null && widget.profileImage == null
                                 ? 'Add profile photo' : 'Change photo'),
                             style: OutlinedButton.styleFrom(
                               foregroundColor: _berry,
                               side: const BorderSide(color: _line),
                               minimumSize: const Size(0, 40),
                             ),
                           )),
                         ]),                        const SizedBox(height: 10),
                        const Text('Use a clear, recent photo. Identity documents are collected in Step 3.',
                            style: TextStyle(fontSize: 11.5, color: _muted)),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 9),
                    decoration: const BoxDecoration(
                      color: _ivory,
                      border: Border(top: BorderSide(color: _line)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD41361), Color(0xFF750034)]),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: FilledButton(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [Text('Continue',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              SizedBox(width: 10), Icon(Icons.arrow_forward_rounded)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (WorkerEnvironment.developmentPreview) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: OutlinedButton.icon(
                        onPressed: _previewProfessionalDetails,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Preview Step 2 — development only'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _berry,
                          side: const BorderSide(color: _line),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
