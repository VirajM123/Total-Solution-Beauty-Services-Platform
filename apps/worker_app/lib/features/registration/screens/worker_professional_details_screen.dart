import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


import '../../../app/slide_page_route.dart';
import '../../home/worker_profile_data.dart';
import 'worker_document_verification_screen.dart';
import '../../../integration/worker_api.dart';
import '../../../integration/worker_mobile_auth_api.dart';
import 'worker_personal_details_screen.dart';

// Pinkora Worker Registration — Step 2 of 4.
// UI-only: no backend writes, approvals or verification assertions.
// Do not attach this screen to a production registration submission until
// server-attested mobile and email verification are implemented.

const _plum = Color(0xFF460621);
const _berry = Color(0xFFB20A50);
const _muted = Color(0xFF624352);
const _ivory = Color(0xFFFFF9F5);
const _line = Color(0xFFE8C9CE);

class WorkerProfessionalDetails {
  const WorkerProfessionalDetails({
    required this.primaryCategory,
    required this.services,
    required this.yearsOfExperience,
    required this.workMode,
    required this.travelRadiusKm,
    required this.languages,
    required this.about,
    required this.certificateDetails,
  });

  final String primaryCategory;
  final List<String> services;
  final int yearsOfExperience;
  final String workMode;
  final int travelRadiusKm;
  final List<String> languages;
  final String about;
  final String certificateDetails;
}

class WorkerProfessionalDetailsScreen extends StatefulWidget {
  const WorkerProfessionalDetailsScreen({
    super.key,
    this.onContinue,
    this.authApi,
    this.personalDetails,
  });

  final ValueChanged<WorkerProfessionalDetails>? onContinue;
  final WorkerAuthApi? authApi;
  final WorkerPersonalDetails? personalDetails;

  @override
  State<WorkerProfessionalDetailsScreen> createState() =>
      _WorkerProfessionalDetailsScreenState();
}

class _WorkerProfessionalDetailsScreenState
    extends State<WorkerProfessionalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _catalogServices = [];
  List<Map<String, dynamic>> _catalogAreas = [];
  bool _loadingCatalog = false;



  Future<void> _fetchCatalog() async {
    final api = widget.authApi ?? WorkerMobileAuthApi();
    if (mounted) setState(() => _loadingCatalog = true);
    try {
      final svcs = await api.fetchServices();
      final areas = await api.fetchServiceAreas();
      if (!mounted) return;
      setState(() {
        _catalogServices = svcs;
        _catalogAreas = areas;
      });
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }
  final _about = TextEditingController();
  final _certificate = TextEditingController();

  static const _workModes = <String>['Home visits', 'Salon-based', 'Both'];
  static const _languages = <String>[
    'Hindi',
    'English',
    'Marathi',
    'Gujarati',
    'Kannada',
    'Other',
  ];

  String? _category;
  final Set<String> _services = {};
  final Set<String> _spokenLanguages = {};
  int? _years;
  String _workMode = 'Home visits';
  double _radiusKm = 10;

  // UI draft only; this shared-device key must be scoped to a verified worker
  // account before production use. No OTP or identity verification is saved.
  static const _draftKey = 'pinkora.worker.registration.professional.v1';
  final FlutterSecureStorage _draftStorage = const FlutterSecureStorage();
  Timer? _saveDebounce;
  Future<void> _pendingWrite = Future<void>.value();
  bool _restoring = true;
  bool _discarding = false;
  bool _draftBusy = false;
  bool _draftAvailable = false;
  String? _draftStatus;

  bool get _hasDraft =>
      _category != null ||
      _services.isNotEmpty ||
      _years != null ||
      _workMode != 'Home visits' ||
      _radiusKm != 10 ||
      _spokenLanguages.isNotEmpty ||
      _about.text.trim().isNotEmpty ||
      _certificate.text.trim().isNotEmpty;

  String _draftJson() => jsonEncode({
    'version': 1,
    'category': _category,
    'services': _services.toList(),
    'years': _years,
    'workMode': _workMode,
    'radiusKm': _radiusKm,
    'languages': _spokenLanguages.toList(),
    'about': _about.text,
    'certificate': _certificate.text,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  });

  void _onDraftChanged() {
    if (_restoring || _discarding) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 550), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_restoring || _discarding) return;
    // Capture values before the widget is disposed.
    final hasDraft = _hasDraft;
    final serialized = _draftJson();
    _pendingWrite = _pendingWrite.catchError((Object _) {}).then((_) async {
      if (hasDraft) {
        await _draftStorage.write(key: _draftKey, value: serialized);
      } else {
        await _draftStorage.delete(key: _draftKey);
      }
    });
    try {
      await _pendingWrite;
      if (mounted && !_discarding) {
        setState(() {
          _draftAvailable = hasDraft;
          _draftStatus = hasDraft ? 'Draft saved on this device' : null;
        });
      }
    } catch (_) {
      if (mounted && !_discarding) {
        setState(() => _draftStatus = 'Could not save draft on this device');
      }
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final raw = await _draftStorage.read(key: _draftKey);
      if (!mounted || raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['version'] != 1) return;
      final cat = decoded['category'];
      final selectedCategory =
          cat is String && workerServiceOptions.containsKey(cat) ? cat : null;
      final validServices =
          workerServiceOptions[selectedCategory] ?? const <String>[];
      final rawServices = decoded['services'];
      final rawLanguages = decoded['languages'];
      final rawYears = decoded['years'];
      final rawMode = decoded['workMode'];
      final rawRadius = decoded['radiusKm'];
      final allowedYears = {0, 1, 2, 3, 4, 5, 7, 10, 15, 20};
      setState(() {
        _category = selectedCategory;
        _services
          ..clear()
          ..addAll(
            rawServices is List
                ? rawServices.whereType<String>().where(validServices.contains)
                : const <String>[],
          );
        _spokenLanguages
          ..clear()
          ..addAll(
            rawLanguages is List
                ? rawLanguages.whereType<String>().where(_languages.contains)
                : const <String>[],
          );
        _years = rawYears is int && allowedYears.contains(rawYears)
            ? rawYears
            : null;
        _workMode = rawMode is String && _workModes.contains(rawMode)
            ? rawMode
            : 'Home visits';
        _radiusKm = rawRadius is num && rawRadius >= 5 && rawRadius <= 30
            ? (rawRadius / 5).round().clamp(1, 6) * 5.0
            : 10;
        _about.text = decoded['about'] is String
            ? (decoded['about'] as String).substring(
                0,
                (decoded['about'] as String).length.clamp(0, 300),
              )
            : '';
        _certificate.text = decoded['certificate'] is String
            ? (decoded['certificate'] as String).substring(
                0,
                (decoded['certificate'] as String).length.clamp(0, 120),
              )
            : '';
        _draftAvailable = true;
        _draftStatus = 'Previous draft restored';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _draftStatus = 'Draft unavailable on this device');
      }
    } finally {
      _restoring = false;
    }
  }

  Future<void> _discardDraft() async {
    if (_draftBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard professional details?'),
        content: const Text(
          'This clears saved Step 2 selections and text on this device. Step 1 will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep draft'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _draftBusy = true;
      _discarding = true;
    });
    _saveDebounce?.cancel();
    _pendingWrite = _pendingWrite
        .catchError((Object _) {})
        .then((_) => _draftStorage.delete(key: _draftKey));
    try {
      await _pendingWrite;
      if (!mounted) return;
      setState(() {
        _category = null;
        _services.clear();
        _spokenLanguages.clear();
        _years = null;
        _workMode = 'Home visits';
        _radiusKm = 10;
        _about.clear();
        _certificate.clear();
        _draftAvailable = false;
        _draftStatus = 'Draft discarded';
      });
    } catch (_) {
      if (mounted) _notice('Could not discard the saved draft. Try again.');
    } finally {
      if (mounted) {
        setState(() {
          _draftBusy = false;
          _discarding = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
    _about.addListener(_onDraftChanged);
    _certificate.addListener(_onDraftChanged);
    _restoreDraft();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (!_restoring && !_discarding) unawaited(_saveDraft());
    _about.dispose();
    _certificate.dispose();
    super.dispose();
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_category == null) {
      _notice('Select your primary beauty category.');
      return;
    }
    if (_services.isEmpty) {
      _notice('Choose at least one service you offer.');
      return;
    }
    if (_years == null) {
      _notice('Select your years of experience.');
      return;
    }
    if (_spokenLanguages.isEmpty) {
      _notice('Select at least one language you speak.');
      return;
    }

    final details = WorkerProfessionalDetails(
      primaryCategory: _category!,
      services: List.unmodifiable(_services),
      yearsOfExperience: _years!,
      workMode: _workMode,
      travelRadiusKm: _radiusKm.round(),
      languages: List.unmodifiable(_spokenLanguages),
      about: _about.text.trim(),
      certificateDetails: _certificate.text.trim(),
    );
    final callback = widget.onContinue;
    if (callback != null) {
      callback(details);
      return;
    }

    Navigator.of(context).push(
      SlidePageRoute<void>(
        page: WorkerDocumentVerificationScreen(
          authApi: widget.authApi,
          personalDetails: widget.personalDetails,
          professionalDetails: details,
          catalogServices: _catalogServices,
          catalogAreas: _catalogAreas,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _plum,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ],
    ),
  );

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF8C737E), fontSize: 13),
    prefixIcon: Icon(icon, color: _muted, size: 20),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: _line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: _berry, width: 1.6),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
  );

  @override
  Widget build(BuildContext context) {
    final homeVisits = _workMode != 'Salon-based';
    final catalogCategoryNames = _catalogServices
        .map((s) => s['category'] is Map ? (s['category']['name'] as String? ?? '') : '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    final categoryOptions = {
      ...catalogCategoryNames,
      ...workerServiceOptions.keys,
      if (_category != null) _category!,
    }.toList();

    final List<String> services;
    if (_category == null) {
      services = const <String>[];
    } else {
      final matchedCatalogServices = _catalogServices
          .where((s) => s['category'] is Map && s['category']['name'] == _category)
          .map((s) => s['name'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (matchedCatalogServices.isNotEmpty) {
        services = matchedCatalogServices;
      } else {
        services = workerServiceOptions[_category] ?? const <String>[];
      }
    }

    return Scaffold(
      backgroundColor: _ivory,
      appBar: AppBar(
        title: const Text(
          'Join Hi Beauty',
          style: TextStyle(
            fontFamily: 'Georgia',
            color: _plum,
            fontSize: 20,
            fontWeight: FontWeight.w700,
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        Row(
                          children: const [
                            Expanded(
                              child: Text(
                                'STEP 2 OF 4',
                                style: TextStyle(
                                  color: _berry,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            Text(
                              '50% complete',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: const LinearProgressIndicator(
                            value: .5,
                            minHeight: 5,
                            backgroundColor: Color(0xFFF3DFE5),
                            color: _berry,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _draftStatus ??
                                    'Professional details save locally as you type',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: (_draftBusy || !_draftAvailable)
                                  ? null
                                  : _discardDraft,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Discard',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your expertise, your way',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            height: 1.15,
                            color: _plum,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tell us which beauty services you love providing.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionTitle(
                          'Primary expertise *',
                          hint:
                              'Choose the category that best describes your work.',
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: _decoration(
                            'Select a category',
                            Icons.auto_awesome_outlined,
                          ),
                          items: categoryOptions
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            _category = value;
                            _services.clear();
                            _onDraftChanged();
                          }),
                        ),
                        const SizedBox(height: 14),
                        _sectionTitle(
                          'Services you provide *',
                          hint:
                              'Select all services you can confidently perform.',
                        ),
                        if (_category == null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8EAEC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _line),
                            ),
                            child: const Text(
                              'Select your primary expertise to see services.',
                              style: TextStyle(color: _muted, fontSize: 13),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: services.map((name) {
                              final selected = _services.contains(name);
                              return FilterChip(
                                label: Text(name),
                                selected: selected,
                                showCheckmark: true,
                                selectedColor: const Color(0xFFF7D9E6),
                                checkmarkColor: _berry,
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: selected ? _berry : _line,
                                ),
                                labelStyle: TextStyle(
                                  color: selected ? _plum : _muted,
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                onSelected: (value) {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    if (value) {
                                      _services.add(name);
                                    } else {
                                      _services.remove(name);
                                    }
                                    _onDraftChanged();
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 22),
                        _sectionTitle('Professional experience *'),
                        DropdownButtonFormField<int>(
                          initialValue: _years,
                          isExpanded: true,
                          decoration: _decoration(
                            'Select years of experience',
                            Icons.workspace_premium_outlined,
                          ),
                          items: const [0, 1, 2, 3, 4, 5, 7, 10, 15, 20]
                              .map(
                                (years) => DropdownMenuItem(
                                  value: years,
                                  child: Text(
                                    years == 0
                                        ? 'Less than 1 year'
                                        : '$years${years == 20 ? '+' : ''} ${years == 1 ? 'year' : 'years'}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _years = value);
                            _onDraftChanged();
                          },
                        ),
                        const SizedBox(height: 22),
                        _sectionTitle('How do you work? *'),
                        ..._workModes.map(
                          (mode) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              clipBehavior: Clip.antiAlias,
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                  horizontal: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _workMode == mode
                                      ? const Color(0xFFFFEBF1)
                                      : Colors.white,
                                  border: Border.all(
                                    color: _workMode == mode ? _berry : _line,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: RadioListTile<String>(
                                  value: mode,
                                  groupValue: _workMode,
                                  activeColor: _berry,
                                  title: Text(
                                    mode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _plum,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _workMode = v);
                                      _onDraftChanged();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (homeVisits) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _sectionTitle(
                                  'Preferred travel radius *',
                                ),
                              ),
                              Text(
                                '${_radiusKm.round()} km',
                                style: const TextStyle(
                                  color: _berry,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 5,
                            max: 30,
                            divisions: 5,
                            value: _radiusKm,
                            activeColor: _berry,
                            label: '${_radiusKm.round()} km',
                            onChanged: (value) {
                              setState(() => _radiusKm = value);
                              _onDraftChanged();
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '5 km',
                                  style: TextStyle(color: _muted, fontSize: 11),
                                ),
                                Text(
                                  '30 km',
                                  style: TextStyle(color: _muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 21),
                        _sectionTitle(
                          'Languages you speak *',
                          hint:
                              'Choose all languages you are comfortable using.',
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _languages.map((language) {
                            final selected = _spokenLanguages.contains(
                              language,
                            );
                            return FilterChip(
                              label: Text(language),
                              selected: selected,
                              showCheckmark: true,
                              selectedColor: const Color(0xFFF7D9E6),
                              checkmarkColor: _berry,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: selected ? _berry : _line,
                              ),
                              onSelected: (value) {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (value) {
                                    _spokenLanguages.add(language);
                                  } else {
                                    _spokenLanguages.remove(language);
                                  }
                                  _onDraftChanged();
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),
                        _sectionTitle(
                          'About you',
                          hint: 'Optional — a short professional introduction.',
                        ),
                        TextFormField(
                          controller: _about,
                          maxLines: 3,
                          maxLength: 300,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(300),
                          ],
                          decoration: _decoration(
                            'Tell customers about your experience',
                            Icons.edit_note_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _sectionTitle(
                          'Training or certificate details',
                          hint:
                              'Optional for now. Document uploads are in Step 3.',
                        ),
                        TextFormField(
                          controller: _certificate,
                          maxLength: 120,
                          decoration: _decoration(
                            'Course or certificate name',
                            Icons.school_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(Icons.lock_outline, color: _muted, size: 14),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Step 2 of your partner registration. Document uploads next in Step 3.',
                                style: TextStyle(color: _muted, fontSize: 11.5),
                              ),
                            ),
                          ],
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
                            minimumSize: const Size(82, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
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
                                  colors: [
                                    Color(0xFFD41361),
                                    Color(0xFF750034),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: FilledButton(
                                onPressed: _continue,
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 7),
                                    Icon(Icons.arrow_forward_rounded, size: 19),
                                  ],
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
      ),
    );
  }
}
