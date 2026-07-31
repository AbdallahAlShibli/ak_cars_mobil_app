import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// How much attention a row is owed.
///
/// Three levels, not five: the eye can sort three things pre-attentively and
/// starts having to *read* at four. Anything that is merely informative is
/// [normal] — inflating it to [upcoming] to make it noticeable is how a page
/// ends up with nothing noticeable on it.
enum UrgencyLevel {
  /// Nothing is being asked of the user. No tint, plain border.
  normal,

  /// Coming due, or waiting on someone else. Amber.
  upcoming,

  /// Past due, or blocking. Red, with an icon.
  overdue,
}

/// The resolved appearance of an [UrgencyLevel] against the active theme.
///
/// Exposed separately from [UrgencyCard] so a widget that cannot use the card
/// shell — a compact list row, a pill, a tile — still takes its colors from
/// the same place rather than picking its own amber.
class UrgencyStyle {
  const UrgencyStyle({
    required this.edge,
    required this.tint,
    required this.text,
    this.icon,
  });

  /// The leading edge bar, and the border of a tinted card.
  final Color edge;

  /// Background wash. Transparent for [UrgencyLevel.normal].
  final Color tint;

  /// Foreground for the status word itself.
  final Color text;

  /// Only [UrgencyLevel.overdue] carries one — see [UrgencyCard].
  final IconData? icon;

  factory UrgencyStyle.of(BuildContext context, UrgencyLevel level) {
    final ak = AkColors.of(context);
    return switch (level) {
      UrgencyLevel.normal => UrgencyStyle(
          edge: ak.border,
          tint: Colors.transparent,
          text: ak.inkSub,
        ),
      UrgencyLevel.upcoming => UrgencyStyle(
          edge: ak.amber,
          tint: ak.amberBgSoft,
          text: ak.amberText,
        ),
      UrgencyLevel.overdue => UrgencyStyle(
          edge: ak.danger,
          tint: ak.dangerSoft,
          text: ak.dangerText,
          icon: LucideIcons.triangleAlert,
        ),
    };
  }
}

/// A card whose state is legible before a single word of it is.
///
/// The problem this solves: on the maintenance page an item that is *overdue*
/// and an item with 1,500 km left were the same white card with the same
/// border, and the only difference between them was the wording of a pill.
/// That makes the eye read every row to find the one row that matters.
///
/// So urgency is carried three ways at once — a colored leading edge, a
/// background tint, and (for overdue only) an icon. Any one of them alone is
/// missable: the edge is thin, the tint is subtle, and the icon is small. All
/// three together are not, and they still work for a user who cannot
/// distinguish the two colors, because the icon and the wording are still
/// there.
class UrgencyCard extends StatelessWidget {
  const UrgencyCard({
    super.key,
    required this.level,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.radius = 18,
  });

  final UrgencyLevel level;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  /// Width of the leading edge bar. Thin enough to read as an accent on the
  /// card rather than as a second column of content.
  static const _edgeWidth = 4.0;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final style = UrgencyStyle.of(context, level);
    final tinted = level != UrgencyLevel.normal;
    final border = BorderRadius.circular(radius);

    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tinted ? style.tint : ak.surface,
        borderRadius: border,
        border: Border.all(
          color: tinted ? style.edge.withValues(alpha: 0.45) : ak.border,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Directional, so the bar sits on the leading edge in both Arabic
            // and English rather than jumping sides with the language.
            Container(width: _edgeWidth, color: style.edge),
            Expanded(child: Padding(padding: padding, child: child)),
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// The status word for an [UrgencyCard], with the overdue icon attached.
///
/// Kept beside the card rather than inside it because the label's *position*
/// differs per screen — a maintenance item puts it top-right beside the title,
/// an operator queue row puts it under the amount — while its appearance must
/// not.
class UrgencyLabel extends StatelessWidget {
  const UrgencyLabel(this.label, {super.key, required this.level});

  final String label;
  final UrgencyLevel level;

  @override
  Widget build(BuildContext context) {
    final style = UrgencyStyle.of(context, level);
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: level == UrgencyLevel.normal ? ak.surfaceDim : style.tint,
        borderRadius: BorderRadius.circular(999),
        border: level == UrgencyLevel.normal
            ? null
            : Border.all(color: style.edge.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (style.icon != null) ...[
            Icon(style.icon, size: 12, color: style.text),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          // Flexible + ellipsis: escrow state names run long in both
          // languages ("Awaiting payment confirmation"), and a pill sitting
          // beside a title has to yield rather than push the row off-screen.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: style.text,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
