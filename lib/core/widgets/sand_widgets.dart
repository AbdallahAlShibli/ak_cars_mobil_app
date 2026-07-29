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
///
/// This is the single back affordance for the whole app: screens with a
/// [SandHeader] get it inline, and every Material [AppBar] gets it through
/// `ActionIconThemeData.backButtonIconBuilder` (see `AppTheme`), so plain
/// `AppBar(...)` screens never fall back to the stock Material arrow.
class SandBackButton extends StatefulWidget {
  const SandBackButton({
    super.key,
    this.onTap,
    this.translucent = false,
    this.size = 38,
  }) : _decorative = false;

  /// Presentation-only variant used where the tap is handled by a parent
  /// (e.g. the [IconButton] Material builds for an `AppBar` leading).
  const SandBackButton.icon({super.key, this.translucent = false, this.size = 34})
      : onTap = null,
        _decorative = true;

  final VoidCallback? onTap;

  /// Sits on top of a photo/hero — uses a scrim instead of the flat surface
  /// so the chevron stays readable over any image.
  final bool translucent;

  final double size;

  final bool _decorative;

  @override
  State<SandBackButton> createState() => _SandBackButtonState();
}

class _SandBackButtonState extends State<SandBackButton> {
  bool _pressed = false;

  void _back() {
    HapticFeedback.selectionClick();
    (widget.onTap ?? () => Navigator.of(context).maybePop())();
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final chip = AnimatedScale(
      scale: _pressed ? 0.9 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.translucent
              ? ak.surface.withValues(alpha: 0.86)
              : ak.surface,
          shape: BoxShape.circle,
          border: Border.all(color: ak.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
          size: widget.size * 0.47,
          color: ak.ink,
        ),
      ),
    );

    // Decorative: the surrounding IconButton owns the gesture, tooltip and
    // semantics — wrapping it again would announce the button twice.
    if (widget._decorative) return chip;

    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: _back,
        // Keeps a 44px tap target without growing the 38px visual.
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: chip,
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
    this.animate = false,
  });

  final double value;
  final Color color;
  final double height;

  /// Fill from empty on first build, and glide between values afterwards.
  ///
  /// Opt-in rather than always on: on a page that lists a dozen countdowns the
  /// bars are reference information, and twelve of them growing at once reads
  /// as a loading state. It is the home page's single headline bar that earns
  /// the movement.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final target = value.clamp(0.0, 1.0);
    Widget fill(double v) => FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: ak.surfaceDim),
            if (animate)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: target),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => fill(v),
              )
            else
              fill(target),
          ],
        ),
      ),
    );
  }
}

/// Wraps a tappable card so it dips under the finger.
///
/// The same 110ms scale the back button uses, factored out because the home
/// page's cards are large enough that a tap with no feedback at all reads as a
/// dead surface — [SandCard]'s own `onTap` gives haptics but no movement.
class SandPressable extends StatefulWidget {
  const SandPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<SandPressable> createState() => _SandPressableState();
}

class _SandPressableState extends State<SandPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
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
  const SandHeader(
    this.title, {
    super.key,
    this.trailing,
    this.onBack,
    this.showBack = true,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  /// Set false on a screen that is the root of a navigation branch. The back
  /// button falls through to `maybePop()`, which has nothing to pop on a tab
  /// root — so it would render a control that does nothing when tapped.
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack) ...[
          SandBackButton(onTap: onBack),
          const SizedBox(width: 10),
        ],
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
