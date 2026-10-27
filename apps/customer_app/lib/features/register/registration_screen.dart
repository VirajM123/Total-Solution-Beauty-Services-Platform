import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/route_names.dart';
import '../../core/api/mobile_api.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/pinkora_brand.dart';
import '../login/login_screen.dart' show IndiaFlag;
import '../../integration/customer_auth_api.dart';
import '../otp/development_otp_screen.dart';
import '../shared/auth_brand_mark.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.config,
    this.authApi,
    this.registration,
  });
  final AppConfig config;
  final CustomerAuthApi? authApi;
  CustomerAuthApi get auth =>
      authApi ?? CustomerAuthApi(api: MobileApi(baseUrl: config.apiBaseUrl));
  final CustomerRegistrationArgs? registration;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _nameError, _phoneError, _emailError, _consentError;
  String? _gender;
  DateTime? _birthDate;
  bool _consent = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _phone.text = widget.registration?.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? today,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _continue() async {
    if (_loading) return;
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Enter your full name.' : null;
      _phoneError = RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)
          ? null
          : 'Enter a valid 10-digit Indian mobile number.';
      _emailError =
          email.isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
          ? null
          : 'Enter a valid email address or leave this blank.';
      _consentError = _consent ? null : 'Please agree before continuing.';
    });
    if (_nameError != null ||
        _phoneError != null ||
        _emailError != null ||
        _consentError != null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final proof = widget.registration?.registrationToken;
      if (proof != null) {
        await widget.auth.register(
          registrationToken: proof,
          name: name,
          email: email,
        );
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
        }
      } else {
        final challengeId = await widget.auth.requestRegistrationOtp(phone);
        if (!mounted) return;
        await Navigator.of(context).pushNamed(
          RouteNames.otp,
          arguments: CustomerOtpRouteArgs(
            phone: phone,
            challengeId: challengeId,
            registration: CustomerRegistrationDraft(
              name: name,
              phone: phone,
              email: email,
            ),
          ),
        );
        if (mounted) {
          _name.clear();
          _phone.clear();
          _email.clear();
          setState(() {
            _gender = null;
            _birthDate = null;
            _consent = false;
          });
        }
      }
    } on MobileApiException catch (error) {
      if (mounted) setState(() => _phoneError = error.message);
    } catch (error) {
      if (mounted) setState(() => _phoneError = 'Registration failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint, {Widget? prefix, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF91878E), fontSize: 13),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: PinkoraBrand.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: PinkoraBrand.berry, width: 1.5),
        ),
      );

  Widget _label(String label, {bool optional = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Text(
      optional ? '$label  (Optional)' : '$label *',
      style: const TextStyle(
        color: PinkoraBrand.charcoal,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _error(String? message) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFB3261E), fontSize: 11),
          ),
        );

  Widget _fieldGroup(
    String label,
    Widget field, {
    bool optional = false,
    String? error,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label, optional: optional),
      SizedBox(height: 46, child: field),
      _error(error),
      const SizedBox(height: 7),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final heroHeight = (screen.height * .255).clamp(185.0, 220.0);
    return Scaffold(
      backgroundColor: PinkoraBrand.ivory,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.customerRegistrationHero,
            key: const ValueKey('customer-registration-background'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          ),
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                children: [
                  SizedBox(
                    height: heroHeight - topPadding,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 16,
                          top: 10,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                            ),
                            color: PinkoraBrand.berry,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: .78,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 28,
                          bottom: 17,
                          child: AuthBrandMark(compact: true),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: screen.height - heroHeight,
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 15),
                    decoration: BoxDecoration(
                      color: PinkoraBrand.ivory.withValues(alpha: .97),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x226C2940),
                          blurRadius: 24,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create your account',
                          style: TextStyle(
                            color: PinkoraBrand.charcoal,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Your beauty routine starts here.',
                          style: TextStyle(
                            color: PinkoraBrand.muted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 11),
                        _fieldGroup(
                          'Full Name',
                          TextField(
                            key: const ValueKey('registration-name'),
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: _decoration(
                              'Your full name',
                              prefix: const Icon(
                                Icons.person_outline,
                                color: PinkoraBrand.muted,
                                size: 20,
                              ),
                            ),
                            onChanged: (_) {
                              if (_nameError != null) {
                                setState(() => _nameError = null);
                              }
                            },
                          ),
                          error: _nameError,
                        ),
                        _fieldGroup(
                          'Mobile Number',
                          TextField(
                            key: const ValueKey('registration-phone'),
                            controller: _phone,
                            readOnly:
                                widget.registration?.registrationToken != null,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.telephoneNumberNational,
                            ],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration:
                                _decoration(
                                  '10-digit mobile number',
                                  prefix: const SizedBox(
                                    width: 88,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IndiaFlag(width: 20, height: 14),
                                          SizedBox(width: 7),
                                          Text(
                                            '+91',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          SizedBox(width: 7),
                                          SizedBox(
                                            height: 20,
                                            child: VerticalDivider(
                                              width: 1,
                                              color: PinkoraBrand.line,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ).copyWith(
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 88,
                                    maxWidth: 88,
                                  ),
                                ),
                            onChanged: (_) {
                              if (_phoneError != null) {
                                setState(() => _phoneError = null);
                              }
                            },
                          ),
                          error: _phoneError,
                        ),
                        _fieldGroup(
                          'Email Address',
                          TextField(
                            key: const ValueKey('registration-email'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: _decoration(
                              'you@example.com',
                              prefix: const Icon(
                                Icons.mail_outline,
                                color: PinkoraBrand.muted,
                                size: 20,
                              ),
                            ),
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                          ),
                          optional: true,
                          error: _emailError,
                        ),
                        _fieldGroup(
                          'Gender',
                          DropdownButtonFormField<String>(
                            key: const ValueKey('registration-gender'),
                            isExpanded: true,
                            initialValue: _gender,
                            style: const TextStyle(
                              color: PinkoraBrand.charcoal,
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                            ),
                            decoration: _decoration(
                              'Select gender',
                              prefix: const Icon(
                                Icons.people_outline,
                                color: PinkoraBrand.muted,
                                size: 20,
                              ),
                            ),
                            items:
                                const [
                                      'Female',
                                      'Male',
                                      'Other',
                                      'Prefer not to say',
                                    ]
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) =>
                                setState(() => _gender = value),
                          ),
                          optional: true,
                        ),
                        _fieldGroup(
                          'Date of Birth',
                          InkWell(
                            key: const ValueKey('registration-dob'),
                            onTap: _pickBirthDate,
                            borderRadius: BorderRadius.circular(11),
                            child: InputDecorator(
                              decoration: _decoration(
                                '',
                                prefix: const Icon(
                                  Icons.calendar_today_outlined,
                                  color: PinkoraBrand.muted,
                                  size: 19,
                                ),
                                suffix: const Icon(
                                  Icons.calendar_month_outlined,
                                  color: PinkoraBrand.berry,
                                  size: 20,
                                ),
                              ),
                              child: Text(
                                _birthDate == null
                                    ? 'Select date'
                                    : '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _birthDate == null
                                      ? PinkoraBrand.muted
                                      : PinkoraBrand.charcoal,
                                ),
                              ),
                            ),
                          ),
                          optional: true,
                        ),
                        Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
                            key: const ValueKey('registration-consent'),
                            value: _consent,
                            onChanged: (value) => setState(() {
                              _consent = value ?? false;
                              if (_consent) _consentError = null;
                            }),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: const VisualDensity(
                              vertical: -4,
                              horizontal: -4,
                            ),
                            activeColor: PinkoraBrand.berry,
                            title: const Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: TextStyle(
                                      color: PinkoraBrand.berry,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: PinkoraBrand.berry,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  TextSpan(text: '.'),
                                ],
                              ),
                              style: TextStyle(
                                color: PinkoraBrand.charcoal,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                        _error(_consentError),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 50,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [PinkoraBrand.rose, PinkoraBrand.berry],
                              ),
                              borderRadius: BorderRadius.circular(27),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x268D214D),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: FilledButton(
                              onPressed: _loading ? null : _continue,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(27),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Continue',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 21,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Already have an account? ',
                                    style: TextStyle(color: PinkoraBrand.muted),
                                  ),
                                  TextSpan(
                                    text: 'Log in',
                                    style: TextStyle(
                                      color: PinkoraBrand.berry,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(fontSize: 12),
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
        ],
      ),
    );
  }
}
