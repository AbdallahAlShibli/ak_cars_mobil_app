import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';

enum OtpChannel { phone, email }

/// Rules 4–6: one-time registration gate before any transaction, and the
/// editor for those same details afterwards.
///
/// Both modes are one screen on purpose — they hold the identical fields and
/// the identical validation. This screen used to be sign-up only, so "My
/// details" on the profile hub reopened an empty registration form and
/// re-demanded an OTP just to correct an address.
///
/// Verification is asked for only when it means something: a brand-new
/// account, or an existing one whose phone or email actually changed. The
/// channel is then dictated by *which* of the two changed rather than left
/// as a free choice, since a code sent to the old address proves nothing.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  /// The code the staging backend always accepts. Real builds swap the mock
  /// auth service; this screen only ever compares against what it displayed.
  static const _stagingCode = '7391';
  static const _resendSeconds = 30;

  /// Captured once: the profile must not flip mid-edit if the state changes
  /// underneath (a sign-out elsewhere, a failed optimistic write rolling back).
  UserProfile? _initial;
  bool get _editing => _initial != null;

  OtpChannel _channel = OtpChannel.phone;
  bool _otpSent = false;
  bool _saving = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _otp = TextEditingController();

  /// Canonical English governorate key. Starts empty for a new account —
  /// silently defaulting to the first governorate in the list filed every
  /// user who never opened the picker under the wrong region.
  String? _region;

  /// Field key → message, shown under the offending row.
  final _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    if (profile == null) return;
    _initial = profile;
    _name.text = profile.name;
    // The field holds the local 8 digits only — the +968 is painted into the
    // row. Prefilling the stored "+968 9200 1234" verbatim would render the
    // dial code twice.
    _phone.text = _local(profile.phone);
    _email.text = profile.email;
    _address.text = profile.address;
    _region = profile.region.isEmpty ? null : profile.region;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _otp.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------- verification

  static String _digits(String v) => v.replaceAll(RegExp(r'\D'), '');

  /// Phone reduced to its Oman-local digits, so "+968 9200 1234",
  /// "96892001234" and "9200 1234" all compare equal.
  static String _local(String v) {
    final digits = _digits(v);
    return digits.startsWith('968') ? digits.substring(3) : digits;
  }

  static String _normEmail(String v) => v.trim().toLowerCase();

  /// Which contact detail still has to be proven, or null when nothing does.
  ///
  /// A new account always verifies through the channel the user picked. An
  /// existing one verifies only what it changed, so editing an address or a
  /// name saves straight away.
  OtpChannel? get _pendingChannel {
    final initial = _initial;
    if (initial == null) return _channel;
    if (_local(_phone.text) != _local(initial.phone)) return OtpChannel.phone;
    final email = _normEmail(_email.text);
    if (email.isNotEmpty && email != _normEmail(initial.email)) {
      return OtpChannel.email;
    }
    return null;
  }

  /// Full E.164-ish phone as stored and displayed, built from the local field.
  String get _fullPhone => '+968 ${_local(_phone.text)}';

  String get _otpTarget =>
      _pendingChannel == OtpChannel.email ? _email.text.trim() : _fullPhone;

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  /// Sends the code, after checking the destination is actually usable —
  /// the old screen happily announced "code sent to " with an empty address.
  void _sendOtp() {
    final s = S.of(context);
    final channel = _pendingChannel;
    if (channel == null) return;

    final error = channel == OtpChannel.phone
        ? _phoneError(s)
        : _emailError(s, required: true);
    if (error != null) {
      setState(() => _errors[channel == OtpChannel.phone ? 'phone' : 'email'] =
          error);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _otpSent = true;
      _errors.remove('otp');
    });
    _startResendCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(channel == OtpChannel.phone
            ? s.t('أُرسل الرمز عبر SMS إلى $_otpTarget — رمز التجربة: $_stagingCode',
                'Code sent by SMS to $_otpTarget — staging code: $_stagingCode')
            : s.t('أُرسل الرمز إلى $_otpTarget — رمز التجربة: $_stagingCode',
                'Code sent to $_otpTarget — staging code: $_stagingCode')),
      ),
    );
  }

  // ------------------------------------------------------------ validation

  String? _phoneError(S s) {
    final local = _local(_phone.text);
    if (local.isEmpty) {
      return s.t('رقم الهاتف مطلوب', 'Phone number is required');
    }
    if (local.length != 8) {
      return s.t('رقم عُماني من 8 أرقام', 'An 8-digit Oman number');
    }
    return null;
  }

  String? _emailError(S s, {required bool required}) {
    final email = _normEmail(_email.text);
    if (email.isEmpty) {
      return required
          ? s.t('البريد الإلكتروني مطلوب للتوثيق بالبريد',
              'Email is required to verify by email')
          : null;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return s.t('صيغة بريد غير صحيحة', 'That does not look like an email');
    }
    return null;
  }

  /// Fills [_errors] and reports whether the form is submittable.
  bool _validate(S s) {
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty) {
      errors['name'] = s.t('الاسم مطلوب', 'Your name is required');
    }
    final phone = _phoneError(s);
    if (phone != null) errors['phone'] = phone;
    final channel = _pendingChannel;
    final email = _emailError(s, required: channel == OtpChannel.email);
    if (email != null) errors['email'] = email;
    if (_region == null) {
      errors['region'] = s.t('اختر المحافظة', 'Choose your governorate');
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  // ---------------------------------------------------------------- submit

  Future<void> _submit() async {
    final s = S.of(context);
    if (!_validate(s)) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_pendingChannel != null) {
      // First tap sends the code and reveals the field. The old screen just
      // complained about a missing code while no code field was on screen.
      if (!_otpSent) {
        _sendOtp();
        return;
      }
      if (_otp.text.trim() != _stagingCode) {
        HapticFeedback.heavyImpact();
        setState(() => _errors['otp'] = _otp.text.trim().isEmpty
            ? s.t('أدخل الرمز المكوّن من 4 أرقام', 'Enter the 4-digit code')
            : s.t('رمز غير صحيح', 'That code is not right'));
        return;
      }
    }

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final profile = UserProfile(
      id: _initial?.id,
      name: _name.text.trim(),
      phone: _fullPhone,
      email: _email.text.trim(),
      region: _region!,
      address: _address.text.trim(),
    );

    final notifier = ref.read(authProvider.notifier);
    if (_editing) {
      await notifier.updateProfile(profile);
    } else {
      await notifier.register(profile);
    }
    if (!mounted) return;

    // Keeps the region the app searches in aligned with the one on file.
    ref.read(regionProvider.notifier).state = profile.region;

    HapticFeedback.heavyImpact();
    final messenger = ScaffoldMessenger.of(context);
    // Reached from a gated action or the profile hub → back to it. Deep
    // linked with nothing to pop → the profile hub.
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/profile');
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(_editing
            ? s.t('تم حفظ بياناتك', 'Your details are saved')
            : s.t('تم توثيق الحساب — يمكنك الآن إجراء المعاملات',
                'Account verified — you can now transact')),
      ),
    );
  }

  Future<void> _pickRegion() async {
    final s = S.of(context);
    final locations = ref.read(locationCatalogProvider);
    final ak = AkColors.of(context);
    final governorates = locations.governorates.keys.toList();
    HapticFeedback.selectionClick();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ak.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(
                  s.t('المحافظة', 'Governorate'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    for (final g in governorates)
                      _RegionOption(
                        label: locations.localized(g, s.isAr),
                        selected: g == _region,
                        onTap: () => Navigator.pop(context, g),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _region = picked;
        _errors.remove('region');
      });
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final locations = ref.watch(locationCatalogProvider);
    final pending = _pendingChannel;

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(
        title: Text(_editing
            ? s.t('بياناتي', 'My details')
            : s.t('أكمل بياناتك', 'Complete your details')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  _editing
                      ? _NoticeCard(
                          icon: Icons.verified_rounded,
                          background: ak.successSoft,
                          foreground: ak.success,
                          message: s.t(
                              'حسابك موثّق. عدّل ما تشاء — لن نطلب رمزاً جديداً إلا إذا غيّرت رقم هاتفك أو بريدك.',
                              'Your account is verified. Change anything you like — a new code is only needed if you change your phone or email.'),
                        )
                      : _NoticeCard(
                          icon: Icons.lock_outline_rounded,
                          background: ak.amberBgSoft,
                          foreground: ak.amberText,
                          message: s.t(
                              'مطلوب مرة واحدة — قبل طلب الخدمات أو شراء القطع أو نشر إعلان سيارة. التصفح يبقى مجانياً.',
                              'Required once — before requesting services, ordering parts, or posting a car ad. Browsing stays free.'),
                        ),
                  const SizedBox(height: 18),
                  _SectionLabel(s.t('بياناتك', 'Your details')),
                  _FieldRow(
                    icon: Icons.person_outline_rounded,
                    label: s.t('الاسم الكامل', 'Full name'),
                    hint: s.t('مثال: سالم الهنائي', 'e.g. Salim Al Hinai'),
                    controller: _name,
                    error: _errors['name'],
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => _clear('name'),
                  ),
                  _FieldRow(
                    icon: Icons.phone_outlined,
                    label: s.t('رقم الهاتف', 'Phone number'),
                    hint: '9200 1234',
                    prefix: '+968 ',
                    controller: _phone,
                    error: _errors['phone'],
                    keyboardType: TextInputType.phone,
                    numeric: true,
                    onChanged: (_) => _clear('phone'),
                  ),
                  _FieldRow(
                    icon: Icons.mail_outline_rounded,
                    label: s.t('البريد الإلكتروني', 'Email'),
                    hint: 'name@example.om',
                    controller: _email,
                    error: _errors['email'],
                    optional: _channel == OtpChannel.phone && !_editing,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _clear('email'),
                  ),
                  _PickerRow(
                    icon: Icons.map_outlined,
                    label: s.t('المحافظة', 'Governorate'),
                    value: _region == null
                        ? null
                        : locations.localized(_region!, s.isAr),
                    hint: s.t('اختر من القائمة', 'Choose from the list'),
                    error: _errors['region'],
                    onTap: _pickRegion,
                  ),
                  _FieldRow(
                    icon: Icons.home_outlined,
                    label: s.t('العنوان', 'Address'),
                    hint: s.t('الولاية، المنطقة', 'Wilayat, area'),
                    controller: _address,
                    optional: true,
                    onChanged: (_) => _clear('address'),
                  ),
                  // The verification block disappears entirely once there is
                  // nothing left to prove, so an address edit is one tap.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: pending == null
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              _SectionLabel(s.t('التوثيق عبر', 'Verify with')),
                              if (_editing)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _NoticeCard(
                                    icon: Icons.shield_outlined,
                                    background: ak.amberBgSoft,
                                    foreground: ak.amberText,
                                    message: pending == OtpChannel.phone
                                        ? s.t(
                                            'غيّرت رقم هاتفك — أكّده برمز قبل الحفظ.',
                                            'You changed your phone number — confirm it with a code before saving.')
                                        : s.t(
                                            'غيّرت بريدك الإلكتروني — أكّده برمز قبل الحفظ.',
                                            'You changed your email — confirm it with a code before saving.'),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    _ChannelCard(
                                      selected: _channel == OtpChannel.phone,
                                      icon: Icons.sms_outlined,
                                      title:
                                          s.t('رمز عبر الهاتف', 'Phone OTP'),
                                      subtitle: s.t('رمز SMS', 'SMS code'),
                                      onTap: () => _switchChannel(
                                          OtpChannel.phone),
                                    ),
                                    const SizedBox(width: 10),
                                    _ChannelCard(
                                      selected: _channel == OtpChannel.email,
                                      icon: Icons.mark_email_read_outlined,
                                      title:
                                          s.t('رمز عبر البريد', 'Email OTP'),
                                      subtitle:
                                          s.t('رمز بالبريد', 'Code by email'),
                                      onTap: () => _switchChannel(
                                          OtpChannel.email),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              _OtpBlock(
                                sent: _otpSent,
                                controller: _otp,
                                target: _otpTarget,
                                error: _errors['otp'],
                                resendIn: _resendIn,
                                onSend: _sendOtp,
                                onChanged: (_) => _clear('otp'),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: ak.inkFaint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.t('رقم الهاتف مطلوب دائماً — حتى عند التوثيق بالبريد الإلكتروني.',
                              'Phone number is always required — even when verifying by email.'),
                          style: TextStyle(
                              fontSize: 11.5, color: ak.inkFaint, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: ak.bg,
                border: Border(top: BorderSide(color: ak.divider)),
              ),
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: ak.onPrimary),
                      )
                    : Text(_submitLabel(s)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _submitLabel(S s) {
    if (_editing) {
      return _pendingChannel != null && !_otpSent
          ? s.t('إرسال الرمز', 'Send the code')
          : s.t('حفظ التعديلات', 'Save changes');
    }
    return s.t('توثيق ومتابعة', 'Verify and continue');
  }

  void _switchChannel(OtpChannel channel) {
    if (_channel == channel) return;
    HapticFeedback.selectionClick();
    setState(() {
      _channel = channel;
      // The code that was sent proves the *other* address, so it is void.
      _otpSent = false;
      _otp.clear();
      _errors.remove('otp');
    });
    _resendTimer?.cancel();
  }

  /// Drops a field's error as soon as the user starts fixing it.
  void _clear(String key) {
    if (!_errors.containsKey(key)) {
      // Editing the phone/email can change what still needs verifying, so
      // the verification block has to be rebuilt either way.
      setState(() {});
      return;
    }
    setState(() => _errors.remove(key));
  }
}

/// Group label above a run of fields.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: ak.inkFaint,
        ),
      ),
    );
  }
}

/// Tinted advisory card (gate notice, verified badge, re-verify warning).
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.message,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: foreground,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared shell for a labelled row: border turns ink once filled, red when
/// the row is reporting an error, with the message underneath.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.icon,
    required this.child,
    required this.filled,
    this.error,
    this.onTap,
  });

  final IconData icon;
  final Widget child;
  final bool filled;
  final String? error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final bad = error != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                color: ak.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: bad
                      ? ak.danger
                      : filled
                          ? ak.primary
                          : ak.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: bad
                        ? ak.danger
                        : filled
                            ? ak.primary
                            : ak.inkFaint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
          if (bad)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
              child: Text(
                error!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: ak.dangerText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Typed field with a floating label — matches the car form's rows.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.prefix,
    this.error,
    this.optional = false,
    this.numeric = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;

  /// Static leading text inside the field (the +968 dial code).
  final String? prefix;
  final String? error;
  final bool optional;
  final bool numeric;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final filled = controller.text.trim().isNotEmpty;
    return _FieldShell(
      icon: icon,
      filled: filled,
      error: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: ak.inkSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (optional && !filled) ...[
                const SizedBox(width: 6),
                Text(
                  s.t('اختياري', 'optional'),
                  style: TextStyle(fontSize: 10.5, color: ak.inkFaint),
                ),
              ],
            ],
          ),
          Row(
            children: [
              if (prefix != null)
                Text(
                  prefix!,
                  style: AppTheme.numeric(
                      size: 13.5, weight: FontWeight.w700, color: ak.inkSub),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  inputFormatters: numeric
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  style: numeric
                      ? AppTheme.numeric(size: 13.5, color: ak.ink)
                      : const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: hint,
                    hintStyle: TextStyle(
                        fontSize: 13, color: ak.inkFaint,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Read-only row that opens a picker sheet (governorate).
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.hint,
    this.error,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final filled = value != null;
    return _FieldShell(
      icon: icon,
      filled: filled,
      error: error,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: ak.inkSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value ?? hint ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                    color: filled ? ak.ink : ak.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.expand_more_rounded, color: ak.inkFaint),
        ],
      ),
    );
  }
}

class _RegionOption extends StatelessWidget {
  const _RegionOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: ak.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? ak.primary : ak.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 17, color: selected ? ak.primary : ak.inkFaint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 18, color: ak.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two OTP delivery choices.
class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            color: ak.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? ak.primary : ak.border,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? ak.primary : ak.inkFaint),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? ak.ink : ak.inkSub,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: ak.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Send the code" prompt before sending; the code field plus a resend
/// countdown after.
class _OtpBlock extends StatelessWidget {
  const _OtpBlock({
    required this.sent,
    required this.controller,
    required this.target,
    required this.resendIn,
    required this.onSend,
    required this.onChanged,
    this.error,
  });

  final bool sent;
  final TextEditingController controller;
  final String target;
  final int resendIn;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    if (!sent) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: onSend,
          icon: const Icon(Icons.send_rounded, size: 16),
          label: Text(s.t('إرسال الرمز', 'Send the code')),
        ),
      );
    }

    final bad = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t('أدخل الرمز المُرسل إلى $target',
              'Enter the code sent to $target'),
          style: TextStyle(fontSize: 12, color: ak.inkSub),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: ak.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: bad ? ak.danger : ak.border,
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTheme.numeric(
                size: 20, weight: FontWeight.w800, color: ak.ink)
                .copyWith(letterSpacing: 10),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: '• • • •',
              counterText: '',
            ),
          ),
        ),
        if (bad)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
            child: Text(
              error!,
              style: TextStyle(
                fontSize: 11.5,
                color: ak.dangerText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: resendIn > 0 ? null : onSend,
            child: Text(
              resendIn > 0
                  ? s.t('إعادة الإرسال خلال $resendIn ثانية',
                      'Resend in ${resendIn}s')
                  : s.t('إعادة إرسال الرمز', 'Resend the code'),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}
