import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/app_exception.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import 'auth_form_widgets.dart';

/// Asks for the registration code already texted to [phone] and returns the
/// phone verification token once the code is right. Null when the sheet is
/// closed without confirming.
///
/// The caller sends the first code (`AuthNotifier.requestRegistrationOtp`)
/// before opening this, so a number that already has an account is refused on
/// the form rather than inside a sheet waiting for a code that never comes.
Future<String?> showPhoneCodeSheet(
  BuildContext context, {
  required String phone,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => PhoneCodeSheet(phone: phone),
);

/// The registration code step as a sheet over the form, so the form keeps
/// everything that was typed into it while the code is entered.
class PhoneCodeSheet extends ConsumerStatefulWidget {
  const PhoneCodeSheet({super.key, required this.phone});

  /// As the account stores it: `+968 9200 1234`.
  final String phone;

  @override
  ConsumerState<PhoneCodeSheet> createState() => _PhoneCodeSheetState();
}

class _PhoneCodeSheetState extends ConsumerState<PhoneCodeSheet> {
  static const _resendSeconds = 30;

  final _code = TextEditingController();
  String? _error;
  bool _busy = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.dispose();
    super.dispose();
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

  Future<void> _confirm() async {
    final s = S.of(context);
    final code = _code.text.trim();
    if (code.length != authCodeLength) {
      HapticFeedback.heavyImpact();
      setState(
        () => _error = s.t(
          'أدخل الرمز المكوّن من $authCodeLength أرقام',
          'Enter the $authCodeLength-digit code',
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(authProvider.notifier)
          .verifyRegistrationOtp(widget.phone, code);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(token);
    } on AppException catch (error) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(
        () => _error = authVerifyCodeMessage(
          s,
          error,
          fallback: s.t(
            'تعذّر التحقق من الرقم — حاول مرة أخرى',
            'Could not verify the number — try again',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final s = S.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _code.clear();
    });
    try {
      await ref
          .read(authProvider.notifier)
          .requestRegistrationOtp(widget.phone);
      if (!mounted) return;
      _startResendCountdown();
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = authSendCodeMessage(s, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.smartphone, size: 20, color: ak.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.t('تأكيد رقم الهاتف', 'Confirm your phone number'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ak.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.t(
              'أدخل الرمز المكوّن من $authCodeLength أرقام الذي أرسلناه برسالة SMS إلى',
              'Enter the $authCodeLength-digit code we texted to',
            ),
            style: TextStyle(fontSize: 12.5, height: 1.5, color: ak.inkFaint),
          ),
          // A phone number reads left-to-right in either language.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              widget.phone,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: ak.ink,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AuthOtpBoxes(
            controller: _code,
            length: authCodeLength,
            error: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 6),
          Center(
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
                    onPressed: _busy ? null : _resend,
                    icon: const Icon(LucideIcons.rotateCw, size: 15),
                    label: Text(
                      s.t(
                        'لم يصلك الرمز؟ أعد الإرسال',
                        "Didn't get it? Resend",
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: ak.onPrimary,
                    ),
                  )
                : Text(s.t('تأكيد الرقم', 'Confirm number')),
          ),
        ],
      ),
    );
  }
}
