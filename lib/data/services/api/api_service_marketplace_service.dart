import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../models/add_on.dart';
import '../../models/audit_entry.dart';
import '../../models/car.dart';
import '../../models/escrow.dart';
import '../../models/offer.dart';
import '../../models/payout_record.dart';
import '../../models/promotion.dart';
import '../../models/proof_of_work.dart';
import '../../models/quote.dart';
import '../../models/service_category.dart';
import '../../models/service_offering.dart';
import '../../models/service_provider.dart';
import '../../models/service_request.dart';
import '../../models/service_stats.dart';
import '../../models/workshop_application.dart';
import '../service_marketplace_service.dart';

/// Service discovery, booking, onboarding and the operator ledgers over REST
/// (§12).
///
/// The routes phase 2.5 added — onboarding, payouts, the audit trail — are
/// nested under the resources they belong to rather than given a new top-level
/// namespace: a workshop's stage is a property of that workshop, and a payout
/// is a record about one. `docs/api_contract.md` is the authority on all of
/// them.
class ApiServiceMarketplaceService implements ServiceMarketplaceService {
  const ApiServiceMarketplaceService(this._client);

  final ApiClient _client;

  static const _base = '/service-marketplace';

  // ------------------------------------------------------------- catalogue

  @override
  Future<List<ServiceCategory>> fetchCategories() async =>
      (await _client.getList(ApiEndpoints.serviceCategories))
          .map(ServiceCategory.fromJson)
          .toList();

  @override
  Future<List<ServiceProvider>> fetchProviders() async =>
      (await _client.getList(ApiEndpoints.serviceProviders))
          .map(ServiceProvider.fromJson)
          .toList();

  @override
  Future<List<ServiceOffering>> fetchOfferings({String? categoryId}) async =>
      (await _client.getList(
        ApiEndpoints.serviceOfferings,
        queryParameters: {'categoryId': ?categoryId},
      ))
          .map(ServiceOffering.fromJson)
          .toList();

  @override
  Future<ServiceOffering> fetchOffering(String offeringId) async =>
      ServiceOffering.fromJson(
        await _client.get('${ApiEndpoints.serviceOfferings}/$offeringId'),
      );

  @override
  Future<List<Promotion>> fetchPromotions() async =>
      (await _client.getList(ApiEndpoints.servicePromotions))
          .map(Promotion.fromJson)
          .toList();

  @override
  Future<List<Offer>> fetchOffers() async =>
      (await _client.getList(ApiEndpoints.serviceOffers))
          .map(Offer.fromJson)
          .toList();

  @override
  Future<Offer> setOfferActive(String offerId, {required bool active}) async =>
      Offer.fromJson(
        await _client.patch(
          '${ApiEndpoints.serviceOffers}/$offerId',
          body: {'activeByFounder': active},
        ),
      );

  @override
  Future<List<CategoryDemand>> fetchCategoryDemand() async =>
      (await _client.getList(ApiEndpoints.serviceCategoryDemand))
          .map(CategoryDemand.fromJson)
          .toList();

  @override
  Future<List<WorkshopDemand>> fetchWorkshopDemand() async =>
      (await _client.getList(ApiEndpoints.serviceWorkshopDemand))
          .map(WorkshopDemand.fromJson)
          .toList();

  @override
  Future<List<WorkshopRating>> fetchWorkshopRatings() async =>
      (await _client.getList(ApiEndpoints.serviceWorkshopRatings))
          .map(WorkshopRating.fromJson)
          .toList();

  @override
  Future<List<AddOn>> fetchAddOns(String providerId) async =>
      (await _client.getList(ApiEndpoints.providerAddOns(providerId)))
          .map(AddOn.fromJson)
          .toList();

  @override
  Future<BookingAvailability> fetchAvailability(
    String providerId, {
    DateTime? date,
  }) async {
    final json = await _client.get(
      ApiEndpoints.providerSlots(providerId),
      queryParameters: {
        if (date != null) 'date': date.toIso8601String().split('T').first,
      },
    );
    return BookingAvailability(
      slots: [for (final slot in json['slots'] as List? ?? []) slot.toString()],
      bookedSlots: {
        for (final slot in json['bookedSlots'] as List? ?? []) slot.toString(),
      },
    );
  }

  // ----------------------------------------------------------- transactions

  @override
  Future<ServiceRequest> createRequest(CreateServiceRequestDraft draft) async =>
      ServiceRequest.fromJson(
        await _client.post(ApiEndpoints.serviceRequests, body: draft.toJson()),
      );

  @override
  Future<ServiceRequest> createPartRequest(
    CreatePartRequestDraft draft, {
    required ServiceProvider provider,
    required Car car,
  }) async =>
      // `provider` and `car` are already resolved by the caller and are not
      // re-sent: the server owns both records, and posting its own copies back
      // would let a client rename a workshop by booking it.
      ServiceRequest.fromJson(
        await _client.post(ApiEndpoints.partRequests, body: draft.toJson()),
      );

  @override
  Future<ServiceRequest> submitQuote(String requestId, Quote quote) async =>
      ServiceRequest.fromJson(
        await _client.post(
          ApiEndpoints.requestQuote(requestId),
          body: quote.toJson(),
        ),
      );

  @override
  Future<List<ServiceRequest>> fetchRequests() async =>
      (await _client.getList(ApiEndpoints.serviceRequests))
          .map(ServiceRequest.fromJson)
          .toList();

  @override
  Future<List<ServiceRequest>> fetchOperatorQueue() async =>
      // A different endpoint, not a wider filter — only an operator may ask
      // for it, and the server authorises it on that basis.
      (await _client.getList('$_base/operator/requests'))
          .map(ServiceRequest.fromJson)
          .toList();

  @override
  Future<ServiceRequest> applyEscrowEvent(
    String requestId,
    EscrowEvent event, {
    required EscrowActor actor,
    ProofOfWork? proof,
    String? disputeNote,
    String? slot,
  }) async =>
      // The transition table is enforced server-side as well; an illegal
      // combination comes back as a 422 and surfaces as the same
      // `BusinessRuleException` the mock throws, with the same code.
      ServiceRequest.fromJson(
        await _client.post(
          ApiEndpoints.serviceRequestStatus(requestId),
          body: {
            'event': event.key,
            'actor': actor.key,
            'proof': ?proof?.toJson(),
            'disputeNote': ?disputeNote,
            'slot': ?slot,
          },
        ),
      );

  // ------------------------------------------------------------- onboarding

  @override
  Future<ServiceProvider> setProviderStage(
    String providerId,
    ProviderOnboardingStage stage, {
    String? reason,
  }) async =>
      // The mandatory-reason rule is the server's here, exactly as it is the
      // mock's: a 422 with `provider_rejection_reason_required` is what a
      // reasonless rejection gets, so both paths fail the same way.
      ServiceProvider.fromJson(
        await _client.patch(
          '${ApiEndpoints.serviceProviders}/$providerId/stage',
          body: {'stage': stage.key, 'reason': ?reason},
        ),
      );

  @override
  Future<ServiceProvider> submitWorkshopApplication({
    required String ownerUserId,
    required WorkshopApplication application,
    required String region,
  }) async =>
      ServiceProvider.fromJson(
        await _client.post(
          '$_base/applications',
          body: {
            'ownerUserId': ownerUserId,
            'region': region,
            ...application.toJson(),
          },
        ),
      );

  // ------------------------------------------------------ ledgers and audit

  @override
  Future<List<PayoutRecord>> fetchPayouts() async =>
      (await _client.getList('$_base/payouts'))
          .map(PayoutRecord.fromJson)
          .toList();

  @override
  Future<PayoutRecord> recordPayout(PayoutRecord payout) async =>
      PayoutRecord.fromJson(
        await _client.post('$_base/payouts', body: payout.toJson()),
      );

  @override
  Future<List<AuditEntry>> fetchAuditLog() async =>
      (await _client.getList('$_base/audit'))
          .map(AuditEntry.fromJson)
          .toList();

  @override
  Future<AuditEntry> appendAudit(AuditEntry entry) async => AuditEntry.fromJson(
        await _client.post('$_base/audit', body: entry.toJson()),
      );
}
