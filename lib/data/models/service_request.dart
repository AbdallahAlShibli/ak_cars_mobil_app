import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'add_on.dart';
import 'car.dart';
import 'service_offering.dart';
import 'service_provider.dart';

/// Lifecycle of a booked service. The provider portal drives the transitions;
/// the customer only acts at [proofSubmitted] (approve or dispute).
enum RequestStatus {
  requested,
  accepted,
  inProgress,
  proofSubmitted,
  completed,
  disputed,
}

extension RequestStatusX on RequestStatus {
  String label(S s) => switch (this) {
        RequestStatus.requested =>
          s.t('بانتظار مزود الخدمة', 'Waiting for provider'),
        RequestStatus.accepted => s.t('مقبول', 'Accepted'),
        RequestStatus.inProgress => s.t('قيد التنفيذ', 'In progress'),
        RequestStatus.proofSubmitted =>
          s.t('بانتظار موافقتك', 'Awaiting your approval'),
        RequestStatus.completed => s.t('مكتمل', 'Completed'),
        RequestStatus.disputed => s.t('متنازع عليه', 'Disputed'),
      };

  /// Stable wire value.
  String get key => name;

  /// The status this one advances to, or null when the request has reached a
  /// terminal state. Single source of truth for the progression — used by the
  /// demo lifecycle simulator today and by optimistic updates later.
  RequestStatus? get next => switch (this) {
        RequestStatus.requested => RequestStatus.accepted,
        RequestStatus.accepted => RequestStatus.inProgress,
        RequestStatus.inProgress => RequestStatus.proofSubmitted,
        _ => null,
      };
}

/// A booking placed against a [ServiceOffering].
class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.offering,
    required this.car,
    required this.plate,
    required this.fulfillment,
    required this.slot,
    required this.addOns,
    required this.total,
    required this.status,
  });

  final String id;
  final ServiceOffering offering;
  final Car car;
  final String plate;
  final Fulfillment fulfillment;
  final String slot;
  final List<AddOn> addOns;
  final double total;
  final RequestStatus status;

  factory ServiceRequest.fromJson(JsonMap json) => ServiceRequest(
        id: json.requireString('id'),
        offering: ServiceOffering.fromJson(json.requireObject('offering')),
        car: Car.fromJson(json.requireObject('car')),
        plate: json.stringOr('plate', ''),
        fulfillment: FulfillmentX.fromKey(json.stringOrNull('fulfillment')),
        slot: json.stringOr('slot', ''),
        addOns: json.objectList('addOns').map(AddOn.fromJson).toList(),
        total: json.doubleOr('total', 0),
        status: json.enumOr(
          'status',
          RequestStatus.values,
          RequestStatus.requested,
        ),
      );

  JsonMap toJson() => {
        'id': id,
        'offering': offering.toJson(),
        'car': car.toJson(),
        'plate': plate,
        'fulfillment': fulfillment.key,
        'slot': slot,
        'addOns': [for (final a in addOns) a.toJson()],
        'total': total,
        'status': status.key,
      };

  ServiceRequest copyWith({
    String? id,
    ServiceOffering? offering,
    Car? car,
    String? plate,
    Fulfillment? fulfillment,
    String? slot,
    List<AddOn>? addOns,
    double? total,
    RequestStatus? status,
  }) =>
      ServiceRequest(
        id: id ?? this.id,
        offering: offering ?? this.offering,
        car: car ?? this.car,
        plate: plate ?? this.plate,
        fulfillment: fulfillment ?? this.fulfillment,
        slot: slot ?? this.slot,
        addOns: addOns ?? this.addOns,
        total: total ?? this.total,
        status: status ?? this.status,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceRequest &&
      other.id == id &&
      other.offering == offering &&
      other.car == car &&
      other.plate == plate &&
      other.fulfillment == fulfillment &&
      other.slot == slot &&
      other.total == total &&
      other.status == status &&
      _sameAddOns(other.addOns);

  bool _sameAddOns(List<AddOn> other) {
    if (other.length != addOns.length) return false;
    for (var i = 0; i < addOns.length; i++) {
      if (other[i] != addOns[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        offering,
        car,
        plate,
        fulfillment,
        slot,
        total,
        status,
        Object.hashAll(addOns),
      );
}

/// Booking total: offering price (0 when quoted after inspection), plus every
/// selected add-on, plus the provider's pickup fee when the car is being
/// collected.
///
/// A pure domain rule, shared by the booking screen's running total and the
/// service that creates the request, so the price shown and the price
/// committed can never diverge.
double calculateRequestTotal({
  required ServiceOffering offering,
  required Iterable<AddOn> addOns,
  required Fulfillment fulfillment,
}) {
  final addOnTotal = addOns.fold<double>(0, (sum, a) => sum + a.price);
  final pickup =
      fulfillment == Fulfillment.pickup ? offering.provider.pickupFee : 0.0;
  return (offering.price ?? 0) + addOnTotal + pickup;
}

/// What the UI submits to book a service.
///
/// A dedicated request DTO rather than posting the entity back: the server
/// owns the id, the price total and the initial status. [toJson] is the exact
/// `POST /service-marketplace/requests` body — ids only.
///
/// [offering] and [car] are carried alongside the ids because the caller has
/// already resolved them; the service uses them to build the response
/// locally today, and an optimistic UI update will use them later.
class CreateServiceRequestDraft {
  const CreateServiceRequestDraft({
    required this.offering,
    required this.car,
    required this.plate,
    required this.fulfillment,
    required this.slot,
    required this.addOnIds,
  });

  final ServiceOffering offering;
  final Car car;
  final String plate;
  final Fulfillment fulfillment;

  /// Human-readable slot label chosen in the booking screen.
  final String slot;

  final Set<String> addOnIds;

  JsonMap toJson() => {
        'offeringId': offering.id,
        'carId': car.id,
        'plate': plate,
        'fulfillment': fulfillment.key,
        'slot': slot,
        'addOnIds': addOnIds.toList(),
      };
}
