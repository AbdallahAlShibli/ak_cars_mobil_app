import '../../core/i18n/strings.dart';
import '../models/models.dart';

/// Transport-agnostic contract for the founder's CRUD over *any* workshop's
/// profile and catalogue — `/service-marketplace/admin/providers/{id}/...`.
///
/// Deliberately separate from [WorkshopService] (the owner's own dashboard):
/// the shapes look similar, but every call here carries an explicit
/// `providerId` because the founder is acting on someone else's workshop, and
/// this only covers the narrower founder-CRUD scope (profile, offerings,
/// add-ons) rather than the owner dashboard's full surface (inventory, staff,
/// schedule, requests, customers, earnings).
abstract interface class AdminWorkshopService {
  // ------------------------------------------------------------- profile
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

  /// Soft-deletes the workshop — see `ServiceProvider.IsDeleted` on the API
  /// side. Historical bookings/payouts keep resolving it; discovery and
  /// operation stop.
  Future<void> deleteProvider(String providerId);

  // ---------------------------------------------------------- offerings
  Future<List<ServiceOffering>> getProviderOfferings(String providerId);

  Future<ServiceOffering> createProviderOffering(
    String providerId, {
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
  });

  Future<ServiceOffering> updateProviderOffering(
    String providerId,
    String offeringId, {
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
  });

  Future<ServiceOffering> setProviderOfferingActive(
    String providerId,
    String offeringId, {
    required bool isActive,
  });

  Future<void> deleteProviderOffering(String providerId, String offeringId);

  // ----------------------------------------------------------- add-ons
  Future<List<AddOn>> getProviderAddOns(String providerId);

  Future<AddOn> createProviderAddOn(
    String providerId, {
    required L name,
    required double price,
    required bool isPart,
  });

  Future<AddOn> updateProviderAddOn(
    String providerId,
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  });

  Future<void> deleteProviderAddOn(String providerId, String addOnId);
}
