import '../../../core/constants/api_endpoints.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/network/api_client.dart';
import '../../models/models.dart';
import '../admin_workshop_service.dart';

/// The founder's CRUD over any workshop's profile and catalogue, over REST —
/// same conventions as [ApiWorkshopService]: one arrow-expression method per
/// call, `?key: ?value` to omit null query/body entries rather than sending
/// them as `null`.
class ApiAdminWorkshopService implements AdminWorkshopService {
  const ApiAdminWorkshopService(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------- profile

  @override
  Future<ServiceProvider> getProvider(String providerId) async =>
      ServiceProvider.fromJson(
        await _client.get(ApiEndpoints.adminProvider(providerId)),
      );

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
  }) async => ServiceProvider.fromJson(
    await _client.put(
      ApiEndpoints.adminProvider(providerId),
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
  Future<void> deleteProvider(String providerId) =>
      _client.delete(ApiEndpoints.adminProvider(providerId));

  @override
  Future<ServiceProvider> updateCrDocument(
    String providerId,
    MediaAttachment document,
  ) async => ServiceProvider.fromJson(
    await _client.put(
      ApiEndpoints.adminProviderCrDocument(providerId),
      body: {
        'id': document.id,
        'base64Data': document.base64Data,
        'mimeType': document.mimeType,
        'fileName': document.fileName,
        'caption': document.caption.isEmpty ? null : document.caption,
      },
    ),
  );

  // ---------------------------------------------------------- offerings

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
  Future<List<ServiceOffering>> getProviderOfferings(String providerId) async =>
      (await _client.getList(
        ApiEndpoints.adminProviderOfferings(providerId),
      )).map(ServiceOffering.fromJson).toList();

  @override
  Future<ServiceOffering> createProviderOffering(
    String providerId, {
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
      ApiEndpoints.adminProviderOfferings(providerId),
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
    MediaAttachment? photo,
  }) async => ServiceOffering.fromJson(
    await _client.put(
      ApiEndpoints.adminProviderOffering(providerId, offeringId),
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
  Future<ServiceOffering> setProviderOfferingActive(
    String providerId,
    String offeringId, {
    required bool isActive,
  }) async => ServiceOffering.fromJson(
    await _client.patch(
      ApiEndpoints.adminProviderOfferingActive(providerId, offeringId),
      body: {'isActive': isActive},
    ),
  );

  @override
  Future<void> deleteProviderOffering(String providerId, String offeringId) =>
      _client.delete(
        ApiEndpoints.adminProviderOffering(providerId, offeringId),
      );

  // ----------------------------------------------------------- add-ons

  @override
  Future<List<AddOn>> getProviderAddOns(String providerId) async =>
      (await _client.getList(
        ApiEndpoints.adminProviderAddOns(providerId),
      )).map(AddOn.fromJson).toList();

  @override
  Future<AddOn> createProviderAddOn(
    String providerId, {
    required L name,
    required double price,
    required bool isPart,
  }) async => AddOn.fromJson(
    await _client.post(
      ApiEndpoints.adminProviderAddOns(providerId),
      body: {
        'nameAr': name.ar,
        'nameEn': name.en,
        'price': price,
        'isPart': isPart,
      },
    ),
  );

  @override
  Future<AddOn> updateProviderAddOn(
    String providerId,
    String addOnId, {
    required L name,
    required double price,
    required bool isPart,
  }) async => AddOn.fromJson(
    await _client.put(
      ApiEndpoints.adminProviderAddOn(providerId, addOnId),
      body: {
        'nameAr': name.ar,
        'nameEn': name.en,
        'price': price,
        'isPart': isPart,
      },
    ),
  );

  @override
  Future<void> deleteProviderAddOn(String providerId, String addOnId) =>
      _client.delete(ApiEndpoints.adminProviderAddOn(providerId, addOnId));
}
