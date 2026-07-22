import '../../config/app_config.dart';
import '../datasources/mock/mock_catalog_data.dart';
import '../models/location_catalog.dart';
import '../models/spec_catalog.dart';
import '../models/vehicle_catalog.dart';
import 'mock_service_base.dart';

/// Reference data that changes rarely and is shared across features:
/// the make/model catalog, the vehicle-spec vocabulary and Oman's locations.
///
/// Phase 2: implement `RestCatalogService` against `GET /cars/catalog`,
/// `GET /cars/spec-options`, `GET /cars/trims` and `GET /locations`, then
/// swap the binding in `lib/di/providers.dart`.
abstract interface class CatalogService {
  Future<VehicleCatalog> fetchVehicleCatalog();

  Future<SpecCatalog> fetchSpecCatalog();

  Future<LocationCatalog> fetchLocationCatalog();

  /// Governorates the marketplace currently operates in.
  Future<List<String>> fetchServiceRegions();
}

/// Serves the bundled catalogs. Async on purpose: the call sites already
/// `await`, so switching to the REST implementation changes no caller.
class MockCatalogService with MockServiceBase implements CatalogService {
  MockCatalogService({required this.config});

  @override
  final AppConfig config;

  @override
  Future<VehicleCatalog> fetchVehicleCatalog() =>
      respond(MockCatalogData.vehicleCatalog);

  @override
  Future<SpecCatalog> fetchSpecCatalog() =>
      respond(MockCatalogData.specCatalog);

  @override
  Future<LocationCatalog> fetchLocationCatalog() =>
      respond(MockCatalogData.locationCatalog);

  @override
  Future<List<String>> fetchServiceRegions() =>
      respond(MockCatalogData.serviceRegions);
}
