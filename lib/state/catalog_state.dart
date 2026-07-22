/// Read-only views onto the reference catalogs warmed at bootstrap.
///
/// Screens watch these instead of reaching for a static data class, so the
/// same widgets keep working once the catalogs come from the API.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/location_catalog.dart';
import '../data/models/spec_catalog.dart';
import '../data/models/vehicle_catalog.dart';
import '../di/providers.dart';

/// Make/model/trim catalog behind every car picker.
final vehicleCatalogProvider = Provider<VehicleCatalog>(
  (ref) => ref.watch(catalogRepositoryProvider).vehicles,
);

/// Canonical vehicle-spec vocabulary shared by the filter and the post-ad
/// form.
final specCatalogProvider = Provider<SpecCatalog>(
  (ref) => ref.watch(catalogRepositoryProvider).specs,
);

/// Oman governorates, wilayats and their Arabic display names.
final locationCatalogProvider = Provider<LocationCatalog>(
  (ref) => ref.watch(catalogRepositoryProvider).locations,
);

/// Governorates the marketplace currently operates in.
final serviceRegionsProvider = Provider<List<String>>(
  (ref) => ref.watch(catalogRepositoryProvider).serviceRegions,
);
