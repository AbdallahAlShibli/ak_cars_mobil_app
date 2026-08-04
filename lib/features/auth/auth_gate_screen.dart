import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';

/// Where any gated action or "complete your details" prompt lands first.
///
/// Used to drop a guest straight into the registration form — which quietly
/// assumed every visitor was new. A returning user who signed out, or who
/// switched phones, had no way back into their own account short of
/// registering a second time. This screen asks the one question that was
/// missing: is this an existing account, or a new one?
class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SandBackButton(onTap: () => context.pop()),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Anchored a third of the way down rather than dead
                      // center — on a tall phone, centering the whole
                      // column left a wall of empty space above the back
                      // button that read as an unfinished screen.
                      const SizedBox(height: AppSpacing.xxl),
                      Entrance(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(LucideIcons.carFront,
                              size: 32, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Entrance(
                        delayMs: 60,
                        child: Text(
                          s.t('حساب واحد لكل شيء', 'One account, everything'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Entrance(
                        delayMs: 100,
                        child: Text(
                          s.t(
                            'سجّل الدخول إن كان لديك حساب، أو أنشئ واحداً جديداً — كعميل أو كورشة.',
                            'Log in if you already have an account, or create a new one — as a customer or a workshop.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13.5, color: ak.inkSub, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Entrance(
                        delayMs: 150,
                        child: _GateOption(
                          icon: LucideIcons.logIn,
                          title: s.t('لديّ حساب', 'I have an account'),
                          subtitle: s.t('تسجيل الدخول برقم هاتفك أو بريدك',
                              'Log in with your phone or email'),
                          primary: true,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.pushReplacement('/login');
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Entrance(
                        delayMs: 200,
                        child: _GateOption(
                          icon: LucideIcons.userPlus,
                          title: s.t('حساب جديد', 'New here'),
                          subtitle: s.t('أنشئ حسابك في أقل من دقيقتين',
                              'Create your account in under two minutes'),
                          primary: false,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.pushReplacement('/register');
                          },
                        ),
                      ),
                    ],
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
            color: widget.primary ? ak.ink : ak.surface,
            borderRadius: BorderRadius.circular(20),
            border: widget.primary ? null : Border.all(color: ak.border),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: ak.ink.withValues(alpha: 0.18),
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
                      ? Colors.white.withValues(alpha: 0.16)
                      : ak.surfaceDim,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  size: 21,
                  color: widget.primary ? Colors.white : ak.ink,
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
                        color: widget.primary ? Colors.white : ak.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: widget.primary
                            ? Colors.white.withValues(alpha: 0.75)
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
                    ? Colors.white.withValues(alpha: 0.75)
                    : ak.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
