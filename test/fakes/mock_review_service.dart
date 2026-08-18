import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/utils/guid.dart';
import 'package:ak_cars_mobil_app/data/models/review.dart';
import 'package:ak_cars_mobil_app/data/services/review_service.dart';

import 'data/mock_seed.dart';
import 'fake_service_base.dart';

/// Seeded, but only against bookings in [MockSeed.requests] that actually
/// reached `releasedToWorkshop` — every seeded review still has a completed,
/// paid-for job behind it, which is what makes a review verifiable.
class MockReviewService with MockServiceBase implements ReviewService {
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
    // A GUID, so a review written in one test cannot collide with a seeded one.
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
