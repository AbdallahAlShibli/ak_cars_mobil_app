import '../models/review.dart';

/// Verified reviews (spec §8).
///
/// Phase 2: implement `RestReviewService` against `/reviews` and swap the
/// binding in `lib/di/providers.dart`. The uniqueness rule below has to be
/// enforced server-side as well — a `UNIQUE (bookingId, direction)` index is
/// the whole anti-spam design, and a client-side check is a convenience, not a
/// guarantee.
abstract interface class ReviewService {
  /// Every review this user can see.
  ///
  /// Every review is tied to a booking that actually reached
  /// `releasedToWorkshop` — a completed, paid-for job — which is what makes it
  /// verifiable (see `review.dart`). A review with no booking id behind it is
  /// the thing this design exists to prevent.
  ///
  /// The marketplace-wide aggregates on
  /// `ServiceMarketplaceService.fetchWorkshopRatings` are a different thing —
  /// those are counts the backend computed.
  Future<List<Review>> fetchReviews();

  /// Records a review. Rejects a second one for the same booking in the same
  /// direction, which is the constraint that makes a review verifiable.
  Future<Review> submit(Review review);

  /// Corrects an existing review inside the edit window. Never deletes: a
  /// review that can be withdrawn on demand is a review a workshop can
  /// pressure someone into withdrawing.
  Future<Review> edit(String reviewId, {required int rating, String? comment});
}
