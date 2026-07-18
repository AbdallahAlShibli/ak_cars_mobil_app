import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Rounded white surface card used across the app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.card,
    this.border,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: border,
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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

/// Squircle icon tile (brand / good / warm / bad / gray tints).
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.background = AppColors.brandSoft,
    this.foreground = AppColors.brand,
    this.size = 42,
    this.radius = 14,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: foreground, size: size * 0.5),
    );
  }
}

/// Small status pill, e.g. "In progress", "Held".
class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.label, {
    super.key,
    this.background = AppColors.brandSoft,
    this.foreground = AppColors.brandDark,
  });

  final String label;
  final Color background;
  final Color foreground;

  const StatusBadge.good(this.label, {super.key})
      : background = AppColors.goodSoft,
        foreground = AppColors.good;

  const StatusBadge.warn(this.label, {super.key})
      : background = AppColors.amberSoft,
        foreground = AppColors.amberText;

  const StatusBadge.bad(this.label, {super.key})
      : background = AppColors.badSoft,
        foreground = AppColors.bad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Selectable filter chip in the app's visual language.
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
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? Colors.white : AppColors.ink2),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink2,
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
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
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
              colors: const [
                Color(0xFFE4E9F0),
                Color(0xFFF3F6FA),
                Color(0xFFE4E9F0),
              ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 17, color: AppColors.amberText),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7C5205),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
