import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

/// Theme-aware Sand & Ink card: surface + 1px border, no heavy shadow.
class SandCard extends StatelessWidget {
  const SandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.color,
    this.border,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final BoxBorder? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? ak.surface,
        borderRadius: BorderRadius.circular(radius),
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

/// Ink pill button (primary action). Pressed state = slight fade.
class InkPill extends StatefulWidget {
  const InkPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.fontSize = 11,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  /// Outline variant (white bg, ink border) — e.g. "أضف سجلاً يدوياً".
  final bool outlined;

  @override
  State<InkPill> createState() => _InkPillState();
}

class _InkPillState extends State<InkPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final fg = widget.outlined ? ak.ink : ak.onPrimary;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _pressed ? 0.85 : 1,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.outlined ? ak.surface : ak.primary,
            borderRadius: BorderRadius.circular(999),
            border: widget.outlined
                ? Border.all(color: ak.ink, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.fontSize + 2, color: fg),
                const SizedBox(width: 6),
              ],
              // Flexible so a long label in a narrow column ellipsizes
              // instead of overflowing the pill.
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.fontSize,
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

/// Circular bordered back button (auto-mirrors for RTL).
class SandBackButton extends StatelessWidget {
  const SandBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: ak.surface,
          shape: BoxShape.circle,
          border: Border.all(color: ak.border),
        ),
        child: Icon(
          rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
          size: 17,
          color: ak.ink,
        ),
      ),
    );
  }
}

/// 6px rounded progress bar on a dim track.
class SandProgressBar extends StatelessWidget {
  const SandProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 6,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: ak.surfaceDim),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small colored status pill ("قريب", "بوضع جيد", "لا يوجد سجل"…).
class SandStatusPill extends StatelessWidget {
  const SandStatusPill(this.label,
      {super.key, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// Screen header: back button + 19px bold title (+ optional trailing).
class SandHeader extends StatelessWidget {
  const SandHeader(this.title, {super.key, this.trailing, this.onBack});

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SandBackButton(onTap: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Section title row ("الأكثر بحثاً" + "عرض الكل ›").
class SandSectionHeader extends StatelessWidget {
  const SandSectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              '$action ›',
              style: TextStyle(fontSize: 11, color: ak.inkSub),
            ),
          ),
      ],
    );
  }
}
