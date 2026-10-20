import 'dart:convert';
import 'dart:io';
import 'dart:ui' show instantiateImageCodec;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/slide_page_route.dart';
import 'worker_profile_data.dart';
import '../widgets/worker_design.dart';

const _pink = WorkerDesign.pink;
const _deep = WorkerDesign.deep;
const _muted = WorkerDesign.muted;
const _border = WorkerDesign.border;
const _background = WorkerDesign.cream;

class WorkerProfileSettingsScreen extends StatefulWidget {
  const WorkerProfileSettingsScreen({
    super.key,
    this.workerName = '',
    this.phoneNumber = '',
    this.isVerified = false,
    this.demoMode = true,
    this.onLogoutTap,
    this.repository,
  });

  final String workerName;
  final String phoneNumber;
  final bool isVerified;
  final bool demoMode;
  final VoidCallback? onLogoutTap;
  final WorkerProfileRepository? repository;

  @override
  State<WorkerProfileSettingsScreen> createState() =>
      _WorkerProfileSettingsScreenState();
}

class _WorkerProfileSettingsScreenState
    extends State<WorkerProfileSettingsScreen> {
  WorkerProfile? _profile;
  bool _loading = true;
  Object? _loadError;
  WorkerProfileRepository get _repository =>
      widget.repository ?? WorkerProfileStore.repository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _repository.load(widget.phoneNumber);
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = error;
        });
      }
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) {
      _notice('No saved local registration profile exists for this mobile.');
      return;
    }
    final updated = await Navigator.of(context).push<WorkerProfile>(
      SlidePageRoute<WorkerProfile>(
        page: WorkerPersonalInformationScreen(
          profile: profile,
          repository: _repository,
        ),
      ),
    );
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  Future<void> _editSpecializations() async {
    final profile = _profile;
    if (profile == null) {
      _notice('No saved local registration profile exists for this mobile.');
      return;
    }
    final updated = await Navigator.of(context).push<WorkerProfile>(
      SlidePageRoute<WorkerProfile>(
        page: WorkerServiceSpecializationScreen(
          profile: profile,
          repository: _repository,
        ),
      ),
    );
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  Future<void> _editNotifications(bool enabled) async {
    final profile = _profile;
    if (profile == null) return;
    try {
      final updated = profile.copyWith(notificationsEnabled: enabled);
      await _repository.save(updated);
      if (mounted) setState(() => _profile = updated);
    } catch (error) {
      if (mounted) {
        _notice('Could not save notification preference locally: $error');
      }
    }
  }

  Future<void> _openSecurity() async {
    await Navigator.of(context).push<void>(
      SlidePageRoute<void>(
        page: WorkerAccountSecurityScreen(
          phoneNumber: widget.phoneNumber,
          onExitPreview: widget.onLogoutTap,
        ),
      ),
    );
  }

  Future<void> _confirmExitPreview() async {
    final exit = widget.onLogoutTap;
    if (exit == null) {
      _notice('Preview exit navigation is not connected in this context.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit worker preview?'),
        content: const Text(
          'There is no authenticated server session to revoke. Your saved local profile and settings will remain on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit preview'),
          ),
        ],
      ),
    );
    if (confirmed == true) exit();
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 9),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _deep,
          ),
        ),
      ),
      Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x18C74776),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  indent: 52,
                  endIndent: 12,
                  color: _border,
                ),
              children[i],
            ],
          ],
        ),
      ),
    ],
  );

  Widget _item(
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) => ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 1),
    leading: Container(
      width: 33,
      height: 33,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: _pink, size: 18),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: _deep,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
    trailing:
        trailing ??
        const Icon(Icons.chevron_right_rounded, color: _muted, size: 19),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final profileName = _profile?.fullName.trim();
    final name = profileName == null || profileName.isEmpty
        ? (widget.workerName.isEmpty ? 'Worker profile' : widget.workerName)
        : profileName;
    final phone = _profile?.mobile ?? widget.phoneNumber;
    final notifications = _profile?.notificationsEnabled ?? false;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _deep,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _pink))
            : _loadError != null
            ? _LoadError(error: _loadError!, onRetry: _load)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
                children: [
                  const WorkerPageBanner(
                    eyebrow: 'Your space',
                    title: 'My Profile',
                    subtitle: 'Keep your details and preferences in one place.',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  if (widget.demoMode) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDF3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: _pink, size: 17),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Local preview profile. Changes stay on this device and are not synced to a server.',
                              style: TextStyle(fontSize: 11, color: _deep),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: WorkerDesign.surface(radius: 20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 29,
                          backgroundColor: Color(0xFFFFE2EC),
                          child: _profile?.profilePhotoPath == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: _pink,
                                  size: 34,
                                )
                              : ClipOval(
                                  child: Image.file(
                                    File(_profile!.profilePhotoPath!),
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        const Icon(
                                          Icons.person_rounded,
                                          color: _pink,
                                          size: 34,
                                        ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _deep,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phone.isEmpty ? 'Mobile not provided' : phone,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 7),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: _muted,
                                    size: 15,
                                  ),
                                  SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Server verification unavailable',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _section('My Account', [
                    _item(
                      Icons.badge_outlined,
                      'Personal Information',
                      subtitle: _profile?.email.isNotEmpty == true
                          ? _profile!.email
                          : 'Registration details and contact',
                      onTap: _editProfile,
                    ),
                    _item(
                      Icons.spa_outlined,
                      'Service Specialization',
                      subtitle: _profile == null
                          ? 'No saved registration profile'
                          : _profile!.services.isEmpty
                          ? 'No services selected'
                          : _profile!.services.join(', '),
                      onTap: _editSpecializations,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _section('Preferences & Security', [
                    _item(
                      Icons.notifications_none_rounded,
                      'Notifications',
                      subtitle:
                          'Saved locally only. Push delivery is not configured; booking alerts remain visible.',
                      trailing: Switch.adaptive(
                        value: notifications,
                        activeTrackColor: _pink,
                        onChanged: _profile == null ? null : _editNotifications,
                      ),
                    ),
                    _item(
                      Icons.lock_outline_rounded,
                      'Account Security',
                      subtitle: 'Mobile OTP preview; no password sign-in',
                      onTap: _openSecurity,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _section('Support & Legal', [
                    _item(
                      Icons.help_outline_rounded,
                      'Help & Support',
                      subtitle: 'FAQs and a local issue draft',
                      onTap: () => Navigator.of(context).push<void>(
                        SlidePageRoute<void>(
                          page: WorkerHelpSupportScreen(
                            phoneNumber: widget.phoneNumber,
                          ),
                        ),
                      ),
                    ),
                    _item(
                      Icons.description_outlined,
                      'Terms & Privacy',
                      subtitle: 'Approved content is not configured',
                      onTap: () => Navigator.of(context).push<void>(
                        SlidePageRoute<void>(
                          page: const WorkerTermsPrivacyScreen(),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: widget.onLogoutTap == null
                        ? null
                        : _confirmExitPreview,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Exit worker preview'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _pink,
                      side: const BorderSide(color: _border),
                    ),
                  ),
                  if (widget.onLogoutTap == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Preview exit is not connected in this context.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Profile load error: $_loadError',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class WorkerPersonalInformationScreen extends StatefulWidget {
  const WorkerPersonalInformationScreen({
    super.key,
    required this.profile,
    required this.repository,
  });

  final WorkerProfile profile;
  final WorkerProfileRepository repository;

  @override
  State<WorkerPersonalInformationScreen> createState() =>
      _WorkerPersonalInformationScreenState();
}

class _WorkerPersonalInformationScreenState
    extends State<WorkerPersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.fullName,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.profile.email,
  );
  late final TextEditingController _city = TextEditingController(
    text: widget.profile.cityOrArea,
  );
  late WorkerProfile _currentProfile = widget.profile;
  final ImagePicker _imagePicker = ImagePicker();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final updated = _currentProfile.copyWith(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        cityOrArea: _city.text.trim(),
      );
      await widget.repository.save(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved on this device.')),
        );
        Navigator.of(context).pop(updated);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile locally: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _choosePhoto() async {
    if (_saving) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.lengthInBytes > 5 * 1024 * 1024) {
        throw const FormatException('Choose a photo smaller than 5 MB.');
      }
      final codec = await instantiateImageCodec(bytes);
      codec.dispose();
      final path = await widget.repository.savePhoto(
        widget.profile.mobile,
        bytes,
      );
      final updated = _currentProfile.copyWith(profilePhotoPath: path);
      await widget.repository.save(updated);
      if (mounted) setState(() => _currentProfile = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update profile photo locally: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      title: const Text('Personal Information'),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Saved registration details · editable changes are local preview data.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFFFE2EC),
                    child: _currentProfile.profilePhotoPath == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: _pink,
                            size: 38,
                          )
                        : ClipOval(
                            child: Image.file(
                              File(_currentProfile.profilePhotoPath!),
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  const Icon(
                                    Icons.person_rounded,
                                    color: _pink,
                                    size: 38,
                                  ),
                            ),
                          ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _choosePhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Change profile photo'),
                  ),
                ],
              ),
            ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter your name.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: widget.profile.mobile,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Registered mobile',
                helperText:
                    'Changing the registered mobile requires verified backend support.',
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Primary service category',
              ),
              child: Text(widget.profile.primaryCategory),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Experience'),
              child: Text('${widget.profile.yearsOfExperience} year(s)'),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Work mode'),
              child: Text(widget.profile.workMode),
            ),
            if (widget.profile.workMode != 'Salon-based') ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Travel radius'),
                child: Text('${widget.profile.travelRadiusKm} km'),
              ),
            ],
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Languages'),
              child: Text(widget.profile.languages.join(', ')),
            ),
            if (widget.profile.about.isNotEmpty) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'About'),
                child: Text(widget.profile.about),
              ),
            ],
            if (widget.profile.certificateDetails.isNotEmpty) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Training details',
                ),
                child: Text(widget.profile.certificateDetails),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isNotEmpty &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'City or service area',
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Date of birth'),
              child: Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(widget.profile.dateOfBirth),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    ),
  );
}

class WorkerServiceSpecializationScreen extends StatefulWidget {
  const WorkerServiceSpecializationScreen({
    super.key,
    required this.profile,
    required this.repository,
  });

  final WorkerProfile profile;
  final WorkerProfileRepository repository;

  @override
  State<WorkerServiceSpecializationScreen> createState() =>
      _WorkerServiceSpecializationScreenState();
}

class _WorkerServiceSpecializationScreenState
    extends State<WorkerServiceSpecializationScreen> {
  late String _category = widget.profile.primaryCategory;
  late final Set<String> _services = {...widget.profile.services};
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || _services.isEmpty) return;
    setState(() => _saving = true);
    try {
      final updated = widget.profile.copyWith(
        primaryCategory: _category,
        services: _services.toList(growable: false),
      );
      await widget.repository.save(updated);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save specializations locally: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = workerServiceOptions[_category] ?? const <String>[];
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('Service Specialization'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Changes are saved locally and do not change booking assignments or approval.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: workerServiceOptions.containsKey(_category)
                  ? _category
                  : null,
              decoration: const InputDecoration(labelText: 'Primary category'),
              items: workerServiceOptions.keys
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _category = value;
                  _services.removeWhere(
                    (service) =>
                        !workerServiceOptions[value]!.contains(service),
                  );
                });
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Select services (${_services.length} selected)',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _deep),
            ),
            const SizedBox(height: 8),
            for (final service in options)
              CheckboxListTile(
                value: _services.contains(service),
                activeColor: _pink,
                contentPadding: EdgeInsets.zero,
                title: Text(service),
                onChanged: (selected) => setState(() {
                  if (selected == true) {
                    _services.add(service);
                  } else {
                    _services.remove(service);
                  }
                }),
              ),
            if (_services.isEmpty)
              const Text(
                'Select at least one service before saving.',
                style: TextStyle(color: _pink),
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving || _services.isEmpty ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save specializations'),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkerAccountSecurityScreen extends StatelessWidget {
  const WorkerAccountSecurityScreen({
    super.key,
    required this.phoneNumber,
    this.onExitPreview,
  });

  final String phoneNumber;
  final VoidCallback? onExitPreview;

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit worker preview?'),
        content: const Text(
          'This preview has no authenticated server session to revoke. Your saved local profile will remain on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit preview'),
          ),
        ],
      ),
    );
    if (confirmed == true && onExitPreview != null) onExitPreview!();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      title: const Text('Account Security'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const ListTile(
          leading: Icon(Icons.phonelink_lock_outlined, color: _pink),
          title: Text('Sign-in method'),
          subtitle: Text(
            'Mobile OTP preview. No password sign-in is configured.',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.phone_outlined, color: _pink),
          title: const Text('Mobile number'),
          subtitle: Text(phoneNumber.isEmpty ? 'Not available' : phoneNumber),
        ),
        const ListTile(
          leading: Icon(Icons.verified_user_outlined, color: _pink),
          title: Text('Verification'),
          subtitle: Text('OTP preview is not server verification.'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onExitPreview == null ? null : () => _confirmExit(context),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Exit preview'),
        ),
        if (onExitPreview == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Preview exit navigation is not connected in this context.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
          ),
      ],
    ),
  );
}

class WorkerHelpSupportScreen extends StatefulWidget {
  const WorkerHelpSupportScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<WorkerHelpSupportScreen> createState() =>
      _WorkerHelpSupportScreenState();
}

class _WorkerHelpSupportScreenState extends State<WorkerHelpSupportScreen> {
  static const _storage = FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _booking = TextEditingController();
  String _category = 'General account';
  bool _saving = false;

  String get _draftKey =>
      'pinkora.worker.support_draft.${widget.phoneNumber.replaceAll(RegExp(r'\D'), '')}';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final raw = await _storage.read(key: _draftKey);
      if (!mounted || raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map) throw const FormatException('Invalid support draft');
      setState(() {
        _category = data['category'] is String
            ? data['category'] as String
            : _category;
        _description.text = data['description'] is String
            ? data['description'] as String
            : '';
        _booking.text = data['booking'] is String
            ? data['booking'] as String
            : '';
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load local support draft: $error')),
        );
      }
    }
  }

  Future<void> _saveDraft() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _storage.write(
        key: _draftKey,
        value: jsonEncode({
          'category': _category,
          'description': _description.text.trim(),
          'booking': _booking.text.trim(),
        }),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Local draft saved on this device; it was not sent to support.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save local draft: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _booking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      title: const Text('Help & Support'),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'FAQ: For booking changes, open the booking from My Bookings. For account details, use Personal Information. No company support service is connected in this preview.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Issue category'),
              items: const [
                DropdownMenuItem(value: 'Booking', child: Text('Booking')),
                DropdownMenuItem(
                  value: 'General account',
                  child: Text('General account'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? 'General account'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _booking,
              decoration: const InputDecoration(
                labelText: 'Booking reference (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Describe the issue',
                alignLabelWithHint: true,
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Describe your issue.'
                  : null,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _saveDraft,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save local draft'),
            ),
          ],
        ),
      ),
    ),
  );
}

class WorkerTermsPrivacyScreen extends StatelessWidget {
  const WorkerTermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      title: const Text('Terms & Privacy'),
    ),
    body: const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, color: _pink, size: 42),
              SizedBox(height: 14),
              Text(
                'Approved terms and privacy content is not configured.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _deep,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'No legal policy text or external URL is available in this app preview.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Could not load local profile data.',
            style: TextStyle(color: _deep, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
