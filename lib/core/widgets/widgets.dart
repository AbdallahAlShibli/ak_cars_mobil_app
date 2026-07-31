import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Rounded surface card used across the app. Colors resolve from the
/// theme-aware [AkColors] (light "Sand" / dark "Ink") unless overridden.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.color,
    this.border,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color ?? ak.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        // Sand & Ink: cards read as flat surfaces with a 1px border.
        border: border ?? Border.all(color: ak.border),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: card,
    );
  }
}

/// Squircle icon tile. Defaults to the dim-surface tint of the active theme.
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.background,
    this.foreground,
    this.size = 42,
    this.radius = 14,
  });

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? ak.surfaceDim,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: foreground ?? ak.ink, size: size * 0.5),
    );
  }
}

enum _BadgeVariant { neutral, good, warn, bad }

/// Small status pill, e.g. "In progress", "Held".
class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.label, {
    super.key,
    this.background,
    this.foreground,
  }) : _variant = _BadgeVariant.neutral;

  const StatusBadge.good(this.label, {super.key})
      : background = null,
        foreground = null,
        _variant = _BadgeVariant.good;

  const StatusBadge.warn(this.label, {super.key})
      : background = null,
        foreground = null,
        _variant = _BadgeVariant.warn;

  const StatusBadge.bad(this.label, {super.key})
      : background = null,
        foreground = null,
        _variant = _BadgeVariant.bad;

  final String label;
  final Color? background;
  final Color? foreground;
  final _BadgeVariant _variant;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final (bg, fg) = switch (_variant) {
      _BadgeVariant.neutral => (ak.surfaceDim, ak.ink),
      _BadgeVariant.good => (ak.successSoft, ak.success),
      _BadgeVariant.warn => (ak.amberSoft, ak.amberText),
      _BadgeVariant.bad => (ak.dangerSoft, ak.dangerText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground ?? fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Selectable filter chip — Sand & Ink: selected = ink pill (inverted in
/// dark), unselected = bordered surface.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? ak.primary : ak.surface,
          border: selected ? null : Border.all(color: ak.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13, color: selected ? ak.onPrimary : ak.inkSub),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? ak.onPrimary : ak.inkSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title row with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: context.text.cardTitle)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: context.text.labelStrong.copyWith(color: ak.ink),
            ),
          ),
      ],
    );
  }
}

/// Shimmering skeleton block — the "app feels fast" loading state.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 10});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = ak.surfaceDim;
    final glow = Color.lerp(base, Colors.white, dark ? 0.07 : 0.5)!;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _c.value, 0),
              end: Alignment(1 + 2 * _c.value, 0),
              colors: [base, glow, base],
            ),
          ),
        );
      },
    );
  }
}

/// Staggered entrance: fades + slides a child in after [delayMs].
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.delayMs = 0});

  final Widget child;
  final int delayMs;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      offset: _in ? Offset.zero : const Offset(0, 0.08),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        opacity: _in ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

/// Escrow notice banner (amber).
class EscrowBanner extends StatelessWidget {
  const EscrowBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ak.amberSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.lock, size: 16, color: ak.amberText),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ak.amberDeep,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
