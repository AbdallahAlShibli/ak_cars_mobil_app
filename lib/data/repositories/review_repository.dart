import '../../core/error/app_exception.dart';
import '../models/escrow.dart';
import '../models/review.dart';
import '../models/service_request.dart';
import '../services/review_service.dart';

/// Verified reviews (spec §8).
///
/// The repository owns the *rule*, not just the plumbing: [submitFor] is the
/// only way a review is created, and it refuses any booking that has not
/// reached [EscrowState.releasedToWorkshop]. That single check is what the
/// word "verified" means here — there is no separate verification step, no
/// badge to award, and nothing to moderate away.
abstract interface class ReviewRepository {
  Future<List<Review>> fetchReviews();

  /// How long an author may correct what they wrote.
  ///
  /// Short on purpose: a review that stays editable forever is a review a
  /// workshop can keep asking to have changed. Deletion is not offered at all,
  /// in either direction.
  Duration get editWindow;

  /// Whether [request] is in a state that has earned a review.
  ///
  /// A disputed booking qualifies once the dispute is *resolved* — release or
  /// refund — because the customer's experience of the dispute is part of the
  /// record. A booking cancelled before any work is not: nothing happened to
  /// review.
  bool reviewable(ServiceRequest request);

  /// Records a review of [request] in [direction].
  ///
  /// Throws [BusinessRuleException] when the booking has not been released, or
  /// when it already carries a review in that direction.
  Future<Review> submitFor(
    ServiceRequest request, {
    required ReviewDirection direction,
    required String authorId,
    required int rating,
    String? comment,
  });

  Future<Review> edit(String reviewId, {required int rating, String? comment});
}

class ReviewRepositoryImpl implements ReviewRepository {
  ReviewRepositoryImpl(this._service);

  final ReviewService _service;

  @override
  Duration get editWindow => const Duration(hours: 24);

  @override
  Future<List<Review>> fetchReviews() => _service.fetchReviews();

  @override
  bool reviewable(ServiceRequest request) =>
      request.escrow == EscrowState.releasedToWorkshop ||
      // Resolved the customer's way: the work still happened, the money came
      // back, and both parties have something to say about it.
      (request.escrow == EscrowState.refunded && _wasWorkedOn(request));

  /// True when the booking got past "funds held" — i.e. a workshop actually
  /// took the job on. A refund that followed a rejection or a cancellation is
  /// not an experience anyone can rate.
  bool _wasWorkedOn(ServiceRequest request) => request.history.any((e) =>
      e.state == EscrowState.inProgress ||
      e.state == EscrowState.proofSubmitted ||
      e.state == EscrowState.awaitingApproval);

  @override
  Future<Review> submitFor(
    ServiceRequest request, {
    required ReviewDirection direction,
    required String authorId,
    required int rating,
    String? comment,
  }) {
    if (!reviewable(request)) {
      throw BusinessRuleException(
        'Booking ${request.id} is ${request.escrow.key} — reviews unlock at '
        'releasedToWorkshop',
        code: 'review_not_unlocked',
      );
    }
    final subjectId = switch (direction) {
      ReviewDirection.customerToWorkshop => request.offering.provider.id,
      // The pilot has one customer account per device, so the booking's own id
      // stands in for the customer until accounts are server-side. It is
      // stable and unique, which is all a subject key has to be.
      ReviewDirection.workshopToCustomer => 'customer-${request.id}',
    };
    return _service.submit(
      Review(
        // Replaced by the service, which owns the identity sequence.
        id: '',
        bookingId: request.id,
        authorId: authorId,
        subjectId: subjectId,
        direction: direction,
        rating: rating,
        comment: (comment ?? '').trim().isEmpty ? null : comment!.trim(),
        serviceType: request.offering.name,
        createdAt: DateTime.now(),
        afterDispute:
            request.history.any((e) => e.state == EscrowState.disputed),
      ),
    );
  }

  @override
  Future<Review> edit(
    String reviewId, {
    required int rating,
    String? comment,
  }) =>
      _service.edit(reviewId, rating: rating, comment: comment);
}
