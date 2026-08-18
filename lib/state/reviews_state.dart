import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../data/models/review.dart';
import '../data/models/service_request.dart';
import '../data/models/service_stats.dart';
import '../di/providers.dart';
import 'auth_state.dart';
import 'requests_state.dart';

/// The identifier a review is filed under while accounts live on the device.
///
/// The pilot has one customer per phone and the mock account has no
/// server-assigned id, so reviews this user wrote are attributed to this
/// constant. When registration round-trips through the API, `UserProfile.id`
/// takes over — see [ReviewsNotifier._authorId], which already prefers it.
const localAuthorId = 'local-customer';

/// Reviews written in this session, plus whatever the backend returned.
///
/// Creation is deliberately not exposed as a free-form "add a review": the
/// only entry point is [submit], which takes a *booking* and hands it to the
/// repository, and the repository refuses any booking that has not been
/// released. There is no code path in the app that produces a review without a
/// completed, paid-for job behind it.
class ReviewsNotifier extends Notifier<List<Review>> {
  /// Whether this notifier has been torn down. [load] is fire-and-forget from
  /// [build] and touches `ref` after an `await`, so without this a container
  /// disposed mid-load — a sign-out, a hot restart — makes it read a dead
  /// container and throw a bare `StateError` into the zone.
  bool _disposed = false;

  @override
  List<Review> build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(load);
    return const [];
  }

  /// `GET /reviews` is the signed-in user's own reviews, and it is
  /// `[Authorize]`d — so for a guest it can only ever answer `401`.
  ///
  /// It used to ask anyway, from a bare `Future.microtask(load)` with nothing
  /// catching it, so the `UnauthorizedException` escaped into the zone as an
  /// uncaught error the moment a guest opened any screen that reads this
  /// provider (a workshop's details page, for one). Same guard and same
  /// swallow as `NotificationsNotifier._loadFromServer`, for the same reason:
  /// "nobody is signed in" is an ordinary cold-start state, not a failure.
  ///
  /// A guest keeps the empty list they started with; [SessionRefresh] calls
  /// this again the moment they sign in.
  Future<void> load() async {
    if (_disposed) return;
    if (!await ref.read(tokenStoreProvider).mayHaveSession()) return;
    if (_disposed) return;
    try {
      final reviews = await ref.read(reviewRepositoryProvider).fetchReviews();
      if (_disposed) return;
      state = reviews;
    } on UnauthorizedException {
      // Still reachable above the guard on an expired token.
    }
  }

  /// Drops this account's reviews on sign-out — see
  /// `RequestsNotifier.clear`'s doc comment for why this is a direct `state =`
  /// write rather than `ref.invalidate(reviewsProvider)`.
  void clear() => state = const [];

  String get _authorId =>
      ref.read(authProvider).profile?.id ?? localAuthorId;

  /// Records the author's review of [request].
  ///
  /// Returns null when the repository refused it — the booking is not
  /// released, or it already carries a review in this direction. A refusal is
  /// not an exception at this layer: a double-tapped "submit" is an ordinary
  /// race, not a bug worth crashing over.
  Future<Review?> submit(
    ServiceRequest request, {
    required ReviewDirection direction,
    required int rating,
    String? comment,
  }) async {
    final repository = ref.read(reviewRepositoryProvider);
    if (!repository.reviewable(request)) return null;
    if (state.forBooking(request.id, direction) != null) return null;

    final review = await repository.submitFor(
      request,
      direction: direction,
      authorId: _authorId,
      rating: rating,
      comment: comment,
    );
    state = [review, ...state];
    return review;
  }

  /// Corrects a review inside the edit window. Outside it, nothing happens —
  /// and there is no delete, in either direction.
  Future<Review?> edit(
    String reviewId, {
    required int rating,
    String? comment,
  }) async {
    final repository = ref.read(reviewRepositoryProvider);
    final existing = state.where((r) => r.id == reviewId).firstOrNull;
    if (existing == null ||
        !existing.editableAt(DateTime.now(), repository.editWindow)) {
      return null;
    }
    final updated =
        await repository.edit(reviewId, rating: rating, comment: comment);
    state = [
      for (final r in state)
        if (r.id == updated.id) updated else r,
    ];
    return updated;
  }
}

final reviewsProvider =
    NotifierProvider<ReviewsNotifier, List<Review>>(ReviewsNotifier.new);

/// The review this booking already carries in this direction, or null.
final reviewForBookingProvider =
    Provider.family<Review?, (String, ReviewDirection)>((ref, key) =>
        ref.watch(reviewsProvider).forBooking(key.$1, key.$2));

/// Bookings the customer can rate but has not — what the "rate your
/// experience" prompt in "حجوزاتي" is built from.
///
/// Empty until a booking is actually released, which is the point: the app
/// never asks for a rating of something that has not happened.
final pendingCustomerReviewsProvider = Provider<List<ServiceRequest>>((ref) {
  final repository = ref.watch(reviewRepositoryProvider);
  final reviews = ref.watch(reviewsProvider);
  return [
    for (final r in ref.watch(requestsProvider))
      if (repository.reviewable(r) &&
          reviews.forBooking(r.id, ReviewDirection.customerToWorkshop) == null)
        r,
  ];
});

/// Bookings the workshop panel can rate but has not — the same rule, the
/// other way round (spec §8, bidirectional).
final pendingWorkshopReviewsProvider = Provider<List<ServiceRequest>>((ref) {
  final repository = ref.watch(reviewRepositoryProvider);
  final reviews = ref.watch(reviewsProvider);
  return [
    for (final r in ref.watch(requestsProvider))
      if (repository.reviewable(r) &&
          reviews.forBooking(r.id, ReviewDirection.workshopToCustomer) == null)
        r,
  ];
});

/// One workshop's rating as this app can honestly state it: the marketplace's
/// own aggregate, with the reviews written on this device folded in.
///
/// **Derived, never stored** (spec §8). There is no editable `rating` field on
/// `ServiceProvider` and there must never be one — a workshop's score is a
/// function of its reviews or it is marketing copy.
///
/// Null means nobody has rated this workshop at all, which every screen has to
/// render as "no reviews yet" rather than as a zero or a default.
final providerRatingProvider =
    Provider.family<WorkshopRating?, String>((ref, providerId) {
  final published =
      ref.watch(serviceMarketplaceRepositoryProvider).ratingFor(providerId);
  final local = ref
      .watch(reviewsProvider)
      .about(providerId, direction: ReviewDirection.customerToWorkshop);
  if (local.isEmpty) return published;

  final localSum = local.fold<int>(0, (sum, r) => sum + r.rating);
  final publishedCount = published?.reviews ?? 0;
  final publishedSum = (published?.rating ?? 0) * publishedCount;
  final count = publishedCount + local.length;
  return WorkshopRating(
    providerId: providerId,
    rating: (publishedSum + localSum) / count,
    reviews: count,
    completedJobs: published?.completedJobs,
  );
});

/// The most recent reviews of a workshop that this device can show — the ones
/// written here. The marketplace aggregate carries counts, not text, so a
/// workshop with a published 4.7 and no local reviews shows the score and no
/// quotes rather than invented ones.
final providerReviewsProvider =
    Provider.family<List<Review>, String>((ref, providerId) => ref
        .watch(reviewsProvider)
        .about(providerId, direction: ReviewDirection.customerToWorkshop)
        .newestFirst);
