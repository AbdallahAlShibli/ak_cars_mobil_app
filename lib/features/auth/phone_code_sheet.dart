import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/error/app_exception.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/phone_verification_service.dart';
import '../../di/providers.dart';
import 'auth_form_widgets.dart';

/// What to tell someone whose SMS phone verification failed.
///
/// Worded around what they can do next. A mistyped code and an expired one
/// are told apart because Firebase tells them apart, unlike the API's own
/// codes, which deliberately collapse both into `otp_invalid_or_expired`.
String phoneVerificationMessage(S s, PhoneVerificationException error) {
  final message = _friendlyMessage(s, error);
  // The friendly sentence covers several Firebase causes (billing off, region
  // blocked, build not registered); only Firebase's own code says which, and
  // a debug build is where someone who can fix it is looking.
  return kDebugMode && error.reason == PhoneVerificationFailure.notConfigured
      ? '$message\n${error.message}'
      : message;
}

String _friendlyMessage(S s, PhoneVerificationException error) =>
    switch (error.reason) {
      PhoneVerificationFailure.notConfigured => s.t(
        'تسجيل الدخول برسالة SMS غير مُفعّل لهذا التطبيق بعد',
        "SMS sign-in isn't set up for this app yet",
      ),
      PhoneVerificationFailure.invalidCode => s.t(
        'الرمز غير صحيح — تحقّق منه وأعد المحاولة',
        'That code is not right — check it and try again',
      ),
      PhoneVerificationFailure.codeExpired => s.t(
        'انتهت صلاحية الرمز — اطلب رمزاً جديداً',
        'That code has expired — ask for a new one',
      ),
      PhoneVerificationFailure.invalidPhoneNumber => s.t(
        'لا يمكن إرسال رسالة إلى هذا الرقم',
        'A text message cannot be sent to that number',
      ),
      PhoneVerificationFailure.tooManyRequests => s.t(
        'محاولات كثيرة من هذا الجهاز — انتظر قليلاً ثم أعد المحاولة',
        'Too many attempts from this device — wait a while, then try again',
      ),
      PhoneVerificationFailure.network => s.t(
        'تعذّر الاتصال — تحقّق من اتصالك',
        'Could not connect — check your connection',
      ),
      PhoneVerificationFailure.unavailable => s.t(
        'التحقق برسالة SMS غير متاح حالياً — حاول لاحقاً',
        'SMS verification is not available right now — try again later',
      ),
      PhoneVerificationFailure.cancelled => s.t(
        'أُلغي التحقق',
        'Verification was cancelled',
      ),
      PhoneVerificationFailure.unknown => s.t(
        'تعذّر التحقق من الرقم — حاول مرة أخرى',
        'Could not verify the number — try again',
      ),
    };

/// Asks for the SMS code sent for [session] and returns the Firebase ID token
/// once the code is right. Null when the sheet is closed without confirming.
///
/// A session the platform already verified (Android instant verification)
/// never shows the sheet: there is nothing left to type.
Future<String?> showPhoneCodeSheet(
  BuildContext context, {
  required PhoneVerificationSession session,
}) {
  final alreadyVerified = session.idToken;
  if (alreadyVerified != null) return Future.value(alreadyVerified);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => PhoneCodeSheet(session: session),
  );
}

/// The code step as a sheet over a long form, so the form keeps everything
/// that was typed into it while the code is entered.
class PhoneCodeSheet extends ConsumerStatefulWidget {
  const PhoneCodeSheet({super.key, required this.session});

  final PhoneVerificationSession session;

  @override
  ConsumerState<PhoneCodeSheet> createState() => _PhoneCodeSheetState();
}

class _PhoneCodeSheetState extends ConsumerState<PhoneCodeSheet> {
  static const _codeLength = 6;
  static const _resendSeconds = 30;

  late PhoneVerificationSession _session = widget.session;
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
    if (code.length != _codeLength) {
      HapticFeedback.heavyImpact();
      setState(() => _error = s.t(
        'أدخل الرمز المكوّن من 6 أرقام',
        'Enter the 6-digit code',
      ));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(phoneVerificationServiceProvider)
          .confirmCode(_session, code);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(token);
    } on PhoneVerificationException catch (error) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _error = phoneVerificationMessage(s, error));
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
      final session = await ref
          .read(phoneVerificationServiceProvider)
          .sendCode(_session.phone);
      if (!mounted) return;
      final alreadyVerified = session.idToken;
      if (alreadyVerified != null) {
        Navigator.of(context).pop(alreadyVerified);
        return;
      }
      setState(() => _session = session);
      _startResendCountdown();
    } on PhoneVerificationException catch (error) {
      if (!mounted) return;
      setState(() => _error = phoneVerificationMessage(s, error));
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
              'أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه برسالة SMS إلى',
              'Enter the 6-digit code we texted to',
            ),
            style: TextStyle(fontSize: 12.5, height: 1.5, color: ak.inkFaint),
          ),
          // A phone number reads left-to-right in either language.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              _session.phone,
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
            length: _codeLength,
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
                      s.t('لم يصلك الرمز؟ أعد الإرسال', "Didn't get it? Resend"),
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