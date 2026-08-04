import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/app_exception.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import 'auth_form_widgets.dart';

/// Sign back in to an account that already registered.
///
/// Registration and login used to be the same screen wearing two hats — a
/// returning user retyped their name, address and governorate just to prove
/// they were still themselves. This screen asks for exactly one thing: the
/// phone or email the account was registered with. Prove it with a code and
/// the session starts with everything already on file, [AccountKind] and all
/// — the profile decides what the rest of the app shows, this screen only
/// decides *whose* profile that is.
///
/// The phone/email choice is explicit — a `_ChannelCard` pair, same shape as
/// the register screen's OTP-channel picker — rather than one field that
/// guesses from an `@`. A guessed field cannot validate: it has no fixed
/// shape to check typing against until the user commits to which kind of
/// value they're typing, and a wrong guess mid-type (an Oman number typed
/// digit-by-digit briefly looks like nothing in particular) flickered the
/// icon and hint under the user's hands.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// Matches the staging OTP the register screen displays — one demo code
  /// for the whole pilot build, so a reviewer never needs a real inbox.
  static const _stagingCode = '7391';
  static const _resendSeconds = 30;

  AuthChannel _channel = AuthChannel.phone;

  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _otp = TextEditingController();

  bool _sending = false;
  bool _otpSent = false;
  bool _verifying = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  /// Field key ('phone' | 'email' | 'otp') → message, shown under the
  /// offending row — same map shape the register screen uses.
  final _errors = <String, String>{};

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ identifier

  /// The address a code is sent to and matched against — the full E.164-ish
  /// phone for the phone channel, the trimmed email for the other. Never
  /// built from raw field text directly, so a stray space in an email or an
  /// unformatted phone can't silently reach the repository.
  String get _identifier => _channel == AuthChannel.phone
      ? AuthPhone.full(AuthPhone.local(_phone.text))
      : _email.text.trim().toLowerCase();

  void _switchChannel(AuthChannel channel) {
    if (_channel == channel) return;
    HapticFeedback.selectionClick();
    setState(() {
      _channel = channel;
      // A code already sent proves the *other* address; switching voids it
      // rather than leaving a stale "sent to" line on screen.
      _otpSent = false;
      _otp.clear();
      _errors.remove('otp');
      _errors.remove('phone');
      _errors.remove('email');
    });
    _resendTimer?.cancel();
  }

  // ------------------------------------------------------------ validation

  String? _phoneError(S s) {
    final local = AuthPhone.local(_phone.text);
    if (local.isEmpty) {
      return s.t('رقم الهاتف مطلوب', 'Phone number is required');
    }
    if (local.length != 8) {
      return s.t('رقم عُماني من 8 أرقام', 'An 8-digit Oman number');
    }
    // The code arrives by SMS, so a landline (2x) cannot receive it.
    if (!RegExp(r'^[79]').hasMatch(local)) {
      return s.t('رقم هاتف نقّال عُماني يبدأ بـ 7 أو 9',
          'An Oman mobile number starting with 7 or 9');
    }
    return null;
  }

  String? _emailError(S s) {
    final email = _email.text.trim();
    if (email.isEmpty) {
      return s.t('البريد الإلكتروني مطلوب', 'Email is required');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return s.t('صيغة بريد غير صحيحة', 'That does not look like an email');
    }
    return null;
  }

  /// The active channel's field error, or null when it validates.
  String? get _currentFieldError =>
      _channel == AuthChannel.phone ? _errors['phone'] : _errors['email'];

  bool _validateIdentifier(S s) {
    final error =
        _channel == AuthChannel.phone ? _phoneError(s) : _emailError(s);
    setState(() {
      if (error == null) {
        _errors.remove(_channel == AuthChannel.phone ? 'phone' : 'email');
      } else {
        _errors[_channel == AuthChannel.phone ? 'phone' : 'email'] = error;
      }
    });
    return error == null;
  }

  void _clearFieldError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  // ---------------------------------------------------------------- OTP

  Future<void> _sendCode() async {
    final s = S.of(context);
    if (!_validateIdentifier(s)) {
      HapticFeedback.heavyImpact();
      return;
    }

    final identifier = _identifier;
    setState(() => _sending = true);
    try {
      final account =
          await ref.read(authProvider.notifier).findAccount(identifier);
      if (!mounted) return;
      if (account == null) {
        HapticFeedback.heavyImpact();
        setState(() => _errors[_channel == AuthChannel.phone
                ? 'phone'
                : 'email'] =
            _channel == AuthChannel.phone
                ? s.t('لا يوجد حساب بهذا الرقم', 'No account with that number')
                : s.t('لا يوجد حساب بهذا البريد', 'No account with that email'));
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
          content: Text(_channel == AuthChannel.email
              ? s.t('أُرسل الرمز إلى $identifier — رمز التجربة: $_stagingCode',
                  'Code sent to $identifier — staging code: $_stagingCode')
              : s.t(
                  'أُرسل الرمز عبر SMS إلى $identifier — رمز التجربة: $_stagingCode',
                  'Code sent by SMS to $identifier — staging code: $_stagingCode')),
        ),
      );
    } on AppException {
      if (!mounted) return;
      setState(() => _errors[_channel == AuthChannel.phone
              ? 'phone'
              : 'email'] =
          s.t('تعذّر إرسال الرمز — حاول مرة أخرى',
              'Could not send the code — try again'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final s = S.of(context);
    if (_otp.text.trim() != _stagingCode) {
      HapticFeedback.heavyImpact();
      setState(() => _errors['otp'] = _otp.text.trim().isEmpty
          ? s.t('أدخل الرمز المكوّن من 4 أرقام', 'Enter the 4-digit code')
          : s.t('رمز غير صحيح', 'That code is not right'));
      return;
    }

    setState(() => _verifying = true);
    try {
      await ref.read(authProvider.notifier).login(_identifier, _otp.text.trim());
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final messenger = ScaffoldMessenger.of(context);
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/profile');
      }
      messenger.showSnackBar(
        SnackBar(content: Text(s.t('مرحباً بعودتك', 'Welcome back'))),
      );
    } on AppException {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _errors['otp'] = s.t(
          'تعذّر تسجيل الدخول — حاول مرة أخرى', 'Could not log in — try again'));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  SandBackButton(onTap: () => context.pop()),
                  const SizedBox(height: 18),
                  Entrance(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(LucideIcons.keyRound,
                          size: 26, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Entrance(
                    delayMs: 40,
                    child: Text(
                      s.t('تسجيل الدخول', 'Log in'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Entrance(
                    delayMs: 80,
                    child: Text(
                      s.t(
                        'اختر كيف سجّلت حسابك، وسنرسل لك رمزاً لمرة واحدة.',
                        "Choose how you registered, and we'll send you a one-time code.",
                      ),
                      style:
                          TextStyle(fontSize: 13, color: ak.inkSub, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthSectionLabel(s.t('الدخول عبر', 'Log in with')),
                  Entrance(
                    delayMs: 100,
                    child: Row(
                      children: [
                        AuthChannelCard(
                          selected: _channel == AuthChannel.phone,
                          icon: LucideIcons.smartphone,
                          title: s.t('رقم الهاتف', 'Phone number'),
                          subtitle: s.t('رمز عبر SMS', 'SMS code'),
                          onTap: () => _switchChannel(AuthChannel.phone),
                        ),
                        const SizedBox(width: 10),
                        AuthChannelCard(
                          selected: _channel == AuthChannel.email,
                          icon: LucideIcons.mail,
                          title: s.t('البريد الإلكتروني', 'Email'),
                          subtitle: s.t('رمز بالبريد', 'Code by email'),
                          onTap: () => _switchChannel(AuthChannel.email),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Entrance(
                    delayMs: 130,
                    // Rebuilt from scratch (not just its content swapped) on
                    // every channel switch, via the `ValueKey` — the two
                    // channels are different fields with different
                    // formatters and keyboards, not the same field relabelled.
                    child: _channel == AuthChannel.phone
                        ? AuthFieldRow(
                            key: const ValueKey('phone'),
                            icon: LucideIcons.smartphone,
                            label: s.t('رقم الهاتف', 'Phone number'),
                            hint: '9200 1234',
                            prefix: '+968 ',
                            controller: _phone,
                            error: _currentFieldError,
                            keyboardType: TextInputType.phone,
                            numeric: true,
                            forceLtr: true,
                            autofocus: true,
                            readOnly: _otpSent,
                            formatters: const [OmanMobileFormatter()],
                            onChanged: (_) => _clearFieldError('phone'),
                          )
                        : AuthFieldRow(
                            key: const ValueKey('email'),
                            icon: LucideIcons.mail,
                            label: s.t('البريد الإلكتروني', 'Email'),
                            hint: 'name@example.om',
                            controller: _email,
                            error: _currentFieldError,
                            keyboardType: TextInputType.emailAddress,
                            autofocus: true,
                            readOnly: _otpSent,
                            onChanged: (_) => _clearFieldError('email'),
                          ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: !_otpSent
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: AuthOtpBlock(
                              sent: true,
                              controller: _otp,
                              target: _identifier,
                              error: _errors['otp'],
                              resendIn: _resendIn,
                              onSend: _sendCode,
                              onChanged: (_) => _clearFieldError('otp'),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Entrance(
                    delayMs: 160,
                    child: AuthNoticeCard(
                      icon: LucideIcons.shieldCheck,
                      background: ak.amberBgSoft,
                      foreground: ak.amberText,
                      message: s.t(
                        'حسابك — وما يظهر لك فيه — يبقى كما سجّلته: عميل أو ورشة.',
                        'Your account — and what you see in it — stays exactly as you registered it: customer or workshop.',
                      ),
                    ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: _sending || _verifying
                        ? null
                        : (_otpSent ? _verify : _sendCode),
                    child: (_sending || _verifying)
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: ak.onPrimary),
                          )
                        : Text(_otpSent
                            ? s.t('تأكيد ودخول', 'Verify and log in')
                            : s.t('إرسال الرمز', 'Send the code')),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => context.pushReplacement('/register'),
                    icon: const Icon(LucideIcons.userPlus, size: 15),
                    label: Text(s.t('جديد على AK Cars؟ أنشئ حساباً',
                        'New to AK Cars? Create an account')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
