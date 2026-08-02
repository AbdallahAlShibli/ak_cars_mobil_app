import '../../core/utils/guid.dart';
import '../../config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../datasources/mock/mock_seed.dart';
import '../models/review.dart';
import 'mock_service_base.dart';

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
  /// Seeded, but only against bookings in [MockSeed.requests] that actually
  /// reached `releasedToWorkshop`. That distinction is the whole point: this
  /// used to start empty precisely so nothing here could be fake social proof,
  /// and the rule has not been relaxed — every seeded review still has a
  /// completed, paid-for job behind it, which is exactly what makes a review
  /// verifiable (see `review.dart`). A review with no booking id that resolves
  /// would be the thing that was banned, and there is none.
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

class MockReviewService with MockServiceBase implements ReviewService {
  MockReviewService({required this.config});

  @override
  final AppConfig config;

  final List<Review> _reviews = [...MockSeed.reviews];

  @override
  Future<List<Review>> fetchReviews() =>
      respond(List<Review>.unmodifiable(_reviews));

  @override
  Future<Review> submit(Review review) {
    final duplicate = _reviews.any((r) =>
        r.bookingId == review.bookingId && r.direction == review.direction);
    if (duplicate) {
      throw BusinessRuleException(
        'Booking ${review.bookingId} already has a ${review.direction.key} review',
        code: 'review_already_exists',
      );
    }
    if (review.rating < 1 || review.rating > 5) {
      throw BusinessRuleException(
        'A review must score 1–5, got ${review.rating}',
        code: 'review_rating_out_of_range',
      );
    }
    // A GUID, so a review written on this device cannot collide with one
    // from the demo world or from another device — which a counter starting
    // at 500 only avoided by being seeded higher than the last mock id.
    final stored = review.copyWith(id: newGuid());
    _reviews.insert(0, stored);
    return respond(stored);
  }

  @override
  Future<Review> edit(
    String reviewId, {
    required int rating,
    String? comment,
  }) {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index < 0) throw NotFoundException('Review $reviewId not found');
    if (rating < 1 || rating > 5) {
      throw BusinessRuleException(
        'A review must score 1–5, got $rating',
        code: 'review_rating_out_of_range',
      );
    }
    final updated = _reviews[index].copyWith(
      rating: rating,
      comment: comment,
      editedAt: DateTime.now(),
    );
    _reviews[index] = updated;
    return respond(updated);
  }
}
