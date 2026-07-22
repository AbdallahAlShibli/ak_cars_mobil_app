import '../models/location_catalog.dart';
import '../models/spec_catalog.dart';
import '../models/vehicle_catalog.dart';
import '../services/catalog_service.dart';
import 'warm_cache.dart';

/// Reference data shared across features.
///
/// Warmed once during bootstrap, then read synchronously by the pickers and
/// filters that need it while building. Swapping [CatalogService] for the
/// REST implementation changes nothing here.
abstract interface class CatalogRepository {
  /// Fetches every catalog and populates the synchronous getters.
  Future<void> warmUp();

  VehicleCatalog get vehicles;
  SpecCatalog get specs;
  LocationCatalog get locations;

  /// Governorates the marketplace currently operates in.
  List<String> get serviceRegions;

  Future<VehicleCatalog> refreshVehicles();
  Future<SpecCatalog> refreshSpecs();
  Future<LocationCatalog> refreshLocations();
}

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._service);

  final CatalogService _service;

  final _vehicles = WarmCache<VehicleCatalog>(fallback: VehicleCatalog.empty);
  final _specs = WarmCache<SpecCatalog>(fallback: SpecCatalog.empty);
  final _locations = WarmCache<LocationCatalog>(fallback: LocationCatalog.empty);
  final _regions = WarmCache<List<String>>(fallback: const []);

  @override
  VehicleCatalog get vehicles => _vehicles.value;

  @override
  SpecCatalog get specs => _specs.value;

  @override
  LocationCatalog get locations => _locations.value;

  @override
  List<String> get serviceRegions => _regions.value;

  @override
  Future<void> warmUp() => Future.wait([
        _vehicles.load(_service.fetchVehicleCatalog),
        _specs.load(_service.fetchSpecCatalog),
        _locations.load(_service.fetchLocationCatalog),
        _regions.load(_service.fetchServiceRegions),
      ]);

  @override
  Future<VehicleCatalog> refreshVehicles() =>
      _vehicles.load(_service.fetchVehicleCatalog);

  @override
  Future<SpecCatalog> refreshSpecs() => _specs.load(_service.fetchSpecCatalog);

  @override
  Future<LocationCatalog> refreshLocations() =>
      _locations.load(_service.fetchLocationCatalog);
}
