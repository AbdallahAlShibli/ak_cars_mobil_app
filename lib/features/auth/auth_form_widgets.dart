import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/error/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/i18n/strings.dart';

/// Shared building blocks for the auth screens (login, register, the
/// welcome gate) — one look for "enter a code", "type your phone", and
/// "here's why we're asking", so the three screens read as one flow rather
/// than three separately designed forms.

/// Keeps a phone field holding exactly the 8 local Oman digits, shown as
/// "9200 1234".
///
/// Typing is only half of it — people paste. "+968 9200 1234", "00968…",
/// "096892001234" and "9200-1234" all reduce to the same eight digits here
/// rather than failing validation for a reason the user can't see.
class OmanMobileFormatter extends TextInputFormatter {
  const OmanMobileFormatter();

  static const _maxLocalDigits = 8;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final all = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Digits dropped off the front, so the caret can be moved back by the
    // same amount instead of jumping.
    var dropped = 0;
    var local = all;
    if (local.startsWith('00968')) {
      local = local.substring(5);
      dropped = 5;
    } else if (local.startsWith('968')) {
      local = local.substring(3);
      dropped = 3;
    }
    while (local.startsWith('0')) {
      local = local.substring(1);
      dropped += 1;
    }
    if (local.length > _maxLocalDigits) {
      local = local.substring(0, _maxLocalDigits);
    }

    final text = local.length > 4
        ? '${local.substring(0, 4)} ${local.substring(4)}'
        : local;

    // A collapsed caret reports end == -1 before the field has focus.
    final caret = newValue.selection.end < 0
        ? newValue.text.length
        : math.min(newValue.selection.end, newValue.text.length);
    final typedBefore = newValue.text
        .substring(0, caret)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    final keptBefore = math.max(
      0,
      math.min(typedBefore - dropped, local.length),
    );
    final offset = keptBefore > 4 ? keptBefore + 1 : keptBefore;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Oman-local phone digits, so "+968 9200 1234", "96892001234" and
/// "9200 1234" all compare/format equal. Shared by every screen that
/// collects or matches a phone number.
abstract final class AuthPhone {
  static String digits(String v) => v.replaceAll(RegExp(r'\D'), '');

  static String local(String v) {
    final d = digits(v);
    return d.startsWith('968') ? d.substring(3) : d;
  }

  /// The 8 local digits split "9200 1234" for reading.
  static String grouped(String local) => local.length > 4
      ? '${local.substring(0, 4)} ${local.substring(4)}'
      : local;

  /// Full E.164-ish phone as stored and displayed.
  static String full(String local) => '+968 ${grouped(local)}';

  /// Why [text] cannot be texted a code, or null when it can. One rule for
  /// login and registration, the same one the API applies.
  static String? error(S s, String text) {
    final local = AuthPhone.local(text);
    if (local.isEmpty) {
      return s.t('رقم الهاتف مطلوب', 'Phone number is required');
    }
    if (local.length != 8) {
      return s.t('رقم عُماني من 8 أرقام', 'An 8-digit Oman number');
    }
    // The code arrives by SMS, so a landline (2x) cannot receive it.
    if (!RegExp(r'^[79]').hasMatch(local)) {
      return s.t(
        'رقم هاتف نقّال عُماني يبدأ بـ 7 أو 9',
        'An Oman mobile number starting with 7 or 9',
      );
    }
    return null;
  }
}

/// The length of every code the API texts, for login and registration alike.
const authCodeLength = 4;

/// What to say when a code could not be sent.
///
/// Both send endpoints are capped per IP (they spend money on SMS), so "try
/// again" is actively wrong advice for a rate limit: trying again immediately
/// is the one thing guaranteed to fail.
String authSendCodeMessage(S s, AppException error) => switch (error) {
  // The per-phone cap: an hour, not a minute, so the advice says so.
  RateLimitedException(code: 'otp_too_many_requests') => s.t(
    'أُرسلت رموز كثيرة لهذا الرقم — حاول بعد ساعة',
    'Too many codes sent to this number — try again in an hour',
  ),
  RateLimitedException() => s.t(
    'طلبات كثيرة — انتظر دقيقة ثم أعد المحاولة',
    'Too many requests — wait a minute and try again',
  ),
  NetworkException() || RequestTimeoutException() => s.t(
    'تعذّر الوصول إلى الخادم — تحقّق من اتصالك',
    'Could not reach the server — check your connection',
  ),
  // The API reached its SMS gateway and the gateway would not take the
  // message. Nothing the user typed is wrong, and nothing they can do fixes
  // it — so the copy does not tell them to check the number or try harder.
  ApiException(errorCode: 'sms_send_failed') => s.t(
    'تعذّر إرسال الرسالة من مزوّد الرسائل — حاول بعد قليل',
    "Our SMS provider wouldn't send the message — try again shortly",
  ),
  // Anything else 5xx: the server, not the send. Told apart from the line
  // above because they are fixed in different places.
  ApiException(isServerError: true) => s.t(
    'خادمنا لا يستجيب الآن — حاول بعد قليل',
    "Our server isn't responding — try again shortly",
  ),
  _ => s.t(
    'تعذّر إرسال الرمز — حاول مرة أخرى',
    'Could not send the code — try again',
  ),
};

/// What to say when a typed code was not accepted.
///
/// The server deliberately does not tell "wrong" from "expired" from "too
/// many attempts": all three answer `otp_invalid_or_expired`, so a guesser
/// cannot learn whether a code was ever right. This copy names the two things
/// the user can act on without claiming to know which one happened.
String authVerifyCodeMessage(
  S s,
  AppException error, {
  required String fallback,
}) => switch (error) {
  UnauthorizedException(code: 'otp_invalid_or_expired') => s.t(
    'الرمز غير صحيح أو انتهت صلاحيته — اطلب رمزاً جديداً',
    'That code is wrong or has expired — request a new one',
  ),
  RateLimitedException() => s.t(
    'محاولات كثيرة — انتظر دقيقة ثم أعد المحاولة',
    'Too many attempts — wait a minute and try again',
  ),
  NetworkException() || RequestTimeoutException() => s.t(
    'تعذّر الوصول إلى الخادم — تحقّق من اتصالك',
    'Could not reach the server — check your connection',
  ),
  ApiException(isServerError: true) => s.t(
    'خادمنا لا يستجيب الآن — حاول بعد قليل',
    "Our server isn't responding — try again shortly",
  ),
  _ => fallback,
};

/// Group label above a run of fields.
class AuthSectionLabel extends StatelessWidget {
  const AuthSectionLabel(this.text, {super.key});

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
class AuthNoticeCard extends StatelessWidget {
  const AuthNoticeCard({
    super.key,
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
class AuthFieldShell extends StatelessWidget {
  const AuthFieldShell({
    super.key,
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

/// Typed field with a floating label.
class AuthFieldRow extends StatelessWidget {
  const AuthFieldRow({
    super.key,
    required this.icon,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.prefix,
    this.error,
    this.optional = false,
    this.numeric = false,
    this.forceLtr = false,
    this.formatters,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.readOnly = false,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;

  /// Static leading text inside the field (e.g. the +968 dial code).
  final String? prefix;
  final String? error;
  final bool optional;
  final bool numeric;

  /// Renders the value row left-to-right whatever the app language is, for
  /// content that is never Arabic-ordered (dial code + digits).
  final bool forceLtr;

  /// Replaces the default digits-only filter when the field needs its own
  /// formatting rules.
  final List<TextInputFormatter>? formatters;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  /// Locks the field once its value has been acted on — e.g. the identifier
  /// a code was already sent to, so editing it silently would send the next
  /// code somewhere the on-screen "sent to" text no longer matches.
  final bool readOnly;

  Widget _maybeLtr(Widget child) => forceLtr
      ? Directionality(textDirection: TextDirection.ltr, child: child)
      : child;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final filled = controller.text.trim().isNotEmpty;
    return AuthFieldShell(
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
          _maybeLtr(
            Row(
              children: [
                if (prefix != null) ...[
                  Text(
                    prefix!,
                    style: AppTheme.numeric(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: ak.inkSub,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 15,
                    margin: const EdgeInsets.only(right: 8),
                    color: ak.divider,
                  ),
                ],
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    autofocus: autofocus,
                    readOnly: readOnly,
                    keyboardType: keyboardType,
                    textCapitalization: textCapitalization,
                    textDirection: forceLtr ? TextDirection.ltr : null,
                    textAlign: forceLtr ? TextAlign.left : TextAlign.start,
                    inputFormatters:
                        formatters ??
                        (numeric
                            ? [FilteringTextInputFormatter.digitsOnly]
                            : null),
                    style: numeric
                        ? AppTheme.numeric(size: 13.5, color: ak.ink)
                        : const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      hintText: hint,
                      hintTextDirection: forceLtr ? TextDirection.ltr : null,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: ak.inkFaint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one-time code, as one box per digit.
///
/// Was a single wide field with `letterSpacing: 10` faking the gaps. That
/// showed no progress: how many digits are wanted, and how many have landed,
/// could only be worked out by counting characters. Four boxes say both at a
/// glance, and the next one to fill is lit.
///
/// There is still exactly one real [TextField] behind them — an invisible one
/// stretched across the row — so paste, autofill and the OS one-time-code
/// suggestion all keep working, and the boxes are only a rendering of its
/// value.
class AuthOtpBoxes extends StatelessWidget {
  const AuthOtpBoxes({
    super.key,
    required this.controller,
    required this.onChanged,
    this.length = 4,
    this.error,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int length;
  final String? error;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final bad = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A code reads left-to-right in every language, so the first digit
        // stays leftmost even when the rest of the screen is mirrored.
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 62,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final digits = controller.text;
                    return Row(
                      children: [
                        for (var i = 0; i < length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: i == length - 1 ? 0 : 10,
                              ),
                              child: _OtpBox(
                                digit: i < digits.length ? digits[i] : '',
                                active: i == digits.length && !bad,
                                bad: bad,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                // Invisible, but still the real field: it owns focus, the
                // keyboard, paste and SMS autofill. `Opacity` rather than
                // `Visibility` — zero opacity still hit-tests, so a tap
                // anywhere across the boxes lands on it.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      autofocus: autofocus,
                      keyboardType: TextInputType.number,
                      maxLength: length,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      textAlign: TextAlign.center,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.transparent),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (bad)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
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
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.digit, required this.active, required this.bad});

  final String digit;
  final bool active;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final filled = digit.isNotEmpty;
    final borderColor = bad
        ? ak.danger
        : active
        ? ak.primary
        : filled
        ? ak.primary.withValues(alpha: 0.45)
        : ak.border;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: active || filled ? 2 : 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: ak.primary.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        digit,
        style: AppTheme.numeric(
          size: 24,
          weight: FontWeight.w800,
          color: ak.ink,
        ),
      ),
    );
  }
}
