import '../../core/json/json_utils.dart';
import 'add_on.dart';
import 'car.dart';
import 'escrow.dart';
import 'proof_of_work.dart';
import 'quote.dart';
import 'service_offering.dart';
import 'service_provider.dart';

/// One entry in a booking's escrow audit trail.
///
/// The founder's panel resolves disputes from this, so "who moved it and
/// when" is stored per transition rather than reconstructed from the current
/// state. It is also the only honest way to show a customer *when* their
/// approval window started.
class EscrowEntry {
  const EscrowEntry({
    required this.state,
    required this.actor,
    required this.at,
    this.event,
  });

  final EscrowState state;
  final EscrowActor actor;
  final DateTime at;

  /// The event that produced [state]. Null for the initial entry, which no
  /// event created.
  final EscrowEvent? event;

  factory EscrowEntry.fromJson(JsonMap json) => EscrowEntry(
    state: json.enumOr(
      'state',
      EscrowState.values,
      EscrowState.createdPendingPayment,
    ),
    actor: json.enumOr('actor', EscrowActor.values, EscrowActor.system),
    at: json.dateTimeOr('at', DateTime.now()),
    event: json['event'] == null
        ? null
        : json.enumOr(
            'event',
            EscrowEvent.values,
            EscrowEvent.handOffForApproval,
          ),
  );

  JsonMap toJson() => {
    'state': state.key,
    'actor': actor.key,
    'at': at.toIso8601String(),
    'event': event?.key,
  };

  @override
  bool operator ==(Object other) =>
      other is EscrowEntry &&
      other.state == state &&
      other.actor == actor &&
      other.at == at &&
      other.event == event;

  @override
  int get hashCode => Object.hash(state, actor, at, event);
}

/// A booking placed against a [ServiceOffering].
///
/// [escrow] is the single source of truth for where the booking stands — see
/// `escrow.dart` for the state machine and its transition table.
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
    required this.escrow,
    required this.createdAt,
    this.history = const [],
    this.proof,
    this.awaitingApprovalSince,
    this.disputeNote = '',
    this.maintenanceItemKey,
    this.type = BookingType.catalogService,
    this.partRequest,
    this.quote,
    this.assignedStaffId,
  });

  /// Opens a "part + installation" request (spec §6).
  ///
  /// It starts at [EscrowState.requested] rather than
  /// [EscrowState.createdPendingPayment] because there is no amount yet — and
  /// [total] is 0 for the same reason. Anything else would be the app naming a
  /// price before the workshop has.
  factory ServiceRequest.partInstall({
    required String id,
    required ServiceProvider provider,
    required Car car,
    required String plate,
    required PartRequest part,
    required Fulfillment fulfillment,
    required DateTime createdAt,
  }) => ServiceRequest(
    id: id,
    offering: ServiceOffering.partInstall(
      provider: provider,
      partDescription: part.description,
    ),
    car: car,
    plate: plate,
    fulfillment: fulfillment,
    // Scheduling happens once there is a job to schedule; until the price
    // is agreed there is nothing to book a bay for.
    slot: '',
    addOns: const [],
    total: 0,
    escrow: EscrowState.requested,
    createdAt: createdAt,
    type: BookingType.customQuote,
    partRequest: part,
    history: [
      EscrowEntry(
        state: EscrowState.requested,
        actor: EscrowActor.customer,
        at: createdAt,
      ),
    ],
  );

  final String id;
  final ServiceOffering offering;
  final Car car;
  final String plate;
  final Fulfillment fulfillment;
  final String slot;
  final List<AddOn> addOns;
  final double total;

  final EscrowState escrow;
  final DateTime createdAt;
  final List<EscrowEntry> history;

  /// The workshop's completion evidence. Null until it submits.
  final ProofOfWork? proof;

  /// When the approval window opened. The 72-hour automatic release is
  /// measured from here, not from the proof's own timestamp, so a proof that
  /// sat unprocessed cannot shorten the customer's window.
  final DateTime? awaitingApprovalSince;

  /// What the customer wrote when they raised an issue. Shown verbatim to the
  /// founder — a dispute summarised by the app is a dispute mis-stated.
  final String disputeNote;

  /// The maintenance schedule line this booking was made for, when it started
  /// from one — a [MaintenanceType] key or a custom item's id, always read
  /// against [car]'s own book.
  ///
  /// It is context, not an outcome: the record is written only if and when the
  /// booking reaches [EscrowState.releasedToWorkshop]. A cancelled, rejected,
  /// refunded or still-disputed booking carries this field and resets nothing.
  final String? maintenanceItemKey;

  /// Which of the two transactions this is. Both ride the same escrow machine;
  /// [BookingType.customQuote] simply enters it earlier, in the quote phase.
  final BookingType type;

  /// What the customer asked for, for a [BookingType.customQuote] booking.
  /// Null on a catalogue booking, which orders a named service instead.
  final PartRequest? partRequest;

  /// The workshop's priced answer. Null until it submits one; once
  /// [EscrowState.quoteAccepted] is reached, [total] is this quote's total and
  /// nothing else.
  final Quote? quote;

  /// Which of the workshop's own staff is doing this job. Independent of
  /// [escrow] — assigning a technician is not an escrow transition.
  final String? assignedStaffId;

  /// True while the booking is waiting for a price rather than for work.
  bool get inQuotePhase => escrow.isQuotePhase;

  /// The part warranty the workshop offered, in days — the *workshop's* own
  /// guarantee on the part, which starts where the payment escrow ends. Null
  /// when none was offered, which is not the same as zero days.
  int? get partWarrantyDays => quote?.warrantyDays;

  /// Whether this booking's completion proof satisfies the rules for its type
  /// (spec §3). Both rules gate the move to `proofSubmitted`.
  ///
  /// 1. **Every job needs at least one photo or video.** The customer releases
  ///    real money on the strength of this, and notes alone are a claim rather
  ///    than evidence — an escrow that settles on an unevidenced assertion is
  ///    not an escrow. This is why there is no "notes only" proof any more.
  /// 2. **A part-and-fitting job must additionally show the part's box or
  ///    label** (spec §6): the customer bought a specific part from a specific
  ///    brand, and only the packaging speaks to which one actually arrived.
  ///
  /// Rule 2 is a declaration, not a verification — the app cannot inspect a
  /// photograph — which is exactly why the customer is shown that the workshop
  /// made it.
  bool proofSatisfiesRules(ProofOfWork? candidate) {
    final evidence = candidate ?? proof;
    if (evidence == null || !evidence.hasMedia) return false;
    if (type != BookingType.customQuote) return true;
    return evidence.includesPartBoxPhoto;
  }

  /// When the escrow releases itself if the customer neither approves nor
  /// objects (spec §3, note 1). Null unless the window is actually open.
  DateTime? approvalDeadline(Duration window) =>
      awaitingApprovalSince?.add(window);

  /// The furthest step of the customer's story this booking actually reached,
  /// read from [history] rather than inferred from the current state.
  ///
  /// The three off-path endings say nothing on their own about how far the
  /// work got: a booking cancelled before payment and one refunded after the
  /// workshop rejected it both sit on the tracking screen's last row, but only
  /// the second ever had funds held. Without this the timeline would tick every
  /// earlier step green on a booking where none of them happened.
  int get reachedStepIndex {
    var reached = escrow.reachedStepIndex ?? 0;
    for (final entry in history) {
      final at = entry.state.reachedStepIndex;
      if (at != null && at > reached) reached = at;
    }
    return reached;
  }

  /// When this booking entered the state it is in now, read from [history].
  ///
  /// Falls back to [createdAt] for a booking that has not moved since it was
  /// made — which is the same answer, since the state it is in is the one it
  /// started in.
  ///
  /// This is the only honest basis for "how long has this been sitting here":
  /// it comes from the audit trail the machine already writes, so an operator
  /// queue can sort by neglect without the app inventing a clock.
  DateTime get inCurrentStateSince {
    for (final entry in history.reversed) {
      if (entry.state == escrow) return entry.at;
    }
    return createdAt;
  }

  /// How long it has been sitting in its current state.
  Duration stalledFor({DateTime? now}) =>
      (now ?? DateTime.now()).difference(inCurrentStateSince);

  /// Whether that deadline has passed as of [now].
  bool autoReleaseDue(Duration window, {DateTime? now}) {
    final deadline = approvalDeadline(window);
    if (deadline == null || escrow != EscrowState.awaitingApproval) {
      return false;
    }
    return !(now ?? DateTime.now()).isBefore(deadline);
  }

  /// Applies [event] if the transition table allows it from the current
  /// state, returning the updated booking — or `this` unchanged when it does
  /// not. The one place a booking's escrow field is allowed to move.
  ServiceRequest apply(
    EscrowEvent event, {
    required EscrowActor actor,
    DateTime? at,
    ProofOfWork? proof,
    String? disputeNote,
    Quote? quote,
    String? slot,
  }) {
    final next = escrow.on(event);
    if (next == null) return this;
    // The one rule the table cannot express, because it is about the payload
    // rather than the states: a part-and-fit job cannot claim completion
    // without evidence of the part itself.
    if (event == EscrowEvent.submitProof &&
        !proofSatisfiesRules(proof ?? this.proof)) {
      return this;
    }
    final when = at ?? DateTime.now();
    final agreed = quote ?? this.quote;
    return copyWith(
      escrow: next,
      proof: proof ?? this.proof,
      disputeNote: disputeNote ?? this.disputeNote,
      quote: agreed,
      slot: slot ?? this.slot,
      // Accepting the quote is what gives the booking an amount. Before that
      // the total is 0 because nothing has been priced, and after it the total
      // is the quote's total — never a number from anywhere else.
      total: event == EscrowEvent.acceptQuote && agreed != null
          ? agreed.total
          : total,
      awaitingApprovalSince: next == EscrowState.awaitingApproval
          ? when
          : awaitingApprovalSince,
      history: [
        ...history,
        EscrowEntry(state: next, actor: actor, at: when, event: event),
      ],
    );
  }

  factory ServiceRequest.fromJson(JsonMap json) => ServiceRequest(
    id: json.requireString('id'),
    offering: ServiceOffering.fromJson(json.requireObject('offering')),
    car: Car.fromJson(json.requireObject('car')),
    plate: json.stringOr('plate', ''),
    fulfillment: FulfillmentX.fromKey(json.stringOrNull('fulfillment')),
    slot: json.stringOr('slot', ''),
    addOns: json.objectList('addOns').map(AddOn.fromJson).toList(),
    total: json.doubleOr('total', 0),
    escrow: json.enumOr(
      'escrow',
      EscrowState.values,
      EscrowState.createdPendingPayment,
    ),
    createdAt: json.dateTimeOr('createdAt', DateTime.now()),
    history: json.objectList('history').map(EscrowEntry.fromJson).toList(),
    proof: json.objectOrNull('proof') == null
        ? null
        : ProofOfWork.fromJson(json.requireObject('proof')),
    awaitingApprovalSince: json.dateTimeOrNull('awaitingApprovalSince'),
    disputeNote: json.stringOr('disputeNote', ''),
    maintenanceItemKey: json.stringOrNull('maintenanceItemKey'),
    type: BookingType.fromKey(json.stringOrNull('type')),
    partRequest: json.objectOrNull('partRequest') == null
        ? null
        : PartRequest.fromJson(json.requireObject('partRequest')),
    quote: json.objectOrNull('quote') == null
        ? null
        : Quote.fromJson(json.requireObject('quote')),
    assignedStaffId: json.stringOrNull('assignedStaffId'),
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
    'escrow': escrow.key,
    'createdAt': createdAt.toIso8601String(),
    'history': [for (final h in history) h.toJson()],
    'proof': proof?.toJson(),
    'awaitingApprovalSince': awaitingApprovalSince?.toIso8601String(),
    'disputeNote': disputeNote,
    'maintenanceItemKey': maintenanceItemKey,
    'type': type.key,
    'partRequest': partRequest?.toJson(),
    'quote': quote?.toJson(),
    'assignedStaffId': assignedStaffId,
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
    EscrowState? escrow,
    DateTime? createdAt,
    List<EscrowEntry>? history,
    ProofOfWork? proof,
    DateTime? awaitingApprovalSince,
    String? disputeNote,
    String? maintenanceItemKey,
    BookingType? type,
    PartRequest? partRequest,
    Quote? quote,
    String? assignedStaffId,
  }) => ServiceRequest(
    id: id ?? this.id,
    offering: offering ?? this.offering,
    car: car ?? this.car,
    plate: plate ?? this.plate,
    fulfillment: fulfillment ?? this.fulfillment,
    slot: slot ?? this.slot,
    addOns: addOns ?? this.addOns,
    total: total ?? this.total,
    escrow: escrow ?? this.escrow,
    createdAt: createdAt ?? this.createdAt,
    history: history ?? this.history,
    proof: proof ?? this.proof,
    awaitingApprovalSince: awaitingApprovalSince ?? this.awaitingApprovalSince,
    disputeNote: disputeNote ?? this.disputeNote,
    maintenanceItemKey: maintenanceItemKey ?? this.maintenanceItemKey,
    type: type ?? this.type,
    partRequest: partRequest ?? this.partRequest,
    quote: quote ?? this.quote,
    assignedStaffId: assignedStaffId ?? this.assignedStaffId,
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
      other.escrow == escrow &&
      other.createdAt == createdAt &&
      other.proof == proof &&
      other.awaitingApprovalSince == awaitingApprovalSince &&
      other.disputeNote == disputeNote &&
      other.maintenanceItemKey == maintenanceItemKey &&
      other.type == type &&
      other.partRequest == partRequest &&
      other.quote == quote &&
      other.assignedStaffId == assignedStaffId &&
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
    escrow,
    createdAt,
    proof,
    awaitingApprovalSince,
    disputeNote,
    maintenanceItemKey,
    type,
    partRequest,
    quote,
    assignedStaffId,
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
  final pickup = fulfillment == Fulfillment.pickup
      ? offering.provider.pickupFee
      : 0.0;
  return (offering.price ?? 0) + addOnTotal + pickup;
}

/// What the UI submits to book a service.
///
/// A dedicated request DTO rather than posting the entity back: the server
/// owns the id, the price total and the initial escrow state. [toJson] is the
/// exact `POST /service-marketplace/requests` body — ids only.
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
    this.maintenanceItemKey,
  });

  final ServiceOffering offering;
  final Car car;
  final String plate;
  final Fulfillment fulfillment;

  /// The raw "HH:mm" slot key chosen in the booking screen — what
  /// `GET .../slots` returned and what the server matches its own schedule
  /// against (`docs/api_contract.md`), not a localized display string. Empty
  /// when the fulfillment has no slot concept (roadside/ASAP).
  final String slot;

  final Set<String> addOnIds;

  /// The maintenance schedule line this booking came from, when the owner
  /// started it from their car's maintenance book. Carried so the completed
  /// booking knows which car and which item to log against.
  final String? maintenanceItemKey;

  JsonMap toJson() => {
    'offeringId': offering.id,
    'carId': car.id,
    'plate': plate,
    'fulfillment': fulfillment.key,
    'slot': slot,
    'addOnIds': addOnIds.toList(),
    'maintenanceItemKey': maintenanceItemKey,
  };
}
