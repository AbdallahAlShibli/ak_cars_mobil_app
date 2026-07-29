import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';

/// Who is rating whom.
///
/// One entity, two directions (spec §8): the customer rates the workshop and
/// the workshop rates the customer, and both unlock at the same moment. A
/// separate `WorkshopReview` / `CustomerReview` pair would duplicate every
/// rule — the unlock condition, the one-per-booking constraint, the edit
/// window — for no gain.
enum ReviewDirection {
  customerToWorkshop,
  workshopToCustomer;

  String get key => name;

  static ReviewDirection fromKey(String? key) {
    for (final value in ReviewDirection.values) {
      if (value.key == key) return value;
    }
    return ReviewDirection.customerToWorkshop;
  }
}

/// A rating that exists because a real, paid-for job finished.
///
/// **This is the entire verification mechanism.** A review can only be created
/// from a booking that reached `releasedToWorkshop`, and [bookingId] +
/// [direction] are unique together — so there is no such thing here as a
/// review without a job behind it, and no second review of the same job. That
/// is why the app needs no separate "verified purchase" check, no moderation
/// queue, and no bot detection: faking a review costs an actual booking with
/// actual money in it.
class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.authorId,
    required this.subjectId,
    required this.direction,
    required this.rating,
    required this.serviceType,
    required this.createdAt,
    this.comment,
    this.editedAt,
    this.afterDispute = false,
  });

  final String id;

  /// The booking this review is *of*. Unique per [direction] — the constraint
  /// that makes the whole design work.
  final String bookingId;

  final String authorId;

  /// The party being rated: a workshop id, or a customer id.
  final String subjectId;

  final ReviewDirection direction;

  /// 1–5. Never 0: a review with no score is not a review.
  final int rating;

  /// Free text, optional. The author's own words — stored and shown verbatim,
  /// never translated, never summarised.
  final String? comment;

  /// Copied off the booking so the review still says what work it is about
  /// after the offering is renamed or withdrawn.
  final L serviceType;

  final DateTime createdAt;

  /// Set when the author corrected it inside the edit window. Shown, because a
  /// silently-rewritten review is a different claim wearing the first one's
  /// timestamp.
  final DateTime? editedAt;

  /// True when the booking behind it went through a dispute before settling.
  /// Such reviews are **not** hidden (spec §8) — they are labelled, since a
  /// resolved dispute is part of the record, not a reason to suppress it.
  final bool afterDispute;

  bool get edited => editedAt != null;

  /// Whether [now] still falls inside the window in which the author may
  /// correct what they wrote. Deletion is never allowed — see
  /// `ReviewRepository`.
  bool editableAt(DateTime now, Duration window) =>
      now.difference(createdAt) <= window;

  factory Review.fromJson(JsonMap json) => Review(
        id: json.requireString('id'),
        bookingId: json.stringOr('bookingId', ''),
        authorId: json.stringOr('authorId', ''),
        subjectId: json.stringOr('subjectId', ''),
        direction: ReviewDirection.fromKey(json.stringOrNull('direction')),
        rating: json.intOr('rating', 0),
        comment: json.stringOrNull('comment'),
        serviceType: L.fromJson(json['serviceType']),
        createdAt: json.dateTimeOr('createdAt', DateTime.now()),
        editedAt: json.dateTimeOrNull('editedAt'),
        afterDispute: json.boolOr('afterDispute', false),
      );

  JsonMap toJson() => {
        'id': id,
        'bookingId': bookingId,
        'authorId': authorId,
        'subjectId': subjectId,
        'direction': direction.key,
        'rating': rating,
        'comment': comment,
        'serviceType': serviceType.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'editedAt': editedAt?.toIso8601String(),
        'afterDispute': afterDispute,
      };

  Review copyWith({
    String? id,
    String? bookingId,
    String? authorId,
    String? subjectId,
    ReviewDirection? direction,
    int? rating,
    String? comment,
    L? serviceType,
    DateTime? createdAt,
    DateTime? editedAt,
    bool? afterDispute,
  }) =>
      Review(
        id: id ?? this.id,
        bookingId: bookingId ?? this.bookingId,
        authorId: authorId ?? this.authorId,
        subjectId: subjectId ?? this.subjectId,
        direction: direction ?? this.direction,
        rating: rating ?? this.rating,
        comment: comment ?? this.comment,
        serviceType: serviceType ?? this.serviceType,
        createdAt: createdAt ?? this.createdAt,
        editedAt: editedAt ?? this.editedAt,
        afterDispute: afterDispute ?? this.afterDispute,
      );

  @override
  bool operator ==(Object other) =>
      other is Review &&
      other.id == id &&
      other.bookingId == bookingId &&
      other.authorId == authorId &&
      other.subjectId == subjectId &&
      other.direction == direction &&
      other.rating == rating &&
      other.comment == comment &&
      other.serviceType == serviceType &&
      other.createdAt == createdAt &&
      other.editedAt == editedAt &&
      other.afterDispute == afterDispute;

  @override
  int get hashCode => Object.hash(
        id,
        bookingId,
        authorId,
        subjectId,
        direction,
        rating,
        comment,
        serviceType,
        createdAt,
        editedAt,
        afterDispute,
      );
}

extension ReviewListX on Iterable<Review> {
  /// Every review of [subjectId] in the given direction.
  List<Review> about(String subjectId, {ReviewDirection? direction}) => [
        for (final r in this)
          if (r.subjectId == subjectId &&
              (direction == null || r.direction == direction))
            r,
      ];

  /// The review this booking already has in this direction, or null. The
  /// one-per-booking constraint, expressed as a lookup.
  Review? forBooking(String bookingId, ReviewDirection direction) {
    for (final r in this) {
      if (r.bookingId == bookingId && r.direction == direction) return r;
    }
    return null;
  }

  /// Mean score, or null when there is nothing to average.
  ///
  /// Null rather than 0 or 5 on purpose: "no reviews yet" is a different
  /// statement from "rated zero", and every screen that prints a rating has to
  /// be able to tell them apart.
  double? get averageRating {
    var sum = 0;
    var n = 0;
    for (final r in this) {
      sum += r.rating;
      n++;
    }
    return n == 0 ? null : sum / n;
  }

  /// Newest first.
  List<Review> get newestFirst {
    final sorted = [...this]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }
}
