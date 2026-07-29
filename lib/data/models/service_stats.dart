import '../../core/json/json_utils.dart';

/// How much a service category was actually booked, over a stated window.
///
/// Aggregated by the marketplace, never by the client: "most booked" is a fact
/// about every customer's bookings, and this app can only see the signed-in
/// user's own. Deriving a leaderboard from anything the phone can reach — the
/// number of workshops selling a category, say — would be a different fact
/// wearing this one's label.
///
/// [windowDays] travels with the count for the same reason: "142 bookings" is
/// meaningless without the period it covers, and the screen prints both.
class CategoryDemand {
  const CategoryDemand({
    required this.categoryId,
    required this.bookings,
    this.windowDays = 30,
  });

  final String categoryId;

  /// Completed bookings in the window, across the whole marketplace.
  final int bookings;

  /// The trailing period [bookings] covers.
  final int windowDays;

  factory CategoryDemand.fromJson(JsonMap json) => CategoryDemand(
        categoryId: json.requireString('categoryId'),
        bookings: json.intOr('bookings', 0),
        windowDays: json.intOr('windowDays', 30),
      );

  JsonMap toJson() => {
        'categoryId': categoryId,
        'bookings': bookings,
        'windowDays': windowDays,
      };

  CategoryDemand copyWith({
    String? categoryId,
    int? bookings,
    int? windowDays,
  }) =>
      CategoryDemand(
        categoryId: categoryId ?? this.categoryId,
        bookings: bookings ?? this.bookings,
        windowDays: windowDays ?? this.windowDays,
      );

  @override
  bool operator ==(Object other) =>
      other is CategoryDemand &&
      other.categoryId == categoryId &&
      other.bookings == bookings &&
      other.windowDays == windowDays;

  @override
  int get hashCode => Object.hash(categoryId, bookings, windowDays);
}

/// How many jobs one workshop actually completed, over a stated window.
///
/// The home page's "most requested" board (home-page spec §4) ranks on this.
/// "Completed" means the booking reached `EscrowState.releasedToWorkshop` —
/// the customer approved the work and the money moved. Requests that were
/// opened, quoted, cancelled or refunded are not demand for a workshop, they
/// are traffic, and ranking on traffic would reward a workshop for being asked
/// rather than for delivering.
///
/// Server-side, like [CategoryDemand], and for the same reason: the phone sees
/// only the signed-in user's own bookings. [windowDays] travels with the count
/// because "84 jobs" without a period is not a fact.
class WorkshopDemand {
  const WorkshopDemand({
    required this.providerId,
    required this.completedBookings,
    this.windowDays = 30,
  });

  final String providerId;

  /// Bookings released to this workshop inside the window.
  final int completedBookings;

  final int windowDays;

  factory WorkshopDemand.fromJson(JsonMap json) => WorkshopDemand(
        providerId: json.requireString('providerId'),
        completedBookings: json.intOr('completedBookings', 0),
        windowDays: json.intOr('windowDays', 30),
      );

  JsonMap toJson() => {
        'providerId': providerId,
        'completedBookings': completedBookings,
        'windowDays': windowDays,
      };

  WorkshopDemand copyWith({
    String? providerId,
    int? completedBookings,
    int? windowDays,
  }) =>
      WorkshopDemand(
        providerId: providerId ?? this.providerId,
        completedBookings: completedBookings ?? this.completedBookings,
        windowDays: windowDays ?? this.windowDays,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkshopDemand &&
      other.providerId == providerId &&
      other.completedBookings == completedBookings &&
      other.windowDays == windowDays;

  @override
  int get hashCode => Object.hash(providerId, completedBookings, windowDays);
}

/// A workshop's customer rating, aggregated from bookings that completed.
///
/// Kept off [ServiceProvider] on purpose. A rating is not a property of the
/// business the way its address or its VAT number is — it is a computed
/// aggregate that arrives from a different endpoint, exists only for workshops
/// that have been rated, and must be *absent* rather than defaulted for the
/// rest. A `rating` field on the provider would have to carry a number for a
/// workshop nobody has reviewed yet, and every provider card in the app would
/// then print it.
///
/// [reviews] is what makes the number rankable: see
/// `ServiceMarketplaceRepository.topRatedWorkshops`, which refuses to rank a
/// workshop with too few reviews to mean anything.
class WorkshopRating {
  const WorkshopRating({
    required this.providerId,
    required this.rating,
    required this.reviews,
    this.completedJobs,
  });

  final String providerId;

  /// Mean score out of 5.
  final double rating;

  /// How many customers rated it. A rating with no review count behind it is
  /// not evidence of anything.
  final int reviews;

  /// Bookings this workshop completed on the platform. Null where the
  /// marketplace does not publish it.
  final int? completedJobs;

  factory WorkshopRating.fromJson(JsonMap json) => WorkshopRating(
        providerId: json.requireString('providerId'),
        rating: json.doubleOr('rating', 0),
        reviews: json.intOr('reviews', 0),
        completedJobs: json.intOrNull('completedJobs'),
      );

  JsonMap toJson() => {
        'providerId': providerId,
        'rating': rating,
        'reviews': reviews,
        'completedJobs': completedJobs,
      };

  WorkshopRating copyWith({
    String? providerId,
    double? rating,
    int? reviews,
    int? completedJobs,
  }) =>
      WorkshopRating(
        providerId: providerId ?? this.providerId,
        rating: rating ?? this.rating,
        reviews: reviews ?? this.reviews,
        completedJobs: completedJobs ?? this.completedJobs,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkshopRating &&
      other.providerId == providerId &&
      other.rating == rating &&
      other.reviews == reviews &&
      other.completedJobs == completedJobs;

  @override
  int get hashCode => Object.hash(providerId, rating, reviews, completedJobs);
}
