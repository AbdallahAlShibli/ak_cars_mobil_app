import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/add_on.dart';
import 'package:ak_cars_mobil_app/data/models/audit_entry.dart';
import 'package:ak_cars_mobil_app/data/models/car.dart';
import 'package:ak_cars_mobil_app/data/models/escrow.dart';
import 'package:ak_cars_mobil_app/data/models/offer.dart';
import 'package:ak_cars_mobil_app/data/models/payout_record.dart';
import 'package:ak_cars_mobil_app/data/models/promotion.dart';
import 'package:ak_cars_mobil_app/data/models/proof_of_work.dart';
import 'package:ak_cars_mobil_app/data/models/quote.dart';
import 'package:ak_cars_mobil_app/data/models/service_category.dart';
import 'package:ak_cars_mobil_app/data/models/service_offering.dart';
import 'package:ak_cars_mobil_app/data/models/service_provider.dart';
import 'package:ak_cars_mobil_app/data/models/service_request.dart';
import 'package:ak_cars_mobil_app/data/models/service_stats.dart';
import 'package:ak_cars_mobil_app/data/models/workshop_application.dart';
import 'package:ak_cars_mobil_app/data/services/service_marketplace_service.dart';
import 'package:collection/collection.dart';

import 'data/mock_seed.dart';
import 'data/mock_service_data.dart';
import 'fake_service_base.dart';

class MockServiceMarketplaceService
    with MockServiceBase
    implements ServiceMarketplaceService {
  MockServiceMarketplaceService({this.seeded = true});

  /// Whether to start from [MockSeed]'s demo world.
  ///
  /// On by default — a test about how the panels look with real data wants the
  /// seeded marketplace. A test about one specific booking turns it off so its
  /// assertions are about the booking it placed rather than about forty it did
  /// not.
  ///
  /// Only the *bookings* are seeded conditionally. The workshop roster is not:
  /// it is reference data every screen reads, and an empty marketplace is not
  /// a state the app supports.
  final bool seeded;

  /// The marketplace's bookings, newest first — the seeded world plus
  /// everything placed during the test.
  late final List<ServiceRequest> _requests =
      seeded ? [...MockSeed.requests] : <ServiceRequest>[];

  /// Ids of the bookings *this device's user* placed. The seeded ones belong
  /// to other people, and a customer's own list must not claim them.
  final Set<String> _mine = {};

  /// The workshop roster. A mutable copy, because onboarding decisions move
  /// workshops along it during a test.
  final List<ServiceProvider> _providers = [...MockSeed.providers];

  final List<PayoutRecord> _payouts = [...MockSeed.payouts];
  final List<AuditEntry> _audit = [...MockSeed.audit];

  /// Mirrors a server-side identity sequence. Starts above the seeded ids so a
  /// booking placed in this session can never collide with a seeded one.
  int _nextRequestNumber = 3001;
  int _nextPayoutNumber = 100;
  int _nextAuditNumber = 100;
  int _nextProviderNumber = 100;

  @override
  Future<List<ServiceCategory>> fetchCategories() =>
      respond(MockServiceData.categories);

  @override
  Future<List<ServiceProvider>> fetchProviders() =>
      respond(List<ServiceProvider>.unmodifiable(_providers));

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
    _mine.add(request.id);
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
    _mine.add(request.id);
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
  Future<List<ServiceRequest>> fetchRequests() => respond(
        List<ServiceRequest>.unmodifiable(
          [for (final r in _requests) if (_mine.contains(r.id)) r],
        ),
      );

  @override
  Future<List<ServiceRequest>> fetchOperatorQueue() =>
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

  // ------------------------------------------------- onboarding (§5, §11)

  @override
  Future<ServiceProvider> setProviderStage(
    String providerId,
    ProviderOnboardingStage stage, {
    String? reason,
  }) {
    final index = _providers.indexWhere((p) => p.id == providerId);
    if (index < 0) throw NotFoundException('Provider $providerId not found');

    final trimmed = reason?.trim();
    // §14: "لا تسمح برفض تسجيل ورشة بلا سبب مكتوب". Enforced at the data
    // layer so it holds for every caller, not only for the panel that
    // happens to render a text field today.
    if (stage == ProviderOnboardingStage.suspended &&
        (trimmed == null || trimmed.isEmpty)) {
      throw BusinessRuleException(
        'Suspending or rejecting a workshop requires a written reason',
        code: 'provider_rejection_reason_required',
      );
    }

    final updated = _providers[index].copyWith(
      stage: stage,
      stageSince: DateTime.now(),
      rejectionReason: stage == ProviderOnboardingStage.suspended ? trimmed : null,
      // Moving off `suspended` drops the old reason — a re-approved workshop
      // that keeps showing its owner why it was once rejected is a bug.
      clearRejectionReason: stage != ProviderOnboardingStage.suspended,
    );
    _providers[index] = updated;
    return respond(updated);
  }

  @override
  Future<ServiceProvider> submitWorkshopApplication({
    required String ownerUserId,
    required WorkshopApplication application,
    required String region,
  }) {
    // Re-submitting after a rejection updates the existing application rather
    // than opening a second one (§11 step 5) — otherwise the founder's queue
    // fills with duplicates of the same workshop.
    final existing = _providers.indexWhere((p) => p.ownerUserId == ownerUserId);
    final now = DateTime.now();

    final provider = ServiceProvider(
      id: existing >= 0 ? _providers[existing].id : 'w-${_nextProviderNumber++}',
      name: L(
        application.businessNameAr,
        application.businessNameEn?.trim().isNotEmpty ?? false
            ? application.businessNameEn!.trim()
            : application.businessNameAr,
      ),
      area: application.area,
      region: region,
      // Nothing has measured a distance to a workshop that is not live yet, and
      // 0 would read as "next door" on every card that prints it.
      distanceKm: 0,
      verified: false,
      stage: ProviderOnboardingStage.documentsSubmitted,
      stageSince: now,
      crDocument: application.crDocument,
      ownerUserId: ownerUserId,
      fulfillments: application.fulfillments,
      crNumber: application.crNumber,
      vatNumber: application.vatNumber,
    );

    if (existing >= 0) {
      _providers[existing] = provider;
    } else {
      _providers.add(provider);
    }
    return respond(provider);
  }

  /// How many times [fetchPayouts] has been asked for — the founder-ledger
  /// half of `ServiceMarketplaceRepositoryImpl.warmUp` calls this (and
  /// [fetchAuditLog]) only when `includeFounderLedger: true`, so a test can
  /// use this to check that a sign-out's re-warm actually asked for it to be
  /// dropped rather than merely passing a flag nothing reads.
  int fetchPayoutsCallCount = 0;

  @override
  Future<List<PayoutRecord>> fetchPayouts() {
    fetchPayoutsCallCount++;
    return respond(List<PayoutRecord>.unmodifiable(_payouts));
  }

  @override
  Future<PayoutRecord> recordPayout(PayoutRecord payout) {
    final stored = payout.copyWith(id: 'po-${_nextPayoutNumber++}');
    _payouts.insert(0, stored);
    return respond(stored);
  }

  @override
  Future<List<AuditEntry>> fetchAuditLog() =>
      respond(List<AuditEntry>.unmodifiable(_audit));

  @override
  Future<AuditEntry> appendAudit(AuditEntry entry) {
    final stored = entry.copyWith(id: 'au-${_nextAuditNumber++}');
    _audit.insert(0, stored);
    return respond(stored);
  }
}
