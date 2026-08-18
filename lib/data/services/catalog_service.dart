import '../models/location_catalog.dart';
import '../models/spec_catalog.dart';
import '../models/vehicle_catalog.dart';

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
