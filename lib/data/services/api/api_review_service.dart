import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../models/review.dart';
import '../review_service.dart';

/// Verified reviews over REST (§12).
///
/// The two rules that make a review verifiable — it exists only against a
/// released booking, and `(bookingId, direction)` is unique — are **the
/// server's** to enforce here. The mock enforces them client-side because it
/// is standing in for the server; this implementation does not re-check them,
/// because a client-side check in front of a real API is a convenience that
/// hides which side actually guarantees the rule.
class ApiReviewService implements ReviewService {
  const ApiReviewService(this._client);

  final ApiClient _client;

  @override
  Future<List<Review>> fetchReviews() async =>
      (await _client.getList(ApiEndpoints.reviews))
          .map(Review.fromJson)
          .toList();

  @override
  Future<Review> submit(Review review) async => Review.fromJson(
        await _client.post(ApiEndpoints.reviews, body: review.toJson()),
      );

  @override
  Future<Review> edit(
    String reviewId, {
    required int rating,
    String? comment,
  }) async =>
      Review.fromJson(
        await _client.patch(
          ApiEndpoints.review(reviewId),
          body: {'rating': rating, 'comment': ?comment},
        ),
      );
}
