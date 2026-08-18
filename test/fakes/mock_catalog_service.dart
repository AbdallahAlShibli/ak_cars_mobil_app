import 'package:ak_cars_mobil_app/data/models/location_catalog.dart';
import 'package:ak_cars_mobil_app/data/models/spec_catalog.dart';
import 'package:ak_cars_mobil_app/data/models/vehicle_catalog.dart';
import 'package:ak_cars_mobil_app/data/services/catalog_service.dart';

import 'data/mock_catalog_data.dart';
import 'fake_service_base.dart';

/// Serves the bundled catalogs. Async on purpose: the call sites already
/// `await`, so this and `ApiCatalogService` are interchangeable.
class MockCatalogService with MockServiceBase implements CatalogService {
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
