import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/data/services/workshop_service.dart';

import 'data/mock_service_data.dart';
import 'fake_service_base.dart';

/// In-memory double for a workshop owner's own dashboard.
///
/// Unlike [MockServiceMarketplaceService] this needs no per-user ownership
/// resolution: the real `/my-workshop/*` API resolves the caller's workshop
/// from the JWT, so from the client's point of view "my workshop" is simply
/// whichever one this double is seeded with — the test session is always
/// that workshop's owner, exactly as an authenticated request against the
/// real API always is.
class MockWorkshopService with MockServiceBase implements WorkshopService {
  MockWorkshopService({ServiceProvider? provider})
    : _provider = provider ?? MockServiceData.providers.first;

  ServiceProvider _provider;
  final List<ServiceOffering> _offerings = [];
  final List<AddOn> _addOns = [];
  final List<InventoryItem> _inventory = [];
  final List<InventoryMovement> _movements = [];
  final List<WorkshopStaff> _staff = [];
  final List<ServiceRequest> _requests = [];
  final Map<String, List<WorkshopCustomerNote>> _notes = {};
  WorkshopSchedule _schedule = const WorkshopSchedule();

  int _nextId = 1;
  String _newId() => 'mock-workshop-${_nextId++}';

  /// How many times *anything* on this fake has been called — every method
  /// resolves through [respond]/[respondRequired], so overriding it here
  /// counts them all without instrumenting each one individually. Lets a
  /// test prove a plain customer, who never opens the workshop dashboard,
  /// never causes a single `/my-workshop/*` request — not even indirectly,
  /// as a side effect of something invalidating an `AsyncNotifierProvider`
  /// that was never built.
  int callCount = 0;

  @override
  Future<T> respond<T>(T value) {
    callCount++;
    return super.respond(value);
  }

  // ------------------------------------------------------------- profile

  /// Swaps which workshop [getMyWorkshop] answers with — stands in for a
  /// second account signing in on the same device, since the real
  /// `/my-workshop/*` API would resolve a different owner's JWT to a
  /// different workshop without the client asking for anything different.
  set provider(ServiceProvider value) => _provider = value;

  @override
  Future<MyWorkshopProfile> getMyWorkshop() =>
      respond(MyWorkshopProfile.of(_provider, schedule: _schedule));

  @override
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
  }) {
    _provider = _provider.copyWith(
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
    return respond(_provider);
  }

  @override
  Future<WorkshopSummary> getMyWorkshopSummary() => respond(
    WorkshopSummary(
      provider: _provider,
      jobs: const WorkshopSummaryJobs(
        needsYou: 0,
        inProgress: 0,
        awaitingApproval: 0,
        overdue: 0,
        todays: 0,
      ),
      money: const WorkshopSummaryMoney(
        heldInEscrow: 0,
        releasedGross: 0,
        totalCommission: 0,
        payoutDue: 0,
      ),
      stock: WorkshopSummaryStock(
        items: _inventory.length,
        lowStock: _inventory.where((i) => i.isLowStock).length,
        outOfStock: _inventory.where((i) => i.isOutOfStock).length,
        stockValue: _inventory.fold(0, (sum, i) => sum + i.stockValue),
      ),
      people: WorkshopSummaryPeople(
        activeStaff: _staff.where((s) => s.isActive).length,
        customers: 0,
        repeatRate: 0,
      ),
      rating: const WorkshopSummaryRating(reviewCount: 0),
      alerts: const [],
    ),
  );

  // ---------------------------------------------------------- offerings

  @override
  Future<List<ServiceOffering>> getMyOfferings() => respond([..._offerings]);

  @override
  Future<ServiceOffering> createOffering({
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
    MediaAttachment? photo,
  }) {
    final offering = ServiceOffering(
      id: _newId(),
      categoryId: categoryId,
      categorySlug: MockServiceData.categories
          .firstWhere(
            (c) => c.id == categoryId,
            orElse: () => MockServiceData.categories.first,
          )
          .slug,
      name: name,
      provider: _provider,
      description: description,
      price: price,
      durationMin: durationMin,
      includes: includes,
      warrantyMonths: warrantyMonths,
      photo: photo,
    );
    _offerings.add(offering);
    return respond(offering);
  }

  @override
  Future<ServiceOffering> updateOffering(
    String offeringId, {
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
    MediaAttachment? photo,
  }) {
    final index = _offerings.indexWhere((o) => o.id == offeringId);
    final updated = _offerings[index].copyWith(
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      durationMin: durationMin,
      includes: includes,
      warrantyMonths: warrantyMonths,
      photo: photo,
      clearPhoto: photo == null,
    );
    _offerings[index] = updated;
    return respond(updated);
  }

  @override
  Future<ServiceOffering> setOfferingActive(
    String offeringId, {
    required bool isActive,
  }) {
    final index = _offerings.indexWhere((o) => o.id == offeringId);
    final updated = _offerings[index].copyWith(isActive: isActive);
    _offerings[index] = updated;
    return respond(updated);
  }

  @override
  Future<void> deleteOffering(String offeringId) {
    final index = _offerings.indexWhere((o) => o.id == offeringId);
    _offerings[index] = _offerings[index].copyWith(isActive: false);
    return respond(null);
  }

  // ----------------------------------------------------------- add-ons

  @override
  Future<List<AddOn>> getMyAddOns() => respond([..._addOns]);

  @override
  Future<AddOn> createAddOn({
    required L name,
    required double price,
    required bool isPart,
  }) {
    final addOn = AddOn(id: _newId(), name: name, price: price, isPart: isPart);
    _addOns.add(addOn);
    return respond(addOn);
  }

  @override
  Future<AddOn> updateAddOn(
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  }) {
    final index = _addOns.indexWhere((a) => a.id == addOnId);
    final updated = _addOns[index].copyWith(
      name: name,
      price: price,
      isPart: isPart,
    );
    _addOns[index] = updated;
    return respond(updated);
  }

  @override
  Future<void> deleteAddOn(String addOnId) {
    _addOns.removeWhere((a) => a.id == addOnId);
    return respond(null);
  }

  // ---------------------------------------------------------- inventory

  @override
  Future<List<InventoryItem>> getInventory() => respond([..._inventory]);

  @override
  Future<List<InventoryItem>> getLowStockInventory() => respond([
    for (final i in _inventory)
      if (i.isActive && i.isLowStock) i,
  ]);

  @override
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
  }) {
    final now = DateTime.now();
    final item = InventoryItem(
      id: _newId(),
      name: name,
      sku: sku,
      partNumber: partNumber,
      brand: brand,
      categoryId: categoryId,
      unitCost: unitCost,
      sellPrice: sellPrice,
      quantityOnHand: 0,
      reorderLevel: reorderLevel,
      unit: unit,
      location: location,
      createdAt: now,
      updatedAt: now,
    );
    _inventory.add(item);
    return respond(item);
  }

  @override
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
  }) {
    final index = _inventory.indexWhere((i) => i.id == itemId);
    final updated = _inventory[index].copyWith(
      name: name,
      sku: sku,
      partNumber: partNumber,
      brand: brand,
      categoryId: categoryId,
      unitCost: unitCost,
      sellPrice: sellPrice,
      reorderLevel: reorderLevel,
      unit: unit,
      location: location,
      isActive: isActive,
      updatedAt: DateTime.now(),
    );
    _inventory[index] = updated;
    return respond(updated);
  }

  @override
  Future<void> deleteInventoryItem(String itemId) {
    final index = _inventory.indexWhere((i) => i.id == itemId);
    _inventory[index] = _inventory[index].copyWith(isActive: false);
    return respond(null);
  }

  @override
  Future<InventoryItem> recordInventoryMovement(
    String itemId, {
    required int delta,
    required InventoryMovementReason reason,
    String? requestId,
    String? note,
  }) {
    final index = _inventory.indexWhere((i) => i.id == itemId);
    final item = _inventory[index];
    final newQuantity = item.quantityOnHand + delta;
    if (newQuantity < 0) {
      throw Exception('inventory_insufficient_stock');
    }
    _movements.add(
      InventoryMovement(
        id: _newId(),
        itemId: itemId,
        delta: delta,
        reason: reason,
        requestId: requestId,
        note: note,
        at: DateTime.now(),
        byUserId: 'test-user',
      ),
    );
    final updated = item.copyWith(
      quantityOnHand: newQuantity,
      updatedAt: DateTime.now(),
    );
    _inventory[index] = updated;
    return respond(updated);
  }

  // ------------------------------------------------------------- staff

  @override
  Future<List<WorkshopStaff>> getStaff() => respond([..._staff]);

  @override
  Future<WorkshopStaff> createStaff({
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
    String? userId,
  }) {
    final member = WorkshopStaff(
      id: _newId(),
      name: name,
      phone: phone,
      role: role,
      specialties: specialties,
      joinedAt: DateTime.now(),
      userId: userId,
    );
    _staff.add(member);
    return respond(member);
  }

  @override
  Future<WorkshopStaff> updateStaff(
    String staffId, {
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
  }) {
    final index = _staff.indexWhere((m) => m.id == staffId);
    final updated = _staff[index].copyWith(
      name: name,
      phone: phone,
      role: role,
      specialties: specialties,
    );
    _staff[index] = updated;
    return respond(updated);
  }

  @override
  Future<void> deactivateStaff(String staffId) {
    final index = _staff.indexWhere((m) => m.id == staffId);
    _staff[index] = _staff[index].copyWith(isActive: false);
    return respond(null);
  }

  @override
  Future<ServiceRequest> assignRequest(
    String requestId, {
    required String staffId,
  }) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    final updated = _requests[index].copyWith(assignedStaffId: staffId);
    _requests[index] = updated;
    return respond(updated);
  }

  // ---------------------------------------------------------- requests

  @override
  Future<List<ServiceRequest>> getMyWorkshopRequests({
    EscrowState? status,
    DateTime? from,
    DateTime? to,
    String? query,
  }) => respond([
    for (final r in _requests)
      if (status == null || r.escrow == status) r,
  ]);

  // --------------------------------------------------------- customers

  @override
  Future<List<WorkshopCustomer>> getWorkshopCustomers({
    String? query,
    WorkshopCustomerTag? tag,
  }) => respond(const []);

  @override
  Future<WorkshopCustomerDetail> getWorkshopCustomer(String userId) => respond(
    WorkshopCustomerDetail(
      customer: WorkshopCustomer(
        userId: userId,
        name: 'Test customer',
        carCount: 0,
        bookingsCount: 0,
        lifetimeGross: 0,
        lastBookingAt: DateTime.now(),
      ),
      bookings: const [],
      notes: [...?_notes[userId]],
    ),
  );

  @override
  Future<WorkshopCustomerNote> addCustomerNote(
    String userId, {
    required String body,
  }) {
    final note = WorkshopCustomerNote(
      id: _newId(),
      body: body,
      at: DateTime.now(),
    );
    _notes.putIfAbsent(userId, () => []).insert(0, note);
    return respond(note);
  }

  // ---------------------------------------------------------- schedule

  @override
  Future<WorkshopDaySchedule> getSchedule(DateTime date) => respond(
    WorkshopDaySchedule(
      date: date,
      slots: _schedule.slotTemplate.isEmpty
          ? const ['09:00', '11:00', '13:00']
          : _schedule.slotTemplate,
      bookedSlots: const [],
      assignedJobs: [
        for (final r in _requests)
          if (r.assignedStaffId != null) r,
      ],
    ),
  );

  @override
  Future<WorkshopSchedule> updateSchedule({
    L? hours,
    List<String> slotTemplate = const [],
    required int capacityPerSlot,
    List<String> closedDays = const [],
  }) {
    _schedule = WorkshopSchedule(
      hours: hours,
      slotTemplate: slotTemplate,
      capacityPerSlot: capacityPerSlot,
      closedDays: closedDays,
    );
    return respond(_schedule);
  }

  // ------------------------------------------------------ earnings/metrics

  @override
  Future<WorkshopEarnings> getWorkshopEarnings({int windowDays = 30}) =>
      respond(WorkshopEarnings.empty);

  @override
  Future<WorkshopMetrics> getWorkshopMetrics({int windowDays = 30}) =>
      respond(WorkshopMetrics.empty);

  /// Test-only seam: lets a test seed a booking directly without going
  /// through the (customer-side) create-request flow this double doesn't
  /// implement.
  void seedRequest(ServiceRequest request) => _requests.add(request);
}
