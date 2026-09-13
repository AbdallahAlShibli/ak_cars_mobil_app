import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/widgets.dart';

/// Which of the two doors the guest picked. Returned by the dialog rather
/// than navigated from inside it, so the closing animation and the push that
/// follows it never race each other.
enum _GateChoice { login, register }

/// Where any gated action or "complete your details" prompt lands first.
///
/// Used to drop a guest straight into the registration form — which quietly
/// assumed every visitor was new. A returning user who signed out, or who
/// switched phones, had no way back into their own account short of
/// registering a second time. This asks the one question that was missing:
/// is this an existing account, or a new one?
///
/// A dialog rather than a route: the question interrupts something the user
/// was already doing — adding a car, checking out, posting an ad — and a
/// whole page made it look like that task had been left behind. The blurred
/// backdrop keeps the original screen visible underneath, so the
/// interruption reads as temporary.
Future<void> showAuthGate(BuildContext context) async {
  // Captured before the await: once the dialog closes, the widget that owns
  // `context` may no longer be mounted.
  final router = GoRouter.of(context);

  final choice = await showGeneralDialog<_GateChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => const _AuthGateDialog(),
    transitionBuilder: (context, animation, _, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6 * t, sigmaY: 6 * t),
        child: Opacity(
          opacity: t,
          child: Transform.scale(
            // Settles down onto the screen from slightly larger, which reads
            // as the card coming forward rather than growing into place.
            scale: 0.94 + (0.06 * t),
            child: child,
          ),
        ),
      );
    },
  );

  if (choice == null) return;
  router.push(choice == _GateChoice.login ? '/login' : '/register');
}

class _AuthGateDialog extends StatelessWidget {
  const _AuthGateDialog();

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          // Keeps the card clear of a software keyboard on the rare short
          // screen where header plus both options do not fit above it.
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: ak.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: ak.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _DialogCloseButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(LucideIcons.carFront,
                          size: 29, color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      s.t('حساب واحد لكل شيء', 'One account, everything'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: ak.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.t(
                        'سجّل الدخول إن كان لديك حساب، أو أنشئ واحداً جديداً — كعميل أو كورشة.',
                        'Log in if you already have an account, or create a new one — as a customer or a workshop.',
                      ),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: ak.inkSub, height: 1.6),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Entrance(
                      delayMs: 60,
                      child: _GateOption(
                        icon: LucideIcons.logIn,
                        title: s.t('لديّ حساب', 'I have an account'),
                        subtitle: s.t('تسجيل الدخول برقم هاتفك أو بريدك',
                            'Log in with your phone or email'),
                        primary: true,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(_GateChoice.login);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Entrance(
                      delayMs: 110,
                      child: _GateOption(
                        icon: LucideIcons.userPlus,
                        title: s.t('حساب جديد', 'New here'),
                        subtitle: s.t('أنشئ حسابك في أقل من دقيقتين',
                            'Create your account in under two minutes'),
                        primary: false,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(_GateChoice.register);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogCloseButton extends StatelessWidget {
  const _DialogCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    return Semantics(
      button: true,
      label: s.t('إغلاق', 'Close'),
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(LucideIcons.x, size: 20, color: ak.inkFaint),
        ),
      ),
    );
  }
}

class _GateOption extends StatefulWidget {
  const _GateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  @override
  State<_GateOption> createState() => _GateOptionState();
}

class _GateOptionState extends State<_GateOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.98 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // `primary`/`onPrimary` invert together per theme — ink card with
            // cream text in light, cream card with ink text in dark. Reading
            // `ink` here instead paired a light dark-theme card with hardcoded
            // white text, which was unreadable.
            color: widget.primary ? ak.primary : ak.surface,
            borderRadius: BorderRadius.circular(20),
            border: widget.primary ? null : Border.all(color: ak.border),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.primary
                      ? ak.onPrimary.withValues(alpha: 0.12)
                      : ak.surfaceDim,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  size: 21,
                  color: widget.primary ? ak.onPrimary : ak.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: widget.primary ? ak.onPrimary : ak.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: widget.primary
                            ? ak.onPrimary.withValues(alpha: 0.75)
                            : ak.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? LucideIcons.chevronLeft
                    : LucideIcons.chevronRight,
                size: 20,
                color: widget.primary
                    ? ak.onPrimary.withValues(alpha: 0.75)
                    : ak.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
