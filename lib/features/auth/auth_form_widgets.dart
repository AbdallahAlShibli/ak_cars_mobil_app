import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/i18n/strings.dart';

/// Shared building blocks for the auth screens (login, register, the
/// welcome gate) — one look for "enter a code", "type your phone", and
/// "here's why we're asking", so the three screens read as one flow rather
/// than three separately designed forms.

/// Which contact detail a form is currently keyed on — a customer's phone
/// or their email, whichever they typed or picked. Both the register and
/// login screens use this to decide which field to show and how to build
/// the address a code gets sent to.
enum AuthChannel { phone, email }

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
    final typedBefore =
        newValue.text.substring(0, caret).replaceAll(RegExp(r'\D'), '').length;
    final keptBefore = math.max(0, math.min(typedBefore - dropped, local.length));
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
  static String grouped(String local) =>
      local.length > 4 ? '${local.substring(0, 4)} ${local.substring(4)}' : local;

  /// Full E.164-ish phone as stored and displayed.
  static String full(String local) => '+968 ${grouped(local)}';
}

/// The phone-vs-email choice, as one sliding segmented control.
///
/// Was a pair of side-by-side cards, each carrying an icon, a title and a
/// subtitle of its own. Two cards is what you build when either option might
/// need explaining; this is one control with a thumb that moves, which is
/// what a binary choice actually is. It costs about a third of the height,
/// and that is what lets the field it governs sit above the fold with it.
class AuthChannelSwitch extends StatelessWidget {
  const AuthChannelSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AuthChannel value;
  final ValueChanged<AuthChannel> onChanged;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ak.border),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          // Expand, so the thumb fills the track's height and the segment
          // labels centre against it instead of hugging the top.
          fit: StackFit.expand,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              // Directional: under RTL the row of segments flips, and the
              // thumb has to start on the same side the first one does.
              alignment: value == AuthChannel.phone
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.centerEnd,
              child: Container(
                width: c.maxWidth / 2,
                height: c.maxHeight,
                decoration: BoxDecoration(
                  color: ak.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: ak.primary.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _ChannelSegment(
                  icon: LucideIcons.smartphone,
                  label: s.t('رقم الهاتف', 'Phone'),
                  selected: value == AuthChannel.phone,
                  onTap: () => onChanged(AuthChannel.phone),
                ),
                _ChannelSegment(
                  icon: LucideIcons.mail,
                  label: s.t('البريد الإلكتروني', 'Email'),
                  selected: value == AuthChannel.email,
                  onTap: () => onChanged(AuthChannel.email),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelSegment extends StatelessWidget {
  const _ChannelSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final fg = selected ? ak.onPrimary : ak.inkSub;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                        size: 13.5, weight: FontWeight.w700, color: ak.inkSub),
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
                    inputFormatters: formatters ??
                        (numeric
                            ? [FilteringTextInputFormatter.digitsOnly]
                            : null),
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
                      hintTextDirection: forceLtr ? TextDirection.ltr : null,
                      hintStyle: TextStyle(
                          fontSize: 13,
                          color: ak.inkFaint,
                          fontWeight: FontWeight.w500),
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
                                  right: i == length - 1 ? 0 : 10),
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
        border:
            Border.all(color: borderColor, width: active || filled ? 2 : 1.5),
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
        style:
            AppTheme.numeric(size: 24, weight: FontWeight.w800, color: ak.ink),
      ),
    );
  }
}
