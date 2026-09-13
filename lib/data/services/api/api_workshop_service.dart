import '../../../core/constants/api_endpoints.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../models/models.dart';
import '../workshop_service.dart';

/// A workshop owner's own dashboard over REST — see `docs/api_contract.md`'s
/// "My workshop" section for every wire shape this implements.
///
/// Same conventions as [ApiServiceMarketplaceService]: one arrow-expression
/// method per call, `?key: ?value` to omit null query/body entries rather
/// than sending them as `null`.
class ApiWorkshopService implements WorkshopService {
  const ApiWorkshopService(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------- profile

  @override
  Future<MyWorkshopProfile> getMyWorkshop() async =>
      MyWorkshopProfile.fromJson(await _client.get(ApiEndpoints.myWorkshop));

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
  }) async => ServiceProvider.fromJson(
    await _client.put(
      ApiEndpoints.myWorkshop,
      body: {
        'nameAr': name.ar,
        'nameEn': name.en,
        'area': area,
        'region': region,
        'phone': ?phone,
        'whatsapp': ?whatsapp,
        'hoursAr': ?hours?.ar,
        'hoursEn': ?hours?.en,
        'fulfillments': [for (final f in fulfillments) f.key],
        'capabilities': [for (final c in capabilities) c.key],
        'pickupFee': pickupFee,
        'vatNumber': ?vatNumber,
        'crNumber': ?crNumber,
      },
    ),
  );

  @override
  Future<WorkshopSummary> getMyWorkshopSummary() async =>
      WorkshopSummary.fromJson(
        await _client.get(ApiEndpoints.myWorkshopSummary),
      );

  // ---------------------------------------------------------- offerings

  @override
  Future<List<ServiceOffering>> getMyOfferings() async =>
      (await _client.getList(
        ApiEndpoints.myWorkshopOfferings,
      )).map(ServiceOffering.fromJson).toList();

  Map<String, dynamic> _offeringBody({
    required String categoryId,
    required L name,
    required L description,
    double? price,
    int? durationMin,
    List<L> includes = const [],
    int? warrantyMonths,
    MediaAttachment? photo,
  }) => {
    'categoryId': categoryId,
    'nameAr': name.ar,
    'nameEn': name.en,
    'descriptionAr': description.ar,
    'descriptionEn': description.en,
    'price': price,
    'durationMin': durationMin,
    'includes': [
      for (final i in includes) {'ar': i.ar, 'en': i.en},
    ],
    'warrantyMonths': warrantyMonths,
    'photoId': ?photo?.id,
    'photoBase64': ?photo?.base64Data,
    'photoMimeType': ?photo?.mimeType,
    'photoFileName': ?photo?.fileName,
  };

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
  }) async => ServiceOffering.fromJson(
    await _client.post(
      ApiEndpoints.myWorkshopOfferings,
      body: _offeringBody(
        categoryId: categoryId,
        name: name,
        description: description,
        price: price,
        durationMin: durationMin,
        includes: includes,
        warrantyMonths: warrantyMonths,
        photo: photo,
      ),
    ),
  );

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
  }) async => ServiceOffering.fromJson(
    await _client.put(
      ApiEndpoints.myWorkshopOffering(offeringId),
      body: _offeringBody(
        categoryId: categoryId,
        name: name,
        description: description,
        price: price,
        durationMin: durationMin,
        includes: includes,
        warrantyMonths: warrantyMonths,
        photo: photo,
      ),
    ),
  );

  @override
  Future<ServiceOffering> setOfferingActive(
    String offeringId, {
    required bool isActive,
  }) async => ServiceOffering.fromJson(
    await _client.patch(
      ApiEndpoints.myWorkshopOfferingActive(offeringId),
      body: {'isActive': isActive},
    ),
  );

  @override
  Future<void> deleteOffering(String offeringId) =>
      _client.delete(ApiEndpoints.myWorkshopOffering(offeringId));

  // ----------------------------------------------------------- add-ons

  @override
  Future<List<AddOn>> getMyAddOns() async => (await _client.getList(
    ApiEndpoints.myWorkshopAddOns,
  )).map(AddOn.fromJson).toList();

  @override
  Future<AddOn> createAddOn({
    required L name,
    required double price,
    required bool isPart,
  }) async => AddOn.fromJson(
    await _client.post(
      ApiEndpoints.myWorkshopAddOns,
      body: {
        'nameAr': name.ar,
        'nameEn': name.en,
        'price': price,
        'isPart': isPart,
      },
    ),
  );

  @override
  Future<AddOn> updateAddOn(
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  }) async => AddOn.fromJson(
    await _client.put(
      ApiEndpoints.myWorkshopAddOn(addOnId),
      body: {
        'nameAr': name.ar,
        'nameEn': name.en,
        'price': price,
        'isPart': isPart,
      },
    ),
  );

  @override
  Future<void> deleteAddOn(String addOnId) =>
      _client.delete(ApiEndpoints.myWorkshopAddOn(addOnId));

  // ---------------------------------------------------------- inventory

  @override
  Future<List<InventoryItem>> getInventory() async => (await _client.getList(
    ApiEndpoints.myWorkshopInventory,
  )).map(InventoryItem.fromJson).toList();

  @override
  Future<List<InventoryItem>> getLowStockInventory() async =>
      (await _client.getList(
        ApiEndpoints.myWorkshopLowStock,
      )).map(InventoryItem.fromJson).toList();

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
  }) async => InventoryItem.fromJson(
    await _client.post(
      ApiEndpoints.myWorkshopInventory,
      body: {
        'nameAr': name.ar,
        'nameEn': name.en,
        'sku': sku,
        'partNumber': ?partNumber,
        'brand': ?brand,
        'categoryId': ?categoryId,
        'unitCost': unitCost,
        'sellPrice': sellPrice,
        'reorderLevel': reorderLevel,
        'unit': unit.key,
        'location': ?location,
      },
    ),
  );

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
  }) async => InventoryItem.fromJson(
    await _client.put(
      ApiEndpoints.myWorkshopInventoryItem(itemId),
      body: {
        'nameAr': name.ar,
        'nameEn': name.en,
        'sku': sku,
        'partNumber': ?partNumber,
        'brand': ?brand,
        'categoryId': ?categoryId,
        'unitCost': unitCost,
        'sellPrice': sellPrice,
        'reorderLevel': reorderLevel,
        'unit': unit.key,
        'location': ?location,
        'isActive': isActive,
      },
    ),
  );

  @override
  Future<void> deleteInventoryItem(String itemId) =>
      _client.delete(ApiEndpoints.myWorkshopInventoryItem(itemId));

  @override
  Future<InventoryItem> recordInventoryMovement(
    String itemId, {
    required int delta,
    required InventoryMovementReason reason,
    String? requestId,
    String? note,
  }) async => InventoryItem.fromJson(
    await _client.post(
      ApiEndpoints.myWorkshopInventoryMovements(itemId),
      body: {
        'delta': delta,
        'reason': reason.key,
        'requestId': ?requestId,
        'note': ?note,
      },
    ),
  );

  // ------------------------------------------------------------- staff

  @override
  Future<List<WorkshopStaff>> getStaff() async => (await _client.getList(
    ApiEndpoints.myWorkshopStaff,
  )).map(WorkshopStaff.fromJson).toList();

  @override
  Future<WorkshopStaff> createStaff({
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
    String? userId,
  }) async => WorkshopStaff.fromJson(
    await _client.post(
      ApiEndpoints.myWorkshopStaff,
      body: {
        'name': name,
        'phone': ?phone,
        'role': role.key,
        'specialties': specialties,
        'userId': ?userId,
      },
    ),
  );

  @override
  Future<WorkshopStaff> updateStaff(
    String staffId, {
    required String name,
    String? phone,
    required WorkshopStaffRole role,
    List<String> specialties = const [],
  }) async => WorkshopStaff.fromJson(
    await _client.put(
      ApiEndpoints.myWorkshopStaffMember(staffId),
      body: {
        'name': name,
        'phone': ?phone,
        'role': role.key,
        'specialties': specialties,
      },
    ),
  );

  @override
  Future<void> deactivateStaff(String staffId) =>
      _client.delete(ApiEndpoints.myWorkshopStaffMember(staffId));

  @override
  Future<ServiceRequest> assignRequest(
    String requestId, {
    required String staffId,
  }) async => ServiceRequest.fromJson(
    await _client.post(
      ApiEndpoints.myWorkshopAssignRequest(requestId),
      body: {'staffId': staffId},
    ),
  );

  // ---------------------------------------------------------- requests

  @override
  Future<List<ServiceRequest>> getMyWorkshopRequests({
    EscrowState? status,
    DateTime? from,
    DateTime? to,
    String? query,
  }) async => (await _client.getList(
    ApiEndpoints.myWorkshopRequests,
    queryParameters: {
      'status': ?status?.key,
      'from': ?from?.toIso8601String(),
      'to': ?to?.toIso8601String(),
      'q': ?query,
    },
  )).map(ServiceRequest.fromJson).toList();

  // --------------------------------------------------------- customers

  @override
  Future<List<WorkshopCustomer>> getWorkshopCustomers({
    String? query,
    WorkshopCustomerTag? tag,
  }) async => (await _client.getList(
    ApiEndpoints.myWorkshopCustomers,
    queryParameters: {'q': ?query, 'tag': ?tag?.key},
  )).map(WorkshopCustomer.fromJson).toList();

  @override
  Future<WorkshopCustomerDetail> getWorkshopCustomer(String userId) async =>
      WorkshopCustomerDetail.fromJson(
        await _client.get(ApiEndpoints.myWorkshopCustomer(userId)),
      );

  @override
  Future<WorkshopCustomerNote> addCustomerNote(
    String userId, {
    required String body,
  }) async => WorkshopCustomerNote.fromJson(
    await _client.post(
      ApiEndpoints.myWorkshopCustomerNotes(userId),
      body: {'body': body},
    ),
  );

  // ---------------------------------------------------------- schedule

  @override
  Future<WorkshopDaySchedule> getSchedule(DateTime date) async =>
      WorkshopDaySchedule.fromJson(
        await _client.get(
          ApiEndpoints.myWorkshopSchedule,
          queryParameters: {'date': date.toIso8601String().split('T').first},
        ),
      );

  @override
  Future<WorkshopSchedule> updateSchedule({
    L? hours,
    List<String> slotTemplate = const [],
    required int capacityPerSlot,
    List<String> closedDays = const [],
  }) async => WorkshopSchedule.fromJson(
    await _client.put(
      ApiEndpoints.myWorkshopSchedule,
      body: {
        'hoursAr': ?hours?.ar,
        'hoursEn': ?hours?.en,
        'slotTemplate': slotTemplate,
        'capacityPerSlot': capacityPerSlot,
        'closedDays': closedDays,
      },
    ),
  );

  // ------------------------------------------------------ earnings/metrics

  @override
  Future<WorkshopEarnings> getWorkshopEarnings({int windowDays = 30}) async =>
      WorkshopEarnings.fromJson(
        await _client.get(
          ApiEndpoints.myWorkshopEarnings,
          queryParameters: {'windowDays': windowDays},
        ),
      );

  @override
  Future<WorkshopMetrics> getWorkshopMetrics({int windowDays = 30}) async =>
      WorkshopMetrics.fromJson(
        await _client.get(
          ApiEndpoints.myWorkshopMetrics,
          queryParameters: {'windowDays': windowDays},
        ),
      );
}
