import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/car_listing.dart';
import '../data/models/cars_filter.dart';
import '../data/models/gallery_listing.dart';
import '../di/providers.dart';
import 'catalog_state.dart';

/// Platform listings, unfiltered.
final platformListingsProvider = Provider<List<GalleryListing>>(
  (ref) => ref.watch(carsRepositoryProvider).listings,
);

/// Compact summaries for the home screen rail.
final homeListingsProvider = Provider<List<CarListing>>(
  (ref) => ref.watch(carsRepositoryProvider).homeListings,
);

/// Ads published by the signed-in user.
class MyAdsNotifier extends Notifier<List<GalleryListing>> {
  @override
  List<GalleryListing> build() => const [];

  void add(GalleryListing ad) => state = [ad, ...state];

  void remove(String id) => state = state.where((a) => a.id != id).toList();
}

final myAdsProvider =
    NotifierProvider<MyAdsNotifier, List<GalleryListing>>(MyAdsNotifier.new);

/// Full gallery feed = the user's ads first, then platform listings.
final galleryFeedProvider = Provider<List<GalleryListing>>((ref) => [
      ...ref.watch(myAdsProvider),
      ...ref.watch(platformListingsProvider),
    ]);

class CarsFilterNotifier extends Notifier<CarsFilter> {
  @override
  CarsFilter build() => const CarsFilter();

  void set(CarsFilter filter) => state = filter;

  /// Single-select shortcut used by the cars-screen category chips.
  void setBodyType(String? bodyType) =>
      state = state.copyWith(bodyTypes: bodyType == null ? const {} : {bodyType});

  void reset() => state = const CarsFilter();
}

final carsFilterProvider =
    NotifierProvider<CarsFilterNotifier, CarsFilter>(CarsFilterNotifier.new);

/// Instant, local-first filtered + sorted cars market feed.
final filteredGalleryProvider = Provider<List<GalleryListing>>(
  (ref) => ref.watch(carsFilterProvider).apply(
        ref.watch(galleryFeedProvider),
        ref.watch(specCatalogProvider),
      ),
);

/// Other listings of the same model as [listing].
final relatedListingsProvider =
    Provider.family<List<GalleryListing>, GalleryListing>(
  (ref, listing) => ref.watch(carsRepositoryProvider).related(listing),
);
