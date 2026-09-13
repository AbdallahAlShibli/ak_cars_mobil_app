import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';

/// The founder panel's shared card language.
///
/// Every tab answers the same shape of question — *what is the state of this
/// pile, and which row needs me* — so every tab is built from the same few
/// pieces: a summary card that states the pile in numbers, a filter row that
/// slices it, cards whose facts are chips, and an action bar along the bottom
/// of each card.
///
/// These started life private to the Offers tab. They are here because the
/// alternative is five tabs that each invent their own stat strip, and the
/// panel's whole job is to be read quickly by one person switching between
/// them — a tab that looks like a different app costs a beat every time.

/// One number in an [AdminSummaryCard]'s strip.
///
/// [value] is a widget rather than a string because half of these are money,
/// and money is rendered with the Rial glyph rather than a currency code.
class AdminStat {
  const AdminStat({required this.value, required this.label, this.color});

  /// A plain count.
  factory AdminStat.count(int value, {required String label, Color? color}) =>
      AdminStat(value: Text('$value'), label: label, color: color);

  final Widget value;
  final String label;

  /// Tints the number only. Leave null for "this is just a count" — a strip
  /// where every figure is coloured says nothing about which one matters.
  final Color? color;
}

/// The block at the top of a founder-panel tab: what this pile is, how it
/// stands, and the one thing you can do to it.
///
/// The numbers come first and the button last, because the founder opens a tab
/// to find out where things stand more often than to add something.
class AdminSummaryCard extends StatelessWidget {
  const AdminSummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.stats = const [],
    this.chips = const [],
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.footnote,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<AdminStat> stats;

  /// Secondary facts that did not earn a place in the strip.
  ///
  /// The strip holds three figures at most: a fourth makes each one about
  /// 75px wide, at which point none of them is readable and the card has
  /// stopped being a summary. Anything past the third belongs here, as an
  /// [AdminMetaChip].
  final List<Widget> chips;

  /// The tab's primary verb, as a full-width button. Omit on a tab that has
  /// nothing to create — an invented action is worse than none.
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// A caveat belonging to the numbers rather than to any one row — e.g. that
  /// a held total includes disputed jobs.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(icon, size: 40, radius: 14),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.cardTitle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: context.text.bodySecondary),
                  ],
                ),
              ),
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: ak.surfaceDim,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  for (final (i, stat) in stats.indexed) ...[
                    if (i > 0) _StatDivider(color: ak.border),
                    Expanded(child: _StatCell(stat: stat)),
                  ],
                ],
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs + 2,
              children: chips,
            ),
          ],
          if (footnote != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              footnote!,
              style: context.text.bodySecondary.copyWith(
                color: ak.inkFaint,
                height: 1.45,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: actionIcon == null
                    ? const SizedBox.shrink()
                    : Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final AdminStat stat;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      children: [
        // A three-up strip on a narrow phone gives each figure about 100px, and
        // a five-digit rial total does not fit that at 21pt. Scaling down beats
        // ellipsising a number.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: stat.color ?? ak.ink,
              height: 1.1,
            ),
            child: stat.value,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          stat.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySecondary,
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: color);
}

/// How loud an [AdminMetaChip] is.
enum AdminChipTone {
  /// A plain fact.
  normal,

  /// Something with a deadline attached to it.
  warn,

  /// A fact that has stopped mattering — expired, closed, historical.
  dim,

  /// A good outcome: money released, a job completed.
  good,
}

/// One fact about a row, in a pill.
///
/// Facts only — everything in a chip is read off the record it describes,
/// never inferred or estimated. That rule is why the panel's chips can be
/// trusted at a glance, which is the only speed at which they are read.
class AdminMetaChip extends StatelessWidget {
  const AdminMetaChip({
    super.key,
    required this.icon,
    this.label,
    this.child,
    this.tone = AdminChipTone.normal,
  }) : assert(
         (label == null) != (child == null),
         'pass exactly one of label or child',
       );

  final IconData icon;
  final String? label;
  final Widget? child;
  final AdminChipTone tone;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final (bg, fg) = switch (tone) {
      AdminChipTone.normal => (ak.surfaceDim, ak.inkSub),
      AdminChipTone.warn => (ak.amberSoft, ak.amberText),
      AdminChipTone.dim => (ak.surfaceDim, ak.inkFaint),
      AdminChipTone.good => (ak.successSoft, ak.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          // Flexible, not bare: `MainAxisSize.min` sizes the row to its
          // children, so a label longer than the space the parent Wrap has
          // left overflows rather than ellipsising. Every chip here holds text
          // written by a translator, and the Arabic of a short English label
          // is regularly half as long again.
          Flexible(
            child: DefaultTextStyle.merge(
              style: context.text.bodySecondary.copyWith(
                fontSize: 11.5,
                color: fg,
              ),
              child:
                  child ??
                  Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

/// An icon button on a card's action bar.
class AdminCardAction extends StatelessWidget {
  const AdminCardAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      color: danger ? ak.dangerText : ak.inkSub,
      onPressed: onTap,
    );
  }
}

/// A divider that stops short of a card's rounded corners, so it reads as a
/// separator between two zones of one card rather than as a cut through it.
class AdminInsetDivider extends StatelessWidget {
  const AdminInsetDivider({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Divider(
      height: 1,
      thickness: 1,
      color: color ?? AkColors.of(context).divider,
    ),
  );
}

/// The label and count of one slice of a tab's list.
class AdminFilter<T> {
  const AdminFilter({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// Appended as `· n`. Omit where a count would be noise.
  final int? count;
}

/// The horizontally scrolling filter row under a tab's summary card.
///
/// Scrollable rather than wrapped: four or five chips wrap to a second line on
/// a narrow phone, and a filter row that changes height as the counts change
/// makes the list under it jump.
class AdminFilterRow<T> extends StatelessWidget {
  const AdminFilterRow({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  final List<AdminFilter<T>> filters;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Row(
      children: [
        for (final (i, filter) in filters.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          SelectChip(
            label: filter.count == null
                ? filter.label
                : '${filter.label} · ${filter.count}',
            selected: filter.value == selected,
            onTap: () => onSelect(filter.value),
          ),
        ],
      ],
    ),
  );
}

/// The heading above a group of cards inside a tab.
///
/// Lighter than [AdminSummaryCard] — used where a tab holds several genuinely
/// different piles (the Today tab's queues, the Money tab's ledger sections)
/// rather than one list with filters.
class AdminGroupHeader extends StatelessWidget {
  const AdminGroupHeader({
    super.key,
    required this.icon,
    required this.title,
    this.count,
    this.tone = AdminChipTone.normal,
  });

  final IconData icon;
  final String title;
  final int? count;

  /// Tints the icon tile. Used to make the queue that is somebody's emergency
  /// look different from the one that is just a list.
  final AdminChipTone tone;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final (bg, fg) = switch (tone) {
      AdminChipTone.normal => (ak.surfaceDim, ak.inkSub),
      AdminChipTone.warn => (ak.amberSoft, ak.amberText),
      AdminChipTone.dim => (ak.surfaceDim, ak.inkFaint),
      AdminChipTone.good => (ak.successSoft, ak.success),
    };

    return Row(
      children: [
        IconTile(icon, size: 30, radius: 10, background: bg, foreground: fg),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(title, style: context.text.cardTitle)),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: ak.surfaceDim,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: context.text.labelStrong.copyWith(color: ak.inkSub),
            ),
          ),
        ],
      ],
    );
  }
}
