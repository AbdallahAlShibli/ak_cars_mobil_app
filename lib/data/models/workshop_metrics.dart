import '../../core/json/json_utils.dart';
import 'review.dart';

/// How one workshop is actually performing (spec §4).
///
/// **Every figure here is derived, none is stored.** The rating is the mean of
/// real [Review]s rather than a number on the provider record, the acceptance
/// rate is counted off the escrow history, and a workshop nobody has reviewed
/// gets a null [avgRating] rather than a flattering default. That is the whole
/// point of the model existing: the previous generation of this screen invented
/// its numbers, and a performance tab that invents its numbers is worse than no
/// performance tab.
///
/// Computed in `ServiceMarketplaceRepository.metricsFor` — never in a widget
/// (§14). A widget that computes its own aggregate is a widget that will
/// disagree with the next one.
class WorkshopMetrics {
  const WorkshopMetrics({
    required this.received,
    required this.accepted,
    required this.completed,
    required this.disputed,
    required this.avgResponseTime,
    required this.reviewCount,
    required this.recentReviews,
    this.avgRating,
  });

  /// A workshop with no history at all. Distinct from "all zeros computed from
  /// real data" only in that [received] is 0, which every rate getter below
  /// reads as "no answer" rather than as 0%.
  static const empty = WorkshopMetrics(
    received: 0,
    accepted: 0,
    completed: 0,
    disputed: 0,
    avgResponseTime: null,
    reviewCount: 0,
    recentReviews: [],
  );

  /// Jobs that reached this workshop at all — everything it was ever asked to
  /// accept, including the ones it rejected.
  final int received;

  /// Of those, the ones it took on.
  final int accepted;

  /// Of the accepted ones, the ones that reached `releasedToWorkshop`.
  final int completed;

  /// Accepted jobs the customer disputed.
  final int disputed;

  /// Mean time from the funds landing to the workshop accepting or rejecting.
  /// Null when it has never been asked — not `Duration.zero`, which would read
  /// as an instant response.
  final Duration? avgResponseTime;

  /// Mean of every customer→workshop review. Null when nobody has reviewed it
  /// (see [ReviewListX.averageRating] for why null and not 0).
  final double? avgRating;

  final int reviewCount;

  /// The five most recent customer reviews, newest first — the words behind
  /// the number.
  final List<Review> recentReviews;

  /// accepted ÷ received. Null when it has been sent nothing: 0% would be a
  /// claim about a workshop that has not had the chance to refuse anything.
  double? get acceptanceRate => received == 0 ? null : accepted / received;

  /// completed ÷ accepted.
  double? get completionRate => accepted == 0 ? null : completed / accepted;

  /// disputed ÷ accepted.
  double? get disputeRate => accepted == 0 ? null : disputed / accepted;

  /// True when there is not enough history for any of the rates to mean
  /// anything. The Performance tab renders an empty state rather than four
  /// null dashes.
  bool get isEmpty => received == 0 && reviewCount == 0;

  factory WorkshopMetrics.fromJson(JsonMap json) => WorkshopMetrics(
        received: json.intOr('received', 0),
        accepted: json.intOr('accepted', 0),
        completed: json.intOr('completed', 0),
        disputed: json.intOr('disputed', 0),
        avgResponseTime: json.intOrNull('avgResponseTimeMinutes') == null
            ? null
            : Duration(minutes: json.requireInt('avgResponseTimeMinutes')),
        avgRating: json.doubleOrNull('avgRating'),
        reviewCount: json.intOr('reviewCount', 0),
        recentReviews:
            json.objectList('recentReviews').map(Review.fromJson).toList(),
      );

  JsonMap toJson() => {
        'received': received,
        'accepted': accepted,
        'completed': completed,
        'disputed': disputed,
        'avgResponseTimeMinutes': avgResponseTime?.inMinutes,
        'avgRating': avgRating,
        'reviewCount': reviewCount,
        'recentReviews': [for (final r in recentReviews) r.toJson()],
      };

  WorkshopMetrics copyWith({
    int? received,
    int? accepted,
    int? completed,
    int? disputed,
    Duration? avgResponseTime,
    double? avgRating,
    int? reviewCount,
    List<Review>? recentReviews,
  }) =>
      WorkshopMetrics(
        received: received ?? this.received,
        accepted: accepted ?? this.accepted,
        completed: completed ?? this.completed,
        disputed: disputed ?? this.disputed,
        avgResponseTime: avgResponseTime ?? this.avgResponseTime,
        avgRating: avgRating ?? this.avgRating,
        reviewCount: reviewCount ?? this.reviewCount,
        recentReviews: recentReviews ?? this.recentReviews,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkshopMetrics &&
      other.received == received &&
      other.accepted == accepted &&
      other.completed == completed &&
      other.disputed == disputed &&
      other.avgResponseTime == avgResponseTime &&
      other.avgRating == avgRating &&
      other.reviewCount == reviewCount &&
      _sameReviews(other.recentReviews);

  bool _sameReviews(List<Review> other) {
    if (other.length != recentReviews.length) return false;
    for (var i = 0; i < recentReviews.length; i++) {
      if (other[i] != recentReviews[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(received, accepted, completed, disputed,
      avgResponseTime, avgRating, reviewCount, Object.hashAll(recentReviews));
}
