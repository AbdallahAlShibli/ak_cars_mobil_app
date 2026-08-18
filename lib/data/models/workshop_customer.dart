import '../../core/json/json_utils.dart';
import 'service_request.dart';

/// A behavioural label the server derives for a [WorkshopCustomer] — never
/// stored, recomputed on every read from that customer's booking history.
enum WorkshopCustomerTag { repeat, newCustomer, disputed, lapsed }

extension WorkshopCustomerTagX on WorkshopCustomerTag {
  /// Wire value — note `newCustomer`'s key is `new`, the reserved word the
  /// server actually sends.
  String get key => switch (this) {
    WorkshopCustomerTag.newCustomer => 'new',
    _ => name,
  };

  static WorkshopCustomerTag? fromKey(String key) => switch (key) {
    'repeat' => WorkshopCustomerTag.repeat,
    'new' => WorkshopCustomerTag.newCustomer,
    'disputed' => WorkshopCustomerTag.disputed,
    'lapsed' => WorkshopCustomerTag.lapsed,
    _ => null,
  };
}

/// One row in a workshop's customer list — a projection over that workshop's
/// own [ServiceRequest]s, never a stored contact. There is no customer table
/// anywhere in this app; ask the server fresh every time.
class WorkshopCustomer {
  const WorkshopCustomer({
    required this.userId,
    required this.name,
    this.phone,
    required this.carCount,
    required this.bookingsCount,
    required this.lifetimeGross,
    required this.lastBookingAt,
    this.avgRatingGiven,
    this.tags = const {},
  });

  final String userId;
  final String name;

  /// Omitted by the server (never sent as an empty string) until escrow
  /// unlocks direct contact for the most recent booking — see
  /// `core/utils/provider_contact.dart`'s gating rule, mirrored server-side.
  final String? phone;

  final int carCount;
  final int bookingsCount;
  final double lifetimeGross;
  final DateTime lastBookingAt;
  final double? avgRatingGiven;
  final Set<WorkshopCustomerTag> tags;

  factory WorkshopCustomer.fromJson(JsonMap json) => WorkshopCustomer(
    userId: json.requireString('userId'),
    name: json.stringOr('name', ''),
    phone: json.stringOrNull('phone'),
    carCount: json.intOr('carCount', 0),
    bookingsCount: json.intOr('bookingsCount', 0),
    lifetimeGross: json.doubleOr('lifetimeGross', 0),
    lastBookingAt: json.dateTimeOr('lastBookingAt', DateTime.now()),
    avgRatingGiven: json.doubleOrNull('avgRatingGiven'),
    tags: {
      for (final key in json.stringList('tags'))
        ?WorkshopCustomerTagX.fromKey(key),
    },
  );

  JsonMap toJson() => {
    'userId': userId,
    'name': name,
    'phone': phone,
    'carCount': carCount,
    'bookingsCount': bookingsCount,
    'lifetimeGross': lifetimeGross,
    'lastBookingAt': lastBookingAt.toIso8601String(),
    'avgRatingGiven': avgRatingGiven,
    'tags': [for (final t in tags) t.key],
  };

  @override
  bool operator ==(Object other) =>
      other is WorkshopCustomer &&
      other.userId == userId &&
      other.name == name &&
      other.phone == phone &&
      other.carCount == carCount &&
      other.bookingsCount == bookingsCount &&
      other.lifetimeGross == lifetimeGross &&
      other.lastBookingAt == lastBookingAt &&
      other.avgRatingGiven == avgRatingGiven &&
      other.tags.length == tags.length &&
      other.tags.containsAll(tags);

  @override
  int get hashCode => Object.hash(
    userId,
    name,
    phone,
    carCount,
    bookingsCount,
    lifetimeGross,
    lastBookingAt,
    avgRatingGiven,
    Object.hashAllUnordered(tags),
  );
}

/// A workshop's own annotation on a customer it has actually served.
class WorkshopCustomerNote {
  const WorkshopCustomerNote({
    required this.id,
    required this.body,
    required this.at,
    this.byStaffId,
  });

  final String id;
  final String body;
  final DateTime at;
  final String? byStaffId;

  factory WorkshopCustomerNote.fromJson(JsonMap json) => WorkshopCustomerNote(
    id: json.requireString('id'),
    body: json.stringOr('body', ''),
    at: json.dateTimeOr('at', DateTime.now()),
    byStaffId: json.stringOrNull('byStaffId'),
  );

  JsonMap toJson() => {
    'id': id,
    'body': body,
    'at': at.toIso8601String(),
    'byStaffId': byStaffId,
  };

  @override
  bool operator ==(Object other) =>
      other is WorkshopCustomerNote &&
      other.id == id &&
      other.body == body &&
      other.at == at &&
      other.byStaffId == byStaffId;

  @override
  int get hashCode => Object.hash(id, body, at, byStaffId);
}

/// One customer plus their full history with this workshop — what the
/// customer-detail screen renders in one round trip.
class WorkshopCustomerDetail {
  const WorkshopCustomerDetail({
    required this.customer,
    this.bookings = const [],
    this.notes = const [],
  });

  final WorkshopCustomer customer;
  final List<ServiceRequest> bookings;
  final List<WorkshopCustomerNote> notes;

  factory WorkshopCustomerDetail.fromJson(
    JsonMap json,
  ) => WorkshopCustomerDetail(
    customer: WorkshopCustomer.fromJson(json.requireObject('customer')),
    bookings: json.objectList('bookings').map(ServiceRequest.fromJson).toList(),
    notes: json.objectList('notes').map(WorkshopCustomerNote.fromJson).toList(),
  );

  JsonMap toJson() => {
    'customer': customer.toJson(),
    'bookings': [for (final b in bookings) b.toJson()],
    'notes': [for (final n in notes) n.toJson()],
  };
}
