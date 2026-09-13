import '../../core/i18n/strings.dart';
import '../models/models.dart';
import '../services/admin_workshop_service.dart';

/// The founder's CRUD over any workshop's profile and catalogue.
///
/// No warm cache, unlike [WorkshopRepository]/[ServiceMarketplaceRepository]:
/// this is an occasionally-opened founder screen for one workshop at a time,
/// not a hot path every screen reads from. Each method is a thin pass-through
/// to [AdminWorkshopService] plus the same "return the fresh record" shape
/// those repositories use, so the caller (an `AsyncNotifier` scoped to one
/// `providerId`) can hold its own short-lived state.
abstract interface class AdminWorkshopRepository {
  Future<ServiceProvider> getProvider(String providerId);

  Future<ServiceProvider> updateProvider(
    String providerId, {
    required L name,
    required String area,
    required String region,
    String? phone,
    String? whatsapp,
    L? hours,
    required Set<Fulfillment> fulfillments,
    required Set<ProviderCapability> capabilities,
    required double pickupFee,
    String? vatNumber,
    String? crNumber,
  });

  Future<void> deleteProvider(String providerId);

  /// Replaces the commercial-registration certificate on the applicant's
  /// behalf. See `AdminWorkshopService.updateCrDocument`.
  Future<ServiceProvider> updateCrDocument(
    String providerId,
    MediaAttachment document,
  );

  Future<List<ServiceOffering>> getOfferings(String providerId);

  Future<ServiceOffering> createOffering(
    String providerId, {
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
    MediaAttachment? photo,
  });

  Future<ServiceOffering> updateOffering(
    String providerId,
    String offeringId, {
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
    MediaAttachment? photo,
  });

  Future<ServiceOffering> setOfferingActive(
    String providerId,
    String offeringId, {
    required bool isActive,
  });

  Future<void> deleteOffering(String providerId, String offeringId);

  Future<List<AddOn>> getAddOns(String providerId);

  Future<AddOn> createAddOn(
    String providerId, {
    required L name,
    required double price,
    required bool isPart,
  });

  Future<AddOn> updateAddOn(
    String providerId,
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  });

  Future<void> deleteAddOn(String providerId, String addOnId);
}

class AdminWorkshopRepositoryImpl implements AdminWorkshopRepository {
  const AdminWorkshopRepositoryImpl(this._service);

  final AdminWorkshopService _service;

  @override
  Future<ServiceProvider> getProvider(String providerId) =>
      _service.getProvider(providerId);

  @override
  Future<ServiceProvider> updateProvider(
    String providerId, {
    required L name,
    required String area,
    required String region,
    String? phone,
    String? whatsapp,
    L? hours,
    required Set<Fulfillment> fulfillments,
    required Set<ProviderCapability> capabilities,
    required double pickupFee,
    String? vatNumber,
    String? crNumber,
  }) => _service.updateProvider(
    providerId,
    name: name,
    area: area,
    region: region,
    phone: phone,
    whatsapp: whatsapp,
    hours: hours,
    fulfillments: fulfillments,
    capabilities: capabilities,
    pickupFee: pickupFee,
    vatNumber: vatNumber,
    crNumber: crNumber,
  );

  @override
  Future<void> deleteProvider(String providerId) =>
      _service.deleteProvider(providerId);

  @override
  Future<ServiceProvider> updateCrDocument(
    String providerId,
    MediaAttachment document,
  ) => _service.updateCrDocument(providerId, document);

  @override
  Future<List<ServiceOffering>> getOfferings(String providerId) =>
      _service.getProviderOfferings(providerId);

  @override
  Future<ServiceOffering> createOffering(
    String providerId, {
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
    MediaAttachment? photo,
  }) => _service.createProviderOffering(
    providerId,
    categoryId: categoryId,
    name: name,
    description: description,
    price: price,
    durationMin: durationMin,
    includes: includes,
    warrantyMonths: warrantyMonths,
    photo: photo,
  );

  @override
  Future<ServiceOffering> updateOffering(
    String providerId,
    String offeringId, {
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
    MediaAttachment? photo,
  }) => _service.updateProviderOffering(
    providerId,
    offeringId,
    categoryId: categoryId,
    name: name,
    description: description,
    price: price,
    durationMin: durationMin,
    includes: includes,
    warrantyMonths: warrantyMonths,
    photo: photo,
  );

  @override
  Future<ServiceOffering> setOfferingActive(
    String providerId,
    String offeringId, {
    required bool isActive,
  }) => _service.setProviderOfferingActive(
    providerId,
    offeringId,
    isActive: isActive,
  );

  @override
  Future<void> deleteOffering(String providerId, String offeringId) =>
      _service.deleteProviderOffering(providerId, offeringId);

  @override
  Future<List<AddOn>> getAddOns(String providerId) =>
      _service.getProviderAddOns(providerId);

  @override
  Future<AddOn> createAddOn(
    String providerId, {
    required L name,
    required double price,
    required bool isPart,
  }) => _service.createProviderAddOn(
    providerId,
    name: name,
    price: price,
    isPart: isPart,
  );

  @override
  Future<AddOn> updateAddOn(
    String providerId,
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  }) => _service.updateProviderAddOn(
    providerId,
    addOnId,
    name: name,
    price: price,
    isPart: isPart,
  );

  @override
  Future<void> deleteAddOn(String providerId, String addOnId) =>
      _service.deleteProviderAddOn(providerId, addOnId);
}
