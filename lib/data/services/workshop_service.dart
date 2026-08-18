import '../../core/i18n/strings.dart';
import '../models/models.dart';

/// Transport-agnostic contract for a workshop owner's own dashboard —
/// everything under `/service-marketplace/my-workshop` in
/// `docs/api_contract.md`.
///
/// Kept separate from [ServiceMarketplaceService] rather than folded into it:
/// that interface already sits at ~24 members, and this feature adds close to
/// 30 more (profile, summary, offerings/add-ons CRUD, inventory CRUD +
/// movements, staff CRUD + assign, filtered requests, customers, schedule,
/// earnings/metrics). A single `ApiXService` implementation of both would be
/// two unrelated feature surfaces sharing one file for no reason other than
/// history.
abstract interface class WorkshopService {
  // ------------------------------------------------------------- profile
  Future<ServiceProvider> getMyWorkshop();

  Future<ServiceProvider> updateMyWorkshop({
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

  Future<WorkshopSummary> getMyWorkshopSummary();

  // ---------------------------------------------------------- offerings
  Future<List<ServiceOffering>> getMyOfferings();

  Future<ServiceOffering> createOffering({
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
  });

  Future<ServiceOffering> updateOffering(
    String offeringId, {
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
  });

  Future<ServiceOffering> setOfferingActive(
    String offeringId, {
    required bool isActive,
  });

  Future<void> deleteOffering(String offeringId);

  // ----------------------------------------------------------- add-ons
  Future<List<AddOn>> getMyAddOns();

  Future<AddOn> createAddOn({
    required L name,
    required double price,
    required bool isPart,
  });

  Future<AddOn> updateAddOn(
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  });

  Future<void> deleteAddOn(String addOnId);

  // ---------------------------------------------------------- inventory
  Future<List<InventoryItem>> getInventory();

  Future<List<InventoryItem>> getLowStockInventory();

  Future<InventoryItem> createInventoryItem({
    required L name,
    required String sku,
    String? partNumber,
    String? brand,
    String? categoryId,
    required double unitCost,
    required double sellPrice,
    required int reorderLevel,
    required InventoryUnit unit,
    String? location,
  });

  Future<InventoryItem> updateInventoryItem(
    String itemId, {
    required L name,
    required String sku,
    String? partNumber,
    String? brand,
    String? categoryId,
    required double unitCost,
    required double sellPrice,
    required int reorderLevel,
    required InventoryUnit unit,
    String? location,
    required bool isActive,
  });

  Future<void> deleteInventoryItem(String itemId);

  Future<InventoryItem> recordInventoryMovement(
    String itemId, {
    required int delta,
    required InventoryMovementReason reason,
    String? requestId,
    String? note,
  });

  // ------------------------------------------------------------- staff
  Future<List<WorkshopStaff>> getStaff();

  Future<WorkshopStaff> createStaff({
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
    String? userId,
  });

  Future<WorkshopStaff> updateStaff(
    String staffId, {
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
  });

  Future<void> deactivateStaff(String staffId);

  Future<ServiceRequest> assignRequest(
    String requestId, {
    required String staffId,
  });

  // ---------------------------------------------------------- requests
  Future<List<ServiceRequest>> getMyWorkshopRequests({
    EscrowState? status,
    DateTime? from,
    DateTime? to,
    String? query,
  });

  // --------------------------------------------------------- customers
  Future<List<WorkshopCustomer>> getWorkshopCustomers({
    String? query,
    WorkshopCustomerTag? tag,
  });

  Future<WorkshopCustomerDetail> getWorkshopCustomer(String userId);

  Future<WorkshopCustomerNote> addCustomerNote(
    String userId, {
    required String body,
  });

  // ---------------------------------------------------------- schedule
  Future<WorkshopDaySchedule> getSchedule(DateTime date);

  Future<WorkshopSchedule> updateSchedule({
    L? hours,
    List<String> slotTemplate = const [],
    required int capacityPerSlot,
    List<String> closedDays = const [],
  });

  // ------------------------------------------------------ earnings/metrics
  Future<WorkshopEarnings> getWorkshopEarnings({int windowDays = 30});

  Future<WorkshopMetrics> getWorkshopMetrics({int windowDays = 30});
}
