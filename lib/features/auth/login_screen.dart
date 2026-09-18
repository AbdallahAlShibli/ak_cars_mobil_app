import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/app_exception.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import 'auth_form_widgets.dart';

/// Sign back in to an account that already registered.
///
/// Registration and login used to be the same screen wearing two hats — a
/// returning user retyped their name, address and governorate just to prove
/// they were still themselves. This screen asks for exactly one thing: the
/// phone number the account was registered with. Prove it with the code the
/// API texts to it and the session starts with everything already on file,
/// [AccountKind] and all — the profile decides what the rest of the app shows,
/// this screen only decides *whose* profile that is.
///
/// Phone only, for now. Email sign-in was offered beside it, but the API has
/// no e-mail sender, so a code "sent" to an address never arrived.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// How long before "resend" becomes available again.
  static const _resendSeconds = 30;

  final _phone = TextEditingController();
  final _otp = TextEditingController();

  bool _sending = false;
  bool _otpSent = false;
  bool _verifying = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  /// Field key ('phone' | 'otp') → message, shown under the offending row —
  /// same map shape the register screen uses.
  final _errors = <String, String>{};

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  /// The number a code is sent to and matched against, as accounts store it.
  /// Never the raw field text, so an unformatted phone can't silently reach
  /// the repository.
  String get _identifier => AuthPhone.full(AuthPhone.local(_phone.text));

  void _clearFieldError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  // ---------------------------------------------------------------- OTP

  Future<void> _sendCode() async {
    final s = S.of(context);
    // A resend from the code step reports under the code: the phone field is
    // not on screen there.
    final errorKey = _otpSent ? 'otp' : 'phone';
    final invalid = AuthPhone.error(s, _phone.text);
    if (invalid != null) {
      HapticFeedback.heavyImpact();
      setState(() => _errors[errorKey] = invalid);
      return;
    }

    final identifier = _identifier;
    setState(() {
      _sending = true;
      _errors.remove(errorKey);
    });
    try {
      final found = await ref
          .read(authProvider.notifier)
          .requestOtp(identifier);
      if (!mounted) return;
      if (!found) {
        HapticFeedback.heavyImpact();
        setState(
          () => _errors[errorKey] = s.t(
            'لا يوجد حساب بهذا الرقم',
            'No account with that number',
          ),
        );
        return;
      }

      HapticFeedback.mediumImpact();
      setState(() {
        _otpSent = true;
        _otp.clear();
        _errors.remove('otp');
      });
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t(
              'أُرسل الرمز عبر SMS إلى $identifier',
              'Code sent by SMS to $identifier',
            ),
          ),
        ),
      );
    } on AppException catch (error) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _errors[errorKey] = authSendCodeMessage(s, error));
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
    final code = _otp.text.trim();
    // Only the shape is checked here. Whether the code is right is the API's
    // to say; anything stricter would reject a genuine code before it was
    // ever tried.
    if (code.length != authCodeLength) {
      HapticFeedback.heavyImpact();
      setState(
        () => _errors['otp'] = s.t(
          'أدخل الرمز المكوّن من $authCodeLength أرقام',
          'Enter the $authCodeLength-digit code',
        ),
      );
      return;
    }

    setState(() => _verifying = true);
    try {
      await ref.read(authProvider.notifier).login(_identifier, code);
      if (!mounted) return;
      _welcomeBack(s);
    } on AppException catch (error) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _errors['otp'] = _verifyMessage(s, error));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Leaves the screen once a session has started.
  void _welcomeBack(S s) {
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
  }

  /// What to put under the code field when verification fails.
  ///
  /// Every one of these used to read "could not log in — try again", which is
  /// the least useful thing the screen could say: it gives a person who
  /// mistyped one digit no reason to look at what they typed, and a person
  /// who has burned all five attempts no reason to ask for a new code.
  String _verifyMessage(S s, AppException error) => switch (error) {
    // The account went away between the send and the code.
    NotFoundException() => s.t(
      'لا يوجد حساب بهذا الرقم',
      'No account with that number',
    ),
    _ => authVerifyCodeMessage(
      s,
      error,
      fallback: s.t(
        'تعذّر تسجيل الدخول — حاول مرة أخرى',
        'Could not log in — try again',
      ),
    ),
  };

  /// Back out of the code step to correct the number it was sent to.
  ///
  /// The phone field used to stay on screen, locked (`readOnly`), with no way
  /// to unlock it — a mistyped digit meant leaving the screen and coming back.
  /// Now the field is replaced by a summary of where the code went, and this
  /// is the way back to it.
  void _editIdentifier() {
    HapticFeedback.selectionClick();
    _resendTimer?.cancel();
    setState(() {
      _otpSent = false;
      _resendIn = 0;
      _otp.clear();
      _errors.remove('otp');
    });
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final busy = _sending || _verifying;

    return Scaffold(
      backgroundColor: ak.bg,
      body: Column(
        children: [
          _LoginHero(
            onBack: () => context.pop(),
            title: s.t('تسجيل الدخول', 'Log in'),
            subtitle: _otpSent
                ? s.t(
                    'أدخل الرمز المكوّن من $authCodeLength أرقام الذي أرسلناه إليك.',
                    'Enter the $authCodeLength-digit code we just sent you.',
                  )
                : s.t(
                    'أدخل رقم هاتفك المسجّل، وسنرسل لك رمزاً لمرة واحدة.',
                    "Enter your registered phone number, and we'll text you a one-time code.",
                  ),
          ),
          // Centred rather than top-aligned. The form is short, and pinning it
          // directly under the header left a wall of empty sand between it and
          // the button — which read as a screen that had not finished loading.
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _otpSent ? _codeStep(ak, s) : _identifierStep(ak, s),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: busy ? null : (_otpSent ? _verify : _sendCode),
                    child: busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: ak.onPrimary,
                            ),
                          )
                        : Text(
                            _otpSent
                                ? s.t('تأكيد ودخول', 'Verify and log in')
                                : s.t('إرسال الرمز', 'Send the code'),
                          ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.pushReplacement('/register'),
                    icon: const Icon(LucideIcons.userPlus, size: 15),
                    label: Text(
                      s.t(
                        'جديد على AK Cars؟ أنشئ حساباً',
                        'New to AK Cars? Create an account',
                      ),
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

  /// Step one: the phone number.
  Widget _identifierStep(AkColors ak, S s) => Column(
    key: const ValueKey('identifier'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Entrance(
        child: Text(
          s.t('سنرسل الرمز في رسالة SMS', "We'll text the code by SMS"),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: ak.inkFaint,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Entrance(
        delayMs: 40,
        child: AuthFieldRow(
          icon: LucideIcons.smartphone,
          label: s.t('رقم الهاتف', 'Phone number'),
          hint: '9200 1234',
          prefix: '+968 ',
          controller: _phone,
          error: _errors['phone'],
          keyboardType: TextInputType.phone,
          numeric: true,
          forceLtr: true,
          autofocus: true,
          formatters: const [OmanMobileFormatter()],
          onChanged: (_) => _clearFieldError('phone'),
        ),
      ),
      const SizedBox(height: 10),
      Entrance(
        delayMs: 120,
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
  );

  /// Step two: the code, and nothing else.
  ///
  /// The gate notice is deliberately gone here —
  /// there is exactly one thing to do on this step, and the address the code
  /// went to is the only context needed to do it.
  Widget _codeStep(AkColors ak, S s) => Column(
    key: const ValueKey('code'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Entrance(
        child: _SentToCard(target: _identifier, onEdit: _editIdentifier),
      ),
      const SizedBox(height: 18),
      Entrance(
        delayMs: 60,
        child: AuthOtpBoxes(
          controller: _otp,
          length: authCodeLength,
          error: _errors['otp'],
          onChanged: (_) => _clearFieldError('otp'),
        ),
      ),
      const SizedBox(height: 6),
      // One centred element, not a label beside a button: the Arabic
      // countdown is half again as long as the English one, and a Row
      // holding both overflowed on a 402pt screen.
      Entrance(
        delayMs: 100,
        child: Center(
          child: _resendIn > 0
              ? Text(
                  s.t(
                    'يمكنك طلب رمز جديد خلال $_resendIn ثانية',
                    'You can ask for a new code in ${_resendIn}s',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: ak.inkFaint),
                )
              : TextButton.icon(
                  onPressed: _sending ? null : _sendCode,
                  icon: const Icon(LucideIcons.rotateCw, size: 15),
                  label: Text(
                    s.t('لم يصلك الرمز؟ أعد الإرسال', "Didn't get it? Resend"),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
        ),
      ),
    ],
  );
}

/// Where the code went, plus the way back to change it.
class _SentToCard extends StatelessWidget {
  const _SentToCard({required this.target, required this.onEdit});

  final String target;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ak.border),
      ),
      child: Row(
        children: [
          MirroredIcon(
            LucideIcons.sendHorizontal,
            size: 18,
            color: ak.inkFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('أُرسل الرمز إلى', 'Code sent to'),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: ak.inkFaint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // A phone number is never Arabic-ordered.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    target,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.numeric(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: ak.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: Text(
              s.t('تغيير', 'Change'),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ink gradient cap over the form.
///
/// The screen used to be one flat sheet of sand — a brand tile, a title, a
/// subtitle and the fields, all the same colour, all stacked from the top,
/// with the button marooned at the bottom of a lot of nothing. The tile was
/// not even the 56px it asked for: inside a `ListView` the cross-axis
/// constraint is tight, so `Container(width: 56)` stretched into a full-width
/// black bar. Capping the screen in ink gives the title somewhere to sit and
/// the form somewhere to start.
class _LoginHero extends StatelessWidget {
  const _LoginHero({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Stack(
          children: [
            // Soft off-canvas disc — the one thing keeping the panel from
            // reading as a plain black rectangle.
            PositionedDirectional(
              top: -48,
              end: -36,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _HeroBackButton(onTap: onBack),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Entrance(
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: const Icon(
                              LucideIcons.keyRound,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Entrance(
                                delayMs: 40,
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Entrance(
                                delayMs: 80,
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.5,
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `SandBackButton` in reverse: white on ink.
///
/// The sand chip that widget draws is `ak.surface`, which is dark in the Ink
/// theme — on a header that is the same dark gradient in *both* themes, it
/// would disappear into its own background.
class _HeroBackButton extends StatefulWidget {
  const _HeroBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HeroBackButton> createState() => _HeroBackButtonState();
}

class _HeroBackButtonState extends State<_HeroBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        // Keeps a 44px tap target without growing the 38px visual.
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Icon(
                rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
