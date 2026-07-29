import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_flags.dart';
import '../data/models/gallery_listing.dart';
import '../data/models/product.dart';
import '../data/models/service_offering.dart';
import '../di/providers.dart';
import 'cars_state.dart';
import 'catalog_state.dart';
import 'settings_state.dart';
import 'shop_state.dart';

/// What the home search pill searched before this existed: nothing. The pill
/// looked like a field, carried the hint "Search services, parts, cars…", and
/// its only behaviour was `context.go('/services')`.
///
/// [SearchResults] is that hint made real — one query across all three
/// catalogues, each matched by its own model so the rules stay next to the
/// data.
class SearchResults {
  const SearchResults({
    required this.services,
    required this.parts,
    required this.cars,
  });

  static const empty =
      SearchResults(services: [], parts: [], cars: []);

  /// Cheapest matching offering per category, so one query does not return
  /// the same service eleven times, once per workshop.
  final List<ServiceOffering> services;
  final List<Product> parts;
  final List<GalleryListing> cars;

  int get total => services.length + parts.length + cars.length;

  bool get isEmpty => total == 0;
}

/// Results for [query]. Trimmed-empty queries return [SearchResults.empty]
/// rather than the whole catalogue — a blank box means "nothing asked yet",
/// not "show me everything".
final searchResultsProvider =
    Provider.family<SearchResults, String>((ref, query) {
  if (query.trim().isEmpty) return SearchResults.empty;

  final locations = ref.watch(locationCatalogProvider);
  final isAr = ref.watch(settingsProvider).isArabic;

  String place(String area, String region) =>
      '${locations.localized(area, isAr)} ${locations.localized(region, isAr)}';

  // One row per service category: the cheapest workshop selling it. Which
  // workshop is the next screen's decision, not the search result's.
  final byCategory = <String, ServiceOffering>{};
  // Priced: a search result that quotes the undiscounted price would send the
  // user to a page showing a different, lower one.
  for (final offering
      in ref.watch(serviceMarketplaceRepositoryProvider).pricedOfferings) {
    if (!offering.matchesQuery(query,
        localizedPlace: place(offering.provider.area, offering.provider.region))) {
      continue;
    }
    final current = byCategory[offering.categoryId];
    if (current == null ||
        (offering.price ?? double.infinity) <
            (current.price ?? double.infinity)) {
      byCategory[offering.categoryId] = offering;
    }
  }

  // A hidden pillar contributes nothing — not rows, and not to the result
  // count either. Filtering here rather than in the widget keeps "3 results"
  // honest and stops the screen offering a tap into a route that is not
  // registered while the flag is off.
  return SearchResults(
    services: byCategory.values.toList(),
    parts: AppFlags.partsStoreEnabled
        ? ref
            .watch(productsProvider)
            .where((p) => p.matchesQuery(query))
            .toList()
        : const [],
    cars: AppFlags.carMarketplaceEnabled
        ? ref
            .watch(galleryFeedProvider)
            .where((l) => l.matchesQuery(query,
                localizedRegion: locations.localizedRegion(l.region, isAr)))
            .toList()
        : const [],
  );
});
