import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'widgets.dart';

/// What a list looks like when it is empty, everywhere in the app.
///
/// An empty list used to render as either nothing at all or a grey sentence
/// floating in the middle of a page, and both read as a broken screen rather
/// than as a fact about the data. This is the fact, stated: an icon so the
/// blank area has a subject, a message that says what being empty *means*
/// here, and — where there is something the user can do about it — one button.
///
/// The message is the part that matters and the part that is easy to get
/// wrong. "No data" describes the database. "No open jobs right now — enjoy
/// the quiet" describes the user's day. Write the second kind: an empty
/// workshop queue is good news for the workshop, and an empty garage is an
/// invitation, not an error.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.action,
    this.compact = false,
  });

  final IconData icon;

  /// The sentence. Positive and specific — see the class doc.
  final String message;

  /// Optional short headline above [message].
  final String? title;

  /// The one thing to do about it, if there is one.
  final Widget? action;

  /// Inline inside an already-titled section, rather than filling a page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: compact ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(
            icon,
            size: compact ? 46 : 62,
            radius: compact ? 16 : 22,
            background: ak.surfaceDim,
            foreground: ak.inkFaint,
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          if (title != null) ...[
            Text(title!,
                textAlign: TextAlign.center, style: context.text.cardTitle),
            const SizedBox(height: AppSpacing.xs + 2),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodySecondary.copyWith(height: 1.6),
          ),
          if (action != null) ...[
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Placeholder rows for a list that is still loading.
///
/// A single spinner in the middle of an empty page says "wait"; a stack of
/// card-shaped blocks says "a list is coming, and it is about this tall",
/// which is both more honest and less anxious to look at. Sized to roughly
/// match the real rows so the page does not jump when they arrive.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.rows = 3,
    this.height = 76,
    this.radius = 18,
    this.gap = AppSpacing.itemGap + 2,
  });

  final int rows;
  final double height;
  final double radius;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Skeleton(height: height, radius: radius),
        ],
      ],
    );
  }
}

/// The metrics strip's loading state — see `MetricTile`.
class MetricSkeleton extends StatelessWidget {
  const MetricSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Skeleton(height: 64, radius: 16)),
        ],
      ],
    );
  }
}

/// One number in an operator panel's metrics strip (§5).
///
/// Reading material, not a control: a quiet surface, no border emphasis, no
/// tap target. Everything actionable on those screens is in the queues below,
/// and a tile that looked pressable would send the operator to the wrong half
/// of the page.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    this.tone,
  });

  final Widget value;
  final String label;

  /// Set only where the number itself is the alarm — an open dispute count,
  /// a queue that has stalled. Left null the number is just a number.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DefaultTextStyle.merge(
            style: context.text.cardTitle.copyWith(color: tone ?? ak.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: value,
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            label,
            maxLines: 2,
            style: context.text.bodySecondary.copyWith(fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }
}
