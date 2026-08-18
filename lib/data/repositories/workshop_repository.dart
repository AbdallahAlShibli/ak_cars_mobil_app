import '../../core/error/app_exception.dart';
import '../../core/i18n/strings.dart';
import '../models/models.dart';
import '../services/service_marketplace_service.dart';
import '../services/workshop_service.dart';
import 'warm_cache.dart';

/// A workshop owner's own dashboard — profile, catalogue, inventory, staff,
/// derived customers, schedule, earnings and metrics.
///
/// Same shape as `ServiceMarketplaceRepository`: an interface plus one impl,
/// `WarmCache` for the lists a screen reads synchronously and repeatedly
/// (offerings, add-ons, inventory, staff), direct pass-through for
/// filtered/paginated reads that take parameters (requests, customers,
/// schedule, earnings, metrics) where caching one answer would be wrong for
/// the next call with different filters.
///
/// Inventory, staff and customer-note writes also append to the platform
/// audit trail (`AuditSubjectType.inventory` / `.staff` / `.customer`),
/// mirroring `ServiceMarketplaceRepository._audit` exactly: private, called
/// once per mutation after it already succeeded, best-effort (a logging
/// failure must never fail the write it logs). Offering/add-on writes do
/// not — those subject types were not added to `AuditSubjectType`, since
/// reusing `.offer` would conflate a workshop's own catalogue with the
/// founder's separate `Offer` (promotional-discount) approvals, which is a
/// different entity entirely. This repository depends on
/// `ServiceMarketplaceService` for exactly one method, `appendAudit` — the
/// same seam `ServiceMarketplaceRepositoryImpl` itself writes through — so
/// the platform keeps one audit log, not two.
abstract interface class WorkshopRepository {
  // ------------------------------------------------------------- profile
  ServiceProvider? get cachedProfile;

  Future<ServiceProvider> loadMyWorkshop();

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

  Future<WorkshopSummary> fetchSummary();

  // ---------------------------------------------------------- offerings
  List<ServiceOffering> get offerings;

  Future<List<ServiceOffering>> loadOfferings();

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
  List<AddOn> get addOns;

  Future<List<AddOn>> loadAddOns();

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
  List<InventoryItem> get inventory;

  Future<List<InventoryItem>> loadInventory();

  Future<List<InventoryItem>> fetchLowStock();

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
  List<WorkshopStaff> get staff;

  Future<List<WorkshopStaff>> loadStaff();

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
  Future<List<ServiceRequest>> fetchWorkshopRequests({
    EscrowState? status,
    DateTime? from,
    DateTime? to,
    String? query,
  });

  // --------------------------------------------------------- customers
  Future<List<WorkshopCustomer>> fetchCustomers({
    String? query,
    WorkshopCustomerTag? tag,
  });

  Future<WorkshopCustomerDetail> fetchCustomer(String userId);

  Future<WorkshopCustomerNote> addCustomerNote(
    String userId, {
    required String body,
  });

  // ---------------------------------------------------------- schedule
  Future<WorkshopDaySchedule> fetchSchedule(DateTime date);

  Future<WorkshopSchedule> updateSchedule({
    L? hours,
    List<String> slotTemplate = const [],
    required int capacityPerSlot,
    List<String> closedDays = const [],
  });

  // ------------------------------------------------------ earnings/metrics
  Future<WorkshopEarnings> fetchEarnings({int windowDays = 30});

  Future<WorkshopMetrics> fetchMetrics({int windowDays = 30});
}

class WorkshopRepositoryImpl implements WorkshopRepository {
  WorkshopRepositoryImpl(this._service, this._auditService);

  final WorkshopService _service;

  /// Used for exactly one call, `appendAudit` — see this file's class doc
  /// comment for why this repository shares the platform's one audit log
  /// rather than growing a second one.
  final ServiceMarketplaceService _auditService;

  ServiceProvider? _profile;
  final _offerings = WarmCache<List<ServiceOffering>>(fallback: const []);
  final _addOns = WarmCache<List<AddOn>>(fallback: const []);
  final _inventory = WarmCache<List<InventoryItem>>(fallback: const []);
  final _staff = WarmCache<List<WorkshopStaff>>(fallback: const []);

  /// Same shape as `ServiceMarketplaceRepositoryImpl._audit`: private, called
  /// once per mutation after it already succeeded, best-effort.
  Future<void> _audit({
    required String action,
    required AuditSubjectType subjectType,
    required String subjectId,
    String? note,
  }) async {
    try {
      await _auditService.appendAudit(
        AuditEntry(
          // Replaced by the service, which owns the identity sequence.
          id: 'pending',
          at: DateTime.now(),
          actor: EscrowActor.workshop,
          actorId: _profile?.id ?? 'workshop',
          action: action,
          subjectType: subjectType,
          subjectId: subjectId,
          note: note,
        ),
      );
    } on AppException {
      // Swallowed on purpose — failing to log must never fail the write it
      // logs.
    }
  }

  // ------------------------------------------------------------- profile

  @override
  ServiceProvider? get cachedProfile => _profile;

  @override
  Future<ServiceProvider> loadMyWorkshop() async {
    _profile = await _service.getMyWorkshop();
    return _profile!;
  }

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
  }) async {
    _profile = await _service.updateMyWorkshop(
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
    return _profile!;
  }

  @override
  Future<WorkshopSummary> fetchSummary() => _service.getMyWorkshopSummary();

  // ---------------------------------------------------------- offerings

  @override
  List<ServiceOffering> get offerings => _offerings.value;

  @override
  Future<List<ServiceOffering>> loadOfferings() =>
      _offerings.load(_service.getMyOfferings);

  @override
  Future<ServiceOffering> createOffering({
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
  }) async {
    final created = await _service.createOffering(
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      durationMin: durationMin,
      includes: includes,
      warrantyMonths: warrantyMonths,
    );
    _offerings.put([..._offerings.value, created]);
    return created;
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
  }) async {
    final updated = await _service.updateOffering(
      offeringId,
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      durationMin: durationMin,
      includes: includes,
      warrantyMonths: warrantyMonths,
    );
    _replaceOffering(updated);
    return updated;
  }

  @override
  Future<ServiceOffering> setOfferingActive(
    String offeringId, {
    required bool isActive,
  }) async {
    final updated = await _service.setOfferingActive(
      offeringId,
      isActive: isActive,
    );
    _replaceOffering(updated);
    return updated;
  }

  void _replaceOffering(ServiceOffering updated) {
    _offerings.put([
      for (final o in _offerings.value)
        if (o.id == updated.id) updated else o,
    ]);
  }

  @override
  Future<void> deleteOffering(String offeringId) async {
    await _service.deleteOffering(offeringId);
    _offerings.put([
      for (final o in _offerings.value)
        if (o.id != offeringId) o,
    ]);
  }

  // ----------------------------------------------------------- add-ons

  @override
  List<AddOn> get addOns => _addOns.value;

  @override
  Future<List<AddOn>> loadAddOns() => _addOns.load(_service.getMyAddOns);

  @override
  Future<AddOn> createAddOn({
    required L name,
    required double price,
    required bool isPart,
  }) async {
    final created = await _service.createAddOn(
      name: name,
      price: price,
      isPart: isPart,
    );
    _addOns.put([..._addOns.value, created]);
    return created;
  }

  @override
  Future<AddOn> updateAddOn(
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  }) async {
    final updated = await _service.updateAddOn(
      addOnId,
      name: name,
      price: price,
      isPart: isPart,
    );
    _addOns.put([
      for (final a in _addOns.value)
        if (a.id == updated.id) updated else a,
    ]);
    return updated;
  }

  @override
  Future<void> deleteAddOn(String addOnId) async {
    await _service.deleteAddOn(addOnId);
    _addOns.put([
      for (final a in _addOns.value)
        if (a.id != addOnId) a,
    ]);
  }

  // ---------------------------------------------------------- inventory

  @override
  List<InventoryItem> get inventory => _inventory.value;

  @override
  Future<List<InventoryItem>> loadInventory() =>
      _inventory.load(_service.getInventory);

  @override
  Future<List<InventoryItem>> fetchLowStock() =>
      _service.getLowStockInventory();

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
  }) async {
    final created = await _service.createInventoryItem(
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
    );
    _inventory.put([..._inventory.value, created]);
    await _audit(
      action: 'inventory.created',
      subjectType: AuditSubjectType.inventory,
      subjectId: created.id,
    );
    return created;
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
  }) async {
    final updated = await _service.updateInventoryItem(
      itemId,
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
    );
    _replaceInventoryItem(updated);
    await _audit(
      action: 'inventory.updated',
      subjectType: AuditSubjectType.inventory,
      subjectId: updated.id,
    );
    return updated;
  }

  void _replaceInventoryItem(InventoryItem updated) {
    _inventory.put([
      for (final i in _inventory.value)
        if (i.id == updated.id) updated else i,
    ]);
  }

  @override
  Future<void> deleteInventoryItem(String itemId) async {
    await _service.deleteInventoryItem(itemId);
    _inventory.put([
      for (final i in _inventory.value)
        if (i.id != itemId) i,
    ]);
    await _audit(
      action: 'inventory.deleted',
      subjectType: AuditSubjectType.inventory,
      subjectId: itemId,
    );
  }

  @override
  Future<InventoryItem> recordInventoryMovement(
    String itemId, {
    required int delta,
    required InventoryMovementReason reason,
    String? requestId,
    String? note,
  }) async {
    final updated = await _service.recordInventoryMovement(
      itemId,
      delta: delta,
      reason: reason,
      requestId: requestId,
      note: note,
    );
    _replaceInventoryItem(updated);
    await _audit(
      action: 'inventory.movement.${reason.key}',
      subjectType: AuditSubjectType.inventory,
      subjectId: itemId,
      note: '$delta (${reason.key})${note == null ? '' : ' — $note'}',
    );
    return updated;
  }

  // ------------------------------------------------------------- staff

  @override
  List<WorkshopStaff> get staff => _staff.value;

  @override
  Future<List<WorkshopStaff>> loadStaff() => _staff.load(_service.getStaff);

  @override
  Future<WorkshopStaff> createStaff({
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
    String? userId,
  }) async {
    final created = await _service.createStaff(
      name: name,
      phone: phone,
      role: role,
      specialties: specialties,
      userId: userId,
    );
    _staff.put([..._staff.value, created]);
    await _audit(
      action: 'staff.created',
      subjectType: AuditSubjectType.staff,
      subjectId: created.id,
    );
    return created;
  }

  @override
  Future<WorkshopStaff> updateStaff(
    String staffId, {
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
  }) async {
    final updated = await _service.updateStaff(
      staffId,
      name: name,
      phone: phone,
      role: role,
      specialties: specialties,
    );
    _staff.put([
      for (final s in _staff.value)
        if (s.id == updated.id) updated else s,
    ]);
    await _audit(
      action: 'staff.updated',
      subjectType: AuditSubjectType.staff,
      subjectId: updated.id,
    );
    return updated;
  }

  @override
  Future<void> deactivateStaff(String staffId) async {
    await _service.deactivateStaff(staffId);
    _staff.put([
      for (final s in _staff.value)
        if (s.id == staffId) s.copyWith(isActive: false) else s,
    ]);
    await _audit(
      action: 'staff.deactivated',
      subjectType: AuditSubjectType.staff,
      subjectId: staffId,
    );
  }

  @override
  Future<ServiceRequest> assignRequest(
    String requestId, {
    required String staffId,
  }) => _service.assignRequest(requestId, staffId: staffId);

  // ---------------------------------------------------------- requests

  @override
  Future<List<ServiceRequest>> fetchWorkshopRequests({
    EscrowState? status,
    DateTime? from,
    DateTime? to,
    String? query,
  }) => _service.getMyWorkshopRequests(
    status: status,
    from: from,
    to: to,
    query: query,
  );

  // --------------------------------------------------------- customers

  @override
  Future<List<WorkshopCustomer>> fetchCustomers({
    String? query,
    WorkshopCustomerTag? tag,
  }) => _service.getWorkshopCustomers(query: query, tag: tag);

  @override
  Future<WorkshopCustomerDetail> fetchCustomer(String userId) =>
      _service.getWorkshopCustomer(userId);

  @override
  Future<WorkshopCustomerNote> addCustomerNote(
    String userId, {
    required String body,
  }) async {
    final note = await _service.addCustomerNote(userId, body: body);
    await _audit(
      action: 'customer.note_added',
      subjectType: AuditSubjectType.customer,
      subjectId: userId,
      note: body,
    );
    return note;
  }

  // ---------------------------------------------------------- schedule

  @override
  Future<WorkshopDaySchedule> fetchSchedule(DateTime date) =>
      _service.getSchedule(date);

  @override
  Future<WorkshopSchedule> updateSchedule({
    L? hours,
    List<String> slotTemplate = const [],
    required int capacityPerSlot,
    List<String> closedDays = const [],
  }) => _service.updateSchedule(
    hours: hours,
    slotTemplate: slotTemplate,
    capacityPerSlot: capacityPerSlot,
    closedDays: closedDays,
  );

  // ------------------------------------------------------ earnings/metrics

  @override
  Future<WorkshopEarnings> fetchEarnings({int windowDays = 30}) =>
      _service.getWorkshopEarnings(windowDays: windowDays);

  @override
  Future<WorkshopMetrics> fetchMetrics({int windowDays = 30}) =>
      _service.getWorkshopMetrics(windowDays: windowDays);
}
