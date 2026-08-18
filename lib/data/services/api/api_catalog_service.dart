import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../models/location_catalog.dart';
import '../../models/spec_catalog.dart';
import '../../models/vehicle_catalog.dart';
import '../catalog_service.dart';

/// Reference data (make/model catalog, spec vocabulary, locations) over
/// REST (§12).
class ApiCatalogService implements CatalogService {
  const ApiCatalogService(this._client);

  final ApiClient _client;

  @override
  Future<VehicleCatalog> fetchVehicleCatalog() async =>
      VehicleCatalog.fromJson(await _client.get(ApiEndpoints.carCatalog));

  @override
  Future<SpecCatalog> fetchSpecCatalog() async =>
      SpecCatalog.fromJson(await _client.get(ApiEndpoints.carSpecOptions));

  @override
  Future<LocationCatalog> fetchLocationCatalog() async =>
      LocationCatalog.fromJson(await _client.get(ApiEndpoints.locations));

  /// Governorates the marketplace currently operates in.
  ///
  /// Not backed by any endpoint: `GET /locations` answers with every Omani
  /// governorate and its wilayats, not the curated subset the service
  /// marketplace is live in today. The backend has no concept yet of "which
  /// governorates does the platform actually operate in" — see
  /// `MockCatalogData.serviceRegions`' doc comment for why the subset matters
  /// (a governorate missing here is one the user can never select even though
  /// workshops serve it). Kept as a client-side constant, same values as the
  /// mock, until the backend grows a real endpoint for it.
  static const _operatingRegions = [
    'Muscat',
    'North Al Batinah',
    'South Al Batinah',
    'Ad Dakhiliyah',
    'Dhofar',
  ];

  @override
  Future<List<String>> fetchServiceRegions() async => _operatingRegions;
}
