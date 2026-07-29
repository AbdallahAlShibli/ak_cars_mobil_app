import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';

/// Five stars, read-only, filled to [rating].
class StarRow extends StatelessWidget {
  const StarRow(this.rating, {super.key, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: ak.amberText,
          ),
      ],
    );
  }
}

/// A workshop's rating, or an honest blank where there is none.
///
/// The number is [providerRatingProvider]'s — derived from reviews, never a
/// field anyone can type. A workshop with no reviews gets the words "no
/// reviews yet", never a default score and never a row of empty stars dressed
/// up as one.
class RatingSummaryLine extends ConsumerWidget {
  const RatingSummaryLine({
    super.key,
    required this.providerId,
    this.compact = false,
  });

  final String providerId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppFlags.verifiedReviews) return const SizedBox.shrink();
    final s = S.of(context);
    final ak = AkColors.of(context);
    final rating = ref.watch(providerRatingProvider(providerId));

    if (rating == null) {
      return Text(
        s.t('لا تقييمات بعد', 'No reviews yet'),
        style: TextStyle(fontSize: 11, color: ak.inkFaint),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarRow(rating.rating, size: compact ? 12 : 14),
        const SizedBox(width: 5),
        // Flexible because "4.8 · 180 reviews" is materially longer than
        // "٤٫٨ · ١٨٠ تقييماً", and this line sits inside rows that are already
        // carrying a workshop name.
        Flexible(
          child: Text(
            '${rating.rating.toStringAsFixed(1)} · ${s.reviews(rating.reviews)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              color: ak.inkSub,
            ),
          ),
        ),
      ],
    );
  }
}

/// The reviews of a workshop that this app can actually show, with the reason
/// they are trustworthy stated once above them.
///
/// Only reviews written on this device carry text today — the marketplace
/// aggregate is counts, not comments — so an unreviewed workshop renders the
/// count and no quotes rather than invented ones.
class ProviderReviewList extends ConsumerWidget {
  const ProviderReviewList({
    super.key,
    required this.providerId,
    this.limit = 3,
  });

  final String providerId;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppFlags.verifiedReviews) return const SizedBox.shrink();
    final s = S.of(context);
    final ak = AkColors.of(context);
    final reviews = ref.watch(providerReviewsProvider(providerId));
    final rating = ref.watch(providerRatingProvider(providerId));

    if (rating == null && reviews.isEmpty) {
      return AppCard(
        child: Text(
          s.t('لم يقيّم أحد هذه الورشة بعد. التقييم لا يُفتح إلا بعد حجز مكتمل ومُحرَّر.',
              'Nobody has rated this workshop yet. A review only unlocks after a booking completes and pays out.'),
          style: TextStyle(fontSize: 12, height: 1.6, color: ak.inkSub),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rating != null)
          AppCard(
            child: Row(
              children: [
                Text(
                  rating.rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StarRow(rating.rating, size: 15),
                      const SizedBox(height: 3),
                      Text(
                        s.t('${s.reviews(rating.reviews)} — كلها من حجوزات مكتملة',
                            '${s.reviews(rating.reviews)} — every one from a completed booking'),
                        style: TextStyle(fontSize: 11, color: ak.inkSub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        for (final review in reviews.take(limit)) ...[
          const SizedBox(height: 9),
          ReviewCard(review: review),
        ],
      ],
    );
  }
}

/// One review, as written.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRow(review.rating.toDouble()),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.serviceType.of(s),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: ak.inkSub),
                ),
              ),
              // The badge is the point of the feature: it is true by
              // construction, not by anyone's assessment.
              StatusBadge.good(s.t('موثّق', 'Verified')),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!,
                style: const TextStyle(fontSize: 12.5, height: 1.6)),
          ],
          if (review.afterDispute || review.edited) ...[
            const SizedBox(height: 7),
            Text(
              [
                if (review.afterDispute)
                  s.t('بعد نزاع محلول', 'After a resolved dispute'),
                if (review.edited) s.t('عُدِّل', 'Edited'),
              ].join(' · '),
              style: TextStyle(fontSize: 10.5, color: ak.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tappable stars for writing a review.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            icon: Icon(
              rating >= i ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 38,
              color: rating >= i ? ak.amberText : ak.inkFaint,
            ),
          ),
      ],
    );
  }
}
