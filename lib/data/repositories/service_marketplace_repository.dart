import 'package:collection/collection.dart';

import '../../config/home_ranking_config.dart';
import '../../core/error/app_exception.dart';
import '../models/add_on.dart';
import '../models/car.dart';
import '../models/escrow.dart';
import '../models/offer.dart';
import '../models/powertrain.dart';
import '../models/promotion.dart';
import '../models/proof_of_work.dart';
import '../models/quote.dart';
import '../models/recommendation.dart';
import '../models/service_category.dart';
import '../models/service_offering.dart';
import '../models/service_provider.dart';
import '../models/service_request.dart';
import '../models/service_stats.dart';
import '../services/service_marketplace_service.dart';
import 'warm_cache.dart';

/// A category with the booking count that ranked it.
typedef RankedCategory = ({ServiceCategory category, CategoryDemand demand});

/// A workshop with the rating that ranked it.
typedef RankedWorkshop = ({ServiceProvider provider, WorkshopRating rating});

/// A workshop with the completed-booking count that ranked it.
typedef RequestedWorkshop = ({ServiceProvider provider, WorkshopDemand demand});

/// A live offer, resolved against the catalogue so a caller never has to look
/// the service or the workshop up again — and so the price on the card and the
/// price on the service page are literally the same object.
typedef LiveOffer = ({Offer offer, ServiceOffering offering});

/// Service discovery and booking.
///
/// The catalogue side (categories, providers, offerings, add-ons, slots) is
/// warmed at bootstrap and read synchronously; the transactional side
/// (creating and advancing a request) stays asynchronous.
abstract interface class ServiceMarketplaceRepository {
  Future<void> warmUp();

  List<ServiceCategory> get categories;

  /// Categories rendered as big "Car service" package cards.
  List<ServiceCategory> get primaryCategories;

  /// Categories rendered as "Other services" tiles. Excludes the
  /// powertrain-specific ones, which get their own rail — see [evCategories].
  List<ServiceCategory> get otherCategories;

  /// Categories that only exist for cars that plug in (EV health check, HV
  /// battery diagnostic, charging and home-charger work, roadside charging).
  ///
  /// Surfaced as its own rail rather than mixed into "Other services": an EV
  /// owner should find these first, and a petrol owner should not have to
  /// scroll past four services their car cannot use.
  List<ServiceCategory> get evCategories;

  /// The categories a car with this [powertrain] can actually book, in
  /// catalogue order with the relevant ones first. A null powertrain (the
  /// owner has not said) returns everything, unreordered.
  List<ServiceCategory> categoriesFor(Powertrain? powertrain);

  List<ServiceProvider> get providers;

  /// The raw catalogue: published prices, no discounts applied. This is the
  /// reference an offer is validated against, so it must never be discounted
  /// itself — a discount that could validate against a discounted price would
  /// validate against itself.
  ///
  /// Screens want [pricedOfferings]; only offer validation wants this.
  List<ServiceOffering> get offerings;

  /// The catalogue with every live discount applied — what a list of services
  /// should show, and the only version any screen should price from.
  List<ServiceOffering> get pricedOfferings;

  /// Workshops holding a given capability, optionally within one governorate.
  List<ServiceProvider> providersWith(
    ProviderCapability capability, {
    String? region,
  });

  /// Governorates that actually have at least one provider, in catalogue
  /// order. The region filter is built from this so it can never offer a
  /// governorate the marketplace does not serve.
  List<String> get providerRegions;

  /// Offerings within one category, optionally limited to one governorate.
  List<ServiceOffering> offeringsFor(String categoryId, {String? region});

  /// How many distinct providers serve a category, optionally within one
  /// governorate.
  int providerCountFor(String categoryId, {String? region});

  /// Cheapest real price in a category, or null when everything in scope is
  /// quote-only. Derived from the offerings rather than stored on the
  /// category, so a "from OMR x" label can never contradict the list it
  /// sits above.
  double? fromPriceFor(String categoryId, {String? region});

  ServiceOffering? offeringById(String offeringId);

  /// The offering as it should be *charged* right now: the catalogue entry,
  /// with a live offer's discount already applied to its price.
  ///
  /// This is the one every booking path reads. Handing the discounted offering
  /// to the booking screen — rather than teaching the booking screen, the
  /// total, the escrow amount and the receipt each to remember a discount —
  /// is what stops the home page advertising 36 and the confirmation charging
  /// 45. [offeringById] stays the untouched catalogue truth, which is what the
  /// struck-through "was" price is drawn from.
  ServiceOffering? pricedOffering(String offeringId);

  /// Every offer that passes all six validation rules, in the user's scope.
  ///
  /// [region] limits to campaigns running there; [powertrain] drops work the
  /// car cannot use — an engine-oil discount is not advertised to an electric
  /// car however good the price is.
  List<LiveOffer> liveOffers({String? region, Powertrain? powertrain});

  /// The live, valid offer on one offering, or null. Used by every price
  /// surface in the app so none of them can disagree with the home page.
  Offer? offerFor(String offeringId);

  /// Every offer the platform holds, each with the reason it is not being
  /// shown (null when it is live). The founder panel's view — it must be able
  /// to say *why* a workshop's offer is not appearing.
  List<({Offer offer, OfferRejection? rejection})> auditOffers();

  /// Enables or stops one offer, on the founder's authority.
  ///
  /// Switching an offer *on* does not make it valid: the other five rules are
  /// still checked on every read, so approving an offer whose reference price
  /// is wrong leaves it just as invisible, with the reason still readable in
  /// [auditOffers].
  Future<Offer> setOfferActive(String offerId, {required bool active});

  /// The cheapest offering in a category, or null when nothing in scope sells
  /// it. Quote-only offerings lose to any priced one and win only when there is
  /// no priced offering at all — a card that says "from OMR 12" must open the
  /// workshop charging 12.
  ServiceOffering? cheapestOfferingFor(String categoryId, {String? region});

  /// Live promoted offers, for the offers rail.
  ///
  /// Filtered to campaigns that have not ended, that run in [region], whose
  /// target still resolves in this catalogue (a card whose tap lands nowhere is
  /// worse than no card), and that sell work a car with this [powertrain] can
  /// actually use — an engine-oil package is not advertised to an electric car,
  /// however well it is selling.
  List<Promotion> promotions({String? region, Powertrain? powertrain});

  /// Marketplace-wide booking counts per category, as the API reports them.
  List<CategoryDemand> get categoryDemand;

  /// Completed-booking counts per workshop, as the API reports them.
  List<WorkshopDemand> get workshopDemand;

  /// Categories ranked by how much the whole marketplace booked them.
  ///
  /// [powertrain] hides categories the user's car cannot book (an HV battery
  /// diagnostic for a petrol Camry) without touching the counts, which stay
  /// marketplace-wide because that is what they measure.
  List<RankedCategory> mostBookedCategories({
    Powertrain? powertrain,
    int limit = 5,
  });

  /// One workshop's rating, or null when nobody has rated it yet.
  WorkshopRating? ratingFor(String providerId);

  /// Workshops ranked by customer rating.
  ///
  /// A workshop needs at least [minReviews] ratings to be ranked: a 4.9 from
  /// four people is not evidence that it is the best workshop in the country,
  /// and a leaderboard that says otherwise is misleading in the direction that
  /// costs a customer money. Ties break on the review count, then on distance.
  /// Only platform-approved workshops are ranked (spec §3): a leaderboard is
  /// the strongest endorsement the front page makes, and it is not made on
  /// behalf of a workshop the platform has not vouched for.
  List<RankedWorkshop> topRatedWorkshops({
    String? region,
    int limit = 5,
    int minReviews = HomeRankingConfig.minReviewsForRanking,
  });

  /// Approved workshops ranked by how many bookings they actually completed in
  /// the trailing window (spec §4, "الأكثر طلباً").
  ///
  /// Completed, not requested: the count comes from bookings that reached
  /// `releasedToWorkshop`. A workshop the aggregate has never seen, or that has
  /// completed nothing, is absent rather than ranked at zero.
  List<RequestedWorkshop> mostRequestedWorkshops({String? region, int limit = 5});

  /// Approved workshops nearest first — the honest fallback for a marketplace
  /// too young to have a ratings board (spec §5).
  ///
  /// Deliberately a different method with a different name, because it is a
  /// different claim: these workshops are approved and close, and calling them
  /// "top rated" when nobody has rated them would be the exact fabrication the
  /// spec forbids.
  List<ServiceProvider> approvedWorkshops({String? region, int limit = 5});

  /// Optional extras the given provider sells.
  List<AddOn> addOnsFor(String providerId);

  /// Bookable slots for a provider, and which are already taken.
  BookingAvailability availabilityFor(String providerId);

  Future<ServiceRequest> createRequest(CreateServiceRequestDraft draft);

  /// Opens a "part + installation" request against one workshop (spec §6).
  ///
  /// Resolves the provider and the car from the ids on [draft] — a caller
  /// passes ids, exactly as it would to a REST endpoint.
  Future<ServiceRequest> createPartRequest(
    CreatePartRequestDraft draft, {
    required Car car,
  });

  /// The workshop's itemised quote for a part request.
  Future<ServiceRequest> submitQuote(String requestId, Quote quote);

  Future<List<ServiceRequest>> fetchRequests();

  /// Fires one escrow transition on behalf of [actor]. See `escrow.dart` for
  /// the table that decides whether it is allowed.
  Future<ServiceRequest> applyEscrowEvent(
    String requestId,
    EscrowEvent event, {
    required EscrowActor actor,
    ProofOfWork? proof,
    String? disputeNote,
    String? slot,
  });
}

class ServiceMarketplaceRepositoryImpl implements ServiceMarketplaceRepository {
  ServiceMarketplaceRepositoryImpl(this._service);

  final ServiceMarketplaceService _service;

  final _categories = WarmCache<List<ServiceCategory>>(fallback: const []);
  final _providers = WarmCache<List<ServiceProvider>>(fallback: const []);
  final _offerings = WarmCache<List<ServiceOffering>>(fallback: const []);
  final _promotions = WarmCache<List<Promotion>>(fallback: const []);
  final _offers = WarmCache<List<Offer>>(fallback: const []);
  final _demand = WarmCache<List<CategoryDemand>>(fallback: const []);
  final _workshopDemand = WarmCache<List<WorkshopDemand>>(fallback: const []);
  final _ratings = WarmCache<List<WorkshopRating>>(fallback: const []);

  /// Add-ons and slots are per-provider, so they are warmed lazily and cached
  /// as they are asked for rather than fetched for every provider up front.
  final Map<String, List<AddOn>> _addOns = {};
  final Map<String, BookingAvailability> _availability = {};

  @override
  Future<void> warmUp() async {
    await Future.wait([
      _categories.load(_service.fetchCategories),
      _providers.load(_service.fetchProviders),
      _offerings.load(() => _service.fetchOfferings()),
      _promotions.load(_service.fetchPromotions),
      _offers.load(_service.fetchOffers),
      _demand.load(_service.fetchCategoryDemand),
      _workshopDemand.load(_service.fetchWorkshopDemand),
      _ratings.load(_service.fetchWorkshopRatings),
    ]);
    await Future.wait([
      for (final provider in _providers.value) _warmProvider(provider.id),
    ]);
  }

  Future<void> _warmProvider(String providerId) async {
    _addOns[providerId] = await _service.fetchAddOns(providerId);
    _availability[providerId] = await _service.fetchAvailability(providerId);
  }

  @override
  List<ServiceCategory> get categories => _categories.value;

  @override
  List<ServiceCategory> get primaryCategories =>
      categories.where((c) => c.primary).toList(growable: false);

  @override
  List<ServiceCategory> get otherCategories =>
      categories.where((c) => !c.primary && !c.evOnly).toList(growable: false);

  @override
  List<ServiceCategory> get evCategories =>
      categories.where((c) => c.evOnly).toList(growable: false);

  @override
  List<ServiceCategory> categoriesFor(Powertrain? powertrain) {
    final bookable =
        categories.where((c) => c.appliesTo(powertrain)).toList(growable: false);
    if (powertrain == null || !powertrain.plugsIn) return bookable;
    // An EV owner's own services first — the rest still follow, because an EV
    // needs tyres, AC and detailing like any other car.
    return [
      ...bookable.where((c) => c.evOnly),
      ...bookable.where((c) => !c.evOnly),
    ];
  }

  @override
  List<ServiceProvider> get providers => _providers.value;

  @override
  List<ServiceProvider> providersWith(
    ProviderCapability capability, {
    String? region,
  }) =>
      providers
          .where((p) =>
              p.capabilities.contains(capability) &&
              (region == null || p.region == region))
          .toList(growable: false);

  @override
  List<ServiceOffering> get offerings => _offerings.value;

  @override
  List<ServiceOffering> get pricedOfferings => [
        for (final offering in offerings) pricedOffering(offering.id)!,
      ];

  @override
  List<String> get providerRegions => {
        for (final provider in providers)
          if (provider.region.isNotEmpty) provider.region,
      }.toList(growable: false);

  /// Priced, not raw: every list of offerings the app shows is a list of
  /// things the user could book right now, so each one carries the price they
  /// would actually pay. The raw catalogue price stays reachable through
  /// [offerings] / [offeringById], which is what offer validation compares
  /// against — and it has to, or a discount would validate itself.
  @override
  List<ServiceOffering> offeringsFor(String categoryId, {String? region}) => [
        for (final offering in offerings)
          if (offering.categoryId == categoryId &&
              (region == null || offering.provider.region == region))
            pricedOffering(offering.id)!,
      ];

  @override
  int providerCountFor(String categoryId, {String? region}) =>
      offeringsFor(categoryId, region: region)
          .map((o) => o.provider.id)
          .toSet()
          .length;

  @override
  double? fromPriceFor(String categoryId, {String? region}) =>
      cheapestOfferingFor(categoryId, region: region)?.price;

  @override
  ServiceOffering? offeringById(String offeringId) {
    for (final offering in offerings) {
      if (offering.id == offeringId) return offering;
    }
    return null;
  }

  @override
  ServiceOffering? pricedOffering(String offeringId) {
    final offering = offeringById(offeringId);
    if (offering == null) return null;
    final offer = offerFor(offeringId);
    if (offer == null) return offering;
    return offering.copyWith(price: offer.discountedPrice);
  }

  /// Every "from OMR x" in the app is this number, so a discount reaches the
  /// category cards, the recommendation rail and the leaderboard rows without
  /// any of them knowing that offers exist.
  double? _payablePrice(ServiceOffering offering) =>
      offerFor(offering.id)?.discountedPrice ?? offering.price;

  @override
  ServiceOffering? cheapestOfferingFor(String categoryId, {String? region}) {
    ServiceOffering? best;
    double? bestPrice;
    for (final offering in offeringsFor(categoryId, region: region)) {
      final price = _payablePrice(offering);
      if (price == null) {
        // Quote-only loses to any priced offering and wins only when there is
        // nothing priced at all.
        best ??= offering;
        continue;
      }
      if (bestPrice == null || price < bestPrice) {
        best = offering;
        bestPrice = price;
      }
    }
    // Returned at the price the customer would actually pay — a card that says
    // "from 4.5" must open the workshop charging 4.5, not the one charging 6.
    return best == null ? null : pricedOffering(best.id);
  }

  @override
  List<Promotion> promotions({String? region, Powertrain? powertrain}) {
    final now = DateTime.now();
    return [
      for (final promotion in _promotions.value)
        if (promotion.isLive(now) &&
            promotion.runsIn(region) &&
            _promotionResolves(promotion) &&
            _promotionSuits(promotion, powertrain))
          promotion,
    ];
  }

  /// True when the work a campaign sells is work this car can use.
  ///
  /// A campaign with no specific offering (a platform announcement) always
  /// passes: it is not selling a service to a particular car.
  bool _promotionSuits(Promotion promotion, Powertrain? powertrain) {
    final offeringId = promotion.offeringId;
    if (offeringId == null) return true;
    final offering = offeringById(offeringId);
    if (offering == null) return false;
    final category =
        categories.where((c) => c.id == offering.categoryId).firstOrNull;
    // The same rule the recommendation rail and the leaderboard use.
    return category == null || categoryServes(category, powertrain);
  }

  /// True when everything the card claims to point at is in this catalogue.
  ///
  /// An offer whose workshop left the marketplace, or whose offering was
  /// withdrawn, becomes a card that opens an error — so it is not rendered at
  /// all. A card with neither target (a plain announcement carrying only a
  /// [Promotion.query]) is fine: the services tab can always run a search.
  bool _promotionResolves(Promotion promotion) {
    final offeringId = promotion.offeringId;
    if (offeringId != null && offeringById(offeringId) == null) return false;
    final providerId = promotion.providerId;
    if (providerId != null &&
        !providers.any((p) => p.id == providerId)) {
      return false;
    }
    return true;
  }

  // ------------------------------------------------------------------ offers

  /// The six validation rules of home-page spec §3, in one place.
  ///
  /// Returns null when the offer may be shown, and the specific reason
  /// otherwise. Every screen that renders an offer goes through here — there is
  /// no path that renders one without being checked, which is the point: an
  /// offer is a claim about money, and the platform is making it on the
  /// workshop's behalf.
  OfferRejection? _reject(Offer offer, {DateTime? now}) {
    final workshop =
        providers.where((p) => p.id == offer.workshopId).firstOrNull;
    if (workshop == null) return OfferRejection.unknownWorkshop;
    // Rule 2 — approved workshops only.
    if (!workshop.isApproved) return OfferRejection.workshopNotApproved;

    // Rule 3 — a service that is actually listed, and listed by *this*
    // workshop.
    final offering = offeringById(offer.serviceOfferingId);
    if (offering == null) return OfferRejection.unlistedService;
    if (offering.provider.id != workshop.id) {
      return OfferRejection.serviceNotThisWorkshops;
    }

    // Rule 1 — the reference price is the platform's published price, not the
    // seller's. A quote-only service has no published price to discount, so
    // there is nothing here that could be honoured.
    final published = offering.price;
    if (published == null) return OfferRejection.serviceHasNoPublishedPrice;
    if ((published - offer.referencePrice).abs() > 0.001) {
      return OfferRejection.referencePriceMismatch;
    }
    if (!offer.isRealDiscount) return OfferRejection.notADiscount;

    // Rule 4 — the founder's switch.
    if (!offer.activeByFounder) return OfferRejection.notApprovedByFounder;

    // Rule 5 — inside its own window.
    if (!offer.isWithin(now ?? DateTime.now())) {
      return OfferRejection.outsideItsDates;
    }
    return null;
  }

  @override
  Offer? offerFor(String offeringId) {
    Offer? best;
    for (final offer in _offers.value) {
      if (offer.serviceOfferingId != offeringId) continue;
      if (_reject(offer) != null) continue;
      // Two valid offers on one service should not happen, but if the API ever
      // sends them the customer gets the better price rather than whichever
      // arrived first.
      if (best == null || offer.discountedPrice < best.discountedPrice) {
        best = offer;
      }
    }
    return best;
  }

  @override
  List<LiveOffer> liveOffers({String? region, Powertrain? powertrain}) {
    final live = <LiveOffer>[];
    for (final offer in _offers.value) {
      if (_reject(offer) != null) continue;
      final offering = offeringById(offer.serviceOfferingId)!;
      if (!offer.runsIn(region, workshopRegion: offering.provider.region)) {
        continue;
      }
      // The same powertrain rule the rest of the home page uses: work this car
      // cannot have done is not an offer to this customer.
      final category =
          categories.where((c) => c.id == offering.categoryId).firstOrNull;
      if (category != null && !categoryServes(category, powertrain)) continue;
      live.add((offer: offer, offering: offering));
    }
    // Biggest real saving first. The only ordering the front page has, and it
    // is computed from the prices themselves — there is nothing a workshop
    // could pay to move up it (spec §2).
    live.sort((a, b) => b.offer.discountPercent.compareTo(a.offer.discountPercent));
    return live.take(HomeRankingConfig.maxCardsPerSection).toList(growable: false);
  }

  @override
  List<({Offer offer, OfferRejection? rejection})> auditOffers() => [
        for (final offer in _offers.value) (offer: offer, rejection: _reject(offer)),
      ];

  @override
  Future<Offer> setOfferActive(String offerId, {required bool active}) async {
    final updated = await _service.setOfferActive(offerId, active: active);
    _offers.put([
      for (final offer in _offers.value)
        if (offer.id == updated.id) updated else offer,
    ]);
    return updated;
  }

  @override
  List<CategoryDemand> get categoryDemand => _demand.value;

  @override
  List<WorkshopDemand> get workshopDemand => _workshopDemand.value;

  @override
  List<RankedCategory> mostBookedCategories({
    Powertrain? powertrain,
    int limit = 5,
  }) {
    final bookable = {
      for (final c in categoriesFor(powertrain))
        // Popular or not, work this car cannot use is dropped: an oil change is
        // the single most booked job in the country and still has no business on
        // an electric car's home page. The marketplace will sell it to them if
        // they search for it — this list is the app volunteering.
        if (categoryServes(c, powertrain)) c.id: c,
    };
    final ranked = <RankedCategory>[
      for (final demand in categoryDemand)
        if (demand.bookings > 0 && bookable[demand.categoryId] != null)
          (category: bookable[demand.categoryId]!, demand: demand),
    ]..sort((a, b) => b.demand.bookings.compareTo(a.demand.bookings));
    return ranked.take(limit).toList(growable: false);
  }

  @override
  WorkshopRating? ratingFor(String providerId) {
    for (final rating in _ratings.value) {
      if (rating.providerId == providerId) return rating;
    }
    return null;
  }

  @override
  List<RankedWorkshop> topRatedWorkshops({
    String? region,
    int limit = 5,
    int minReviews = HomeRankingConfig.minReviewsForRanking,
  }) {
    final ranked = <RankedWorkshop>[];
    for (final provider in providers) {
      if (region != null && provider.region != region) continue;
      // Spec §3: the platform only promotes workshops it has approved.
      if (!provider.isApproved) continue;
      final rating = ratingFor(provider.id);
      // No rating and too few reviews are the same answer here: there is not
      // enough evidence to put this workshop on a leaderboard.
      if (rating == null || rating.reviews < minReviews) continue;
      ranked.add((provider: provider, rating: rating));
    }
    ranked.sort((a, b) {
      final byRating = b.rating.rating.compareTo(a.rating.rating);
      if (byRating != 0) return byRating;
      final byReviews = b.rating.reviews.compareTo(a.rating.reviews);
      if (byReviews != 0) return byReviews;
      return a.provider.distanceKm.compareTo(b.provider.distanceKm);
    });
    return ranked.take(limit).toList(growable: false);
  }

  @override
  List<RequestedWorkshop> mostRequestedWorkshops({
    String? region,
    int limit = 5,
  }) {
    final ranked = <RequestedWorkshop>[];
    for (final demand in workshopDemand) {
      // Nothing completed is not a rank of last place — it is no evidence at
      // all, and a "most requested" board is a claim about evidence.
      if (demand.completedBookings <= 0) continue;
      final provider =
          providers.where((p) => p.id == demand.providerId).firstOrNull;
      if (provider == null || !provider.isApproved) continue;
      if (region != null && provider.region != region) continue;
      ranked.add((provider: provider, demand: demand));
    }
    ranked.sort((a, b) {
      final byBookings =
          b.demand.completedBookings.compareTo(a.demand.completedBookings);
      if (byBookings != 0) return byBookings;
      return a.provider.distanceKm.compareTo(b.provider.distanceKm);
    });
    return ranked.take(limit).toList(growable: false);
  }

  @override
  List<ServiceProvider> approvedWorkshops({String? region, int limit = 5}) {
    final matches = [
      for (final provider in providers)
        if (provider.isApproved && (region == null || provider.region == region))
          provider,
    ]..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return matches.take(limit).toList(growable: false);
  }

  @override
  List<AddOn> addOnsFor(String providerId) => _addOns[providerId] ?? const [];

  @override
  BookingAvailability availabilityFor(String providerId) =>
      _availability[providerId] ??
      const BookingAvailability(slots: [], bookedSlots: {});

  @override
  Future<ServiceRequest> createRequest(CreateServiceRequestDraft draft) =>
      _service.createRequest(draft);

  @override
  Future<ServiceRequest> createPartRequest(
    CreatePartRequestDraft draft, {
    required Car car,
  }) {
    final provider =
        providers.where((p) => p.id == draft.providerId).firstOrNull;
    if (provider == null) {
      throw NotFoundException('Provider ${draft.providerId} not found');
    }
    return _service.createPartRequest(draft, provider: provider, car: car);
  }

  @override
  Future<ServiceRequest> submitQuote(String requestId, Quote quote) =>
      _service.submitQuote(requestId, quote);

  @override
  Future<List<ServiceRequest>> fetchRequests() => _service.fetchRequests();

  @override
  Future<ServiceRequest> applyEscrowEvent(
    String requestId,
    EscrowEvent event, {
    required EscrowActor actor,
    ProofOfWork? proof,
    String? disputeNote,
    String? slot,
  }) =>
      _service.applyEscrowEvent(
        requestId,
        event,
        actor: actor,
        proof: proof,
        disputeNote: disputeNote,
        slot: slot,
      );
}
