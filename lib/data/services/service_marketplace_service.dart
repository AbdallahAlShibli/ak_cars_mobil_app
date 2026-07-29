import 'package:collection/collection.dart';

import '../../config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../datasources/mock/mock_service_data.dart';
import '../models/add_on.dart';
import '../models/car.dart';
import '../models/escrow.dart';
import '../models/offer.dart';
import '../models/promotion.dart';
import '../models/proof_of_work.dart';
import '../models/quote.dart';
import '../models/service_category.dart';
import '../models/service_offering.dart';
import '../models/service_provider.dart';
import '../models/service_request.dart';
import '../models/service_stats.dart';
import 'mock_service_base.dart';

/// Slots a provider can be booked into, plus the ones already taken.
class BookingAvailability {
  const BookingAvailability({required this.slots, required this.bookedSlots});

  final List<String> slots;
  final Set<String> bookedSlots;

  bool isAvailable(String slot) => !bookedSlots.contains(slot);
}

/// Service discovery and booking.
///
/// Phase 2: implement `RestServiceMarketplaceService` against the
/// `/service-marketplace/*` endpoints and swap the binding in
/// `lib/di/providers.dart`.
abstract interface class ServiceMarketplaceService {
  Future<List<ServiceCategory>> fetchCategories();

  Future<List<ServiceProvider>> fetchProviders();

  /// All offerings, or only those in [categoryId] when given.
  Future<List<ServiceOffering>> fetchOfferings({String? categoryId});

  Future<ServiceOffering> fetchOffering(String offeringId);

  /// Platform announcements — how escrow works, which workshops collect cars.
  /// These carry no price; discounts are [fetchOffers].
  Future<List<Promotion>> fetchPromotions();

  /// Time-boxed workshop discounts on listed services.
  ///
  /// The server is expected to return only offers it has approved and that are
  /// in window; the repository validates them again against the live catalogue
  /// before any of them reaches a screen, because the claim they make is about
  /// money.
  Future<List<Offer>> fetchOffers();

  /// The founder's switch on one offer (home-page spec §3: offers are enabled
  /// and stopped from the founder panel in this phase, not self-served by the
  /// workshop).
  ///
  /// Only [Offer.activeByFounder] moves. Nothing here can change a price: the
  /// discount and the reference are the workshop's and the catalogue's
  /// respectively, and an approval flow that could quietly edit either would
  /// defeat the point of validating them.
  Future<Offer> setOfferActive(String offerId, {required bool active});

  /// Marketplace-wide booking counts per category. Aggregated server-side: the
  /// client can only see its own user's bookings.
  Future<List<CategoryDemand>> fetchCategoryDemand();

  /// Completed-booking counts per workshop, over a trailing window. Same
  /// server-side rule as [fetchCategoryDemand].
  Future<List<WorkshopDemand>> fetchWorkshopDemand();

  /// Customer ratings per workshop. Only workshops that have been rated appear
  /// — there is no entry, and no default, for one nobody has reviewed.
  Future<List<WorkshopRating>> fetchWorkshopRatings();

  /// Optional extras the given provider sells.
  Future<List<AddOn>> fetchAddOns(String providerId);

  /// Bookable slots for a provider on a given day, and which are taken.
  Future<BookingAvailability> fetchAvailability(
    String providerId, {
    DateTime? date,
  });

  /// Prices and places a booking, returning the created request.
  Future<ServiceRequest> createRequest(CreateServiceRequestDraft draft);

  /// Opens a "part + installation" request (spec §6).
  ///
  /// Returns a booking at [EscrowState.requested] with no amount: the workshop
  /// names the price, and it does that through [submitQuote].
  Future<ServiceRequest> createPartRequest(
    CreatePartRequestDraft draft, {
    required ServiceProvider provider,
    required Car car,
  });

  /// The workshop's itemised answer to a part request. Moves the booking to
  /// [EscrowState.quoted].
  Future<ServiceRequest> submitQuote(String requestId, Quote quote);

  /// Bookings belonging to the signed-in user.
  Future<List<ServiceRequest>> fetchRequests();

  /// Fires one escrow transition.
  ///
  /// The only way a booking's state moves. [actor] is the party the caller is
  /// acting as, and the transition table in `escrow.dart` decides whether the
  /// combination is legal — an illegal one is a [BusinessRuleException], not a
  /// silently-ignored tap. Production will enforce the same table server-side
  /// and this becomes a `POST …/requests/{id}/transitions`.
  Future<ServiceRequest> applyEscrowEvent(
    String requestId,
    EscrowEvent event, {
    required EscrowActor actor,
    ProofOfWork? proof,
    String? disputeNote,
    String? slot,
  });
}

class MockServiceMarketplaceService
    with MockServiceBase
    implements ServiceMarketplaceService {
  MockServiceMarketplaceService({required this.config});

  @override
  final AppConfig config;

  /// Bookings placed during this session, newest first.
  final List<ServiceRequest> _requests = [];

  /// Mirrors a server-side identity sequence.
  int _nextRequestNumber = 1042;

  @override
  Future<List<ServiceCategory>> fetchCategories() =>
      respond(MockServiceData.categories);

  @override
  Future<List<ServiceProvider>> fetchProviders() =>
      respond(MockServiceData.providers);

  @override
  Future<List<ServiceOffering>> fetchOfferings({String? categoryId}) => respond(
        categoryId == null
            ? MockServiceData.offerings
            : MockServiceData.offerings
                .where((o) => o.categoryId == categoryId)
                .toList(growable: false),
      );

  @override
  Future<ServiceOffering> fetchOffering(String offeringId) {
    ServiceOffering? match;
    for (final offering in MockServiceData.offerings) {
      if (offering.id == offeringId) match = offering;
    }
    return respondRequired(match, 'Offering $offeringId');
  }

  @override
  Future<List<Promotion>> fetchPromotions() =>
      respond(MockServiceData.promotions);

  @override
  Future<List<Offer>> fetchOffers() => respond(MockServiceData.offers);

  @override
  Future<Offer> setOfferActive(String offerId, {required bool active}) async {
    final index = MockServiceData.offers.indexWhere((o) => o.id == offerId);
    if (index < 0) throw NotFoundException('Offer $offerId not found');
    final updated =
        MockServiceData.offers[index].copyWith(activeByFounder: active);
    MockServiceData.offers[index] = updated;
    return respond(updated);
  }

  @override
  Future<List<CategoryDemand>> fetchCategoryDemand() =>
      respond(MockServiceData.categoryDemand);

  @override
  Future<List<WorkshopDemand>> fetchWorkshopDemand() =>
      respond(MockServiceData.workshopDemand);

  @override
  Future<List<WorkshopRating>> fetchWorkshopRatings() =>
      respond(MockServiceData.workshopRatings);

  @override
  Future<List<AddOn>> fetchAddOns(String providerId) =>
      respond(MockServiceData.addOnsByProvider[providerId] ?? const []);

  @override
  Future<BookingAvailability> fetchAvailability(
    String providerId, {
    DateTime? date,
  }) =>
      respond(
        const BookingAvailability(
          slots: MockServiceData.slots,
          bookedSlots: MockServiceData.bookedSlots,
        ),
      );

  @override
  Future<ServiceRequest> createRequest(CreateServiceRequestDraft draft) async {
    final available = await fetchAddOns(draft.offering.provider.id);
    final selected =
        available.where((a) => draft.addOnIds.contains(a.id)).toList();
    final now = DateTime.now();

    final request = ServiceRequest(
      id: '${_nextRequestNumber++}',
      offering: draft.offering,
      car: draft.car,
      plate: draft.plate,
      fulfillment: draft.fulfillment,
      slot: draft.slot,
      addOns: selected,
      total: calculateRequestTotal(
        offering: draft.offering,
        addOns: selected,
        fulfillment: draft.fulfillment,
      ),
      // A new booking always starts before the money is confirmed held: in the
      // pilot the founder confirms that by hand (spec §3, note 2).
      escrow: EscrowState.createdPendingPayment,
      createdAt: now,
      maintenanceItemKey: draft.maintenanceItemKey,
      history: [
        EscrowEntry(
          state: EscrowState.createdPendingPayment,
          actor: EscrowActor.customer,
          at: now,
        ),
      ],
    );
    _requests.insert(0, request);
    return respond(request);
  }

  @override
  Future<ServiceRequest> createPartRequest(
    CreatePartRequestDraft draft, {
    required ServiceProvider provider,
    required Car car,
  }) {
    final request = ServiceRequest.partInstall(
      id: '${_nextRequestNumber++}',
      provider: provider,
      car: car,
      plate: draft.plate,
      part: draft.part,
      fulfillment: FulfillmentX.fromKey(draft.fulfillment),
      createdAt: DateTime.now(),
    );
    _requests.insert(0, request);
    return respond(request);
  }

  @override
  Future<ServiceRequest> submitQuote(String requestId, Quote quote) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) {
      throw NotFoundException('Service request $requestId not found');
    }
    final current = _requests[index];
    if (current.escrow != EscrowState.requested) {
      throw BusinessRuleException(
        'Cannot quote a booking in ${current.escrow.key}',
        code: 'quote_not_allowed',
      );
    }
    final updated = current.apply(
      EscrowEvent.submitQuote,
      actor: EscrowActor.workshop,
      quote: quote,
    );
    _requests[index] = updated;
    return respond(updated);
  }

  @override
  Future<List<ServiceRequest>> fetchRequests() =>
      respond(List<ServiceRequest>.unmodifiable(_requests));

  @override
  Future<ServiceRequest> applyEscrowEvent(
    String requestId,
    EscrowEvent event, {
    required EscrowActor actor,
    ProofOfWork? proof,
    String? disputeNote,
    String? slot,
  }) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) {
      throw NotFoundException('Service request $requestId not found');
    }
    final current = _requests[index];
    final transition = current.escrow.transitions
        .where((t) => t.event == event && t.actor == actor)
        .firstOrNull;
    if (transition == null) {
      throw BusinessRuleException(
        '${actor.key} cannot fire ${event.key} from ${current.escrow.key}',
        code: 'escrow_transition_not_allowed',
      );
    }
    // The payload rule the transition table cannot carry: a part-and-fit job
    // needs the part's box in evidence before it may claim completion
    // (spec §6). Raised rather than silently ignored — the workshop needs to
    // know why its submission did not land.
    if (event == EscrowEvent.submitProof &&
        !current.proofSatisfiesRules(proof)) {
      throw BusinessRuleException(
        'A part-and-fit job needs proof of the part itself before completion',
        code: 'proof_missing_part_box_photo',
      );
    }
    final updated = current.apply(
      event,
      actor: actor,
      proof: proof,
      disputeNote: disputeNote,
      slot: slot,
    );
    _requests[index] = updated;
    return respond(updated);
  }
}
