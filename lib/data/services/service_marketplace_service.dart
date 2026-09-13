import 'package:flutter/widgets.dart' show IconData;

import '../../core/i18n/strings.dart';
import '../models/add_on.dart';
import '../models/audit_entry.dart';
import '../models/car.dart';
import '../models/escrow.dart';
import '../models/offer.dart';
import '../models/payout_record.dart';
import '../models/proof_of_work.dart';
import '../models/promotion.dart';
import '../models/quote.dart';
import '../models/service_category.dart';
import '../models/service_offering.dart';
import '../models/service_provider.dart';
import '../models/service_request.dart';
import '../models/service_stats.dart';
import '../models/workshop_application.dart';

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

  /// Sets or clears the promo ribbon on one service category
  /// ("زيت مجاني" / "FREE OIL"). Null clears it.
  ///
  /// Kept as its own call beside [updateCategory] because it is the field a
  /// founder changes most often and the only one that carries no behaviour —
  /// worth a one-field write rather than PUTting a whole category back to move
  /// a ribbon.
  Future<ServiceCategory> updateCategoryBadge(String categoryId, {L? badge});

  /// Adds a service type to the catalogue.
  ///
  /// [slug] is the behavioural key, not wording: the maintenance mapper resets
  /// a schedule line from it and the booking screen treats `sos` as an
  /// emergency callout. The API validates its shape and uniqueness.
  Future<ServiceCategory> createCategory(ServiceCategoryDraft draft);

  /// Rewrites one service type. The API renames the denormalised
  /// `categorySlug` on every offering underneath it in the same transaction,
  /// so a rename cannot leave services answering to the old key.
  Future<ServiceCategory> updateCategory(
    String categoryId,
    ServiceCategoryDraft draft,
  );

  /// Removes a service type.
  ///
  /// The API refuses with `category_in_use` while any offering is still sold
  /// under it — deleting the row would orphan those offerings, and the
  /// customer's Services tab resolves that reference to draw its cards.
  Future<void> deleteCategory(String categoryId);

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

  /// The founder's management view — every offer regardless of approval
  /// state or window, so nothing created or since-expired can go missing
  /// from the create/edit/delete screen.
  Future<List<Offer>> fetchAllOffersForFounder();

  /// Publishes a new offer. Founder-only — see [setOfferActive]'s note on why
  /// there is no self-serve path for a workshop.
  Future<Offer> createOffer({
    required String workshopId,
    required String serviceOfferingId,
    required double referencePrice,
    required double discountedPrice,
    required DateTime startsAt,
    required DateTime endsAt,
    Set<String> regions = const {},
    bool activeByFounder = false,
  });

  /// Full edit of an existing offer's terms — price, dates, regions and the
  /// founder switch together, unlike [setOfferActive] which only ever moves
  /// the switch.
  Future<Offer> updateOffer(
    String offerId, {
    required double referencePrice,
    required double discountedPrice,
    required DateTime startsAt,
    required DateTime endsAt,
    Set<String> regions = const {},
    required bool activeByFounder,
  });

  Future<void> deleteOffer(String offerId);

  /// The founder's management view of every promotion, including ones past
  /// [Promotion.endsAt] — [fetchPromotions] filters those out for the
  /// customer-facing rail.
  Future<List<Promotion>> fetchAllPromotionsForFounder();

  /// Publishes a new promotion (a platform announcement, or a workshop's own
  /// campaign card). Unlike [createOffer], a promotion carries no price and
  /// no founder-approval gate — publishing it is what shows it.
  Future<Promotion> createPromotion({
    required L title,
    required L body,
    required IconData icon,
    L? badge,
    String? providerId,
    String? offeringId,
    String? query,
    Set<String> regions = const {},
    DateTime? endsAt,
  });

  Future<Promotion> updatePromotion(
    String promotionId, {
    required L title,
    required L body,
    required IconData icon,
    L? badge,
    String? providerId,
    String? offeringId,
    String? query,
    Set<String> regions = const {},
    DateTime? endsAt,
  });

  Future<void> deletePromotion(String promotionId);

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

  /// Every booking on the marketplace — the operator panels' queue.
  ///
  /// A **different endpoint** from [fetchRequests], not a wider filter on it,
  /// because they answer different questions and are authorised differently:
  /// one is "my bookings" and the other is "the platform's", and only an
  /// operator may ask the second. Merging them would put forty strangers'
  /// bookings in a customer's own list, which is the mistake seeding this data
  /// makes easy.
  Future<List<ServiceRequest>> fetchOperatorQueue();

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

  // ------------------------------------------------- onboarding (§5, §11)

  /// Moves one workshop along the onboarding path.
  ///
  /// [reason] is **required** for [ProviderOnboardingStage.suspended] and
  /// rejected otherwise — a rejection with no sentence after it is not
  /// something the workshop's owner can act on (§11 step 3), and the rule is
  /// enforced here rather than in the panel so no second caller can skip it.
  Future<ServiceProvider> setProviderStage(
    String providerId,
    ProviderOnboardingStage stage, {
    String? reason,
  });

  /// Files a workshop registration (§11 step 1).
  ///
  /// Creates the provider at [ProviderOnboardingStage.documentsSubmitted] —
  /// not `applied`, because the CR document is attached in the same step — and
  /// returns it. From this moment the account is suspended in practice: an
  /// unapproved workshop is invisible to customers, takes no bookings and
  /// cannot open its panel.
  Future<ServiceProvider> submitWorkshopApplication({
    required String ownerUserId,
    required WorkshopApplication application,
    required String region,
  });

  /// The founder's payout ledger.
  Future<List<PayoutRecord>> fetchPayouts();

  /// Records a transfer the founder made by hand. Nothing here moves money.
  Future<PayoutRecord> recordPayout(PayoutRecord payout);

  /// The platform-wide audit trail (§6).
  Future<List<AuditEntry>> fetchAuditLog();

  /// Appends one audit line. Called only from the repository's single write
  /// point — see `ServiceMarketplaceRepositoryImpl._audit`.
  Future<AuditEntry> appendAudit(AuditEntry entry);
}
