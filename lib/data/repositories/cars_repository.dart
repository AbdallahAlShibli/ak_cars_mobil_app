import '../models/car_listing.dart';
import '../models/cars_filter.dart';
import '../models/gallery_listing.dart';
import '../models/spec_catalog.dart';
import '../services/cars_service.dart';
import 'warm_cache.dart';

/// The cars marketplace feed.
///
/// The platform feed is warmed at bootstrap so filtering stays instant as the
/// user taps facets. [fetchListings] is the same query executed remotely and
/// becomes the primary path once inventory outgrows the warm cache.
abstract interface class CarsRepository {
  Future<void> warmUp();

  /// Every platform listing, unfiltered.
  List<GalleryListing> get listings;

  /// Compact summaries for the home screen rail.
  List<CarListing> get homeListings;

  GalleryListing? listingById(String listingId);

  /// Other listings of the same model.
  List<GalleryListing> related(GalleryListing listing);

  /// Sub-model options for a model, used by the Sub-Model facet.
  Future<List<GalleryListing>> fetchListings({
    CarsFilter? filter,
    SpecCatalog? specs,
  });
}

class CarsRepositoryImpl implements CarsRepository {
  CarsRepositoryImpl(this._service);

  final CarsService _service;

  final _listings = WarmCache<List<GalleryListing>>(fallback: const []);
  final _homeListings = WarmCache<List<CarListing>>(fallback: const []);

  @override
  // `async`, not `=> Future.wait(...)`, and that is load-bearing rather than a
  // style choice. `Future.wait` here hands back a `Future<List<...>>`; widening
  // it to the declared `Future<void>` is legal at compile time but does not
  // change the object, so the future's *runtime* type argument stays
  // `List<...>`. `warmUp().catchError((_) {})` then fails with "the error
  // handler of Future.catchError must return a value of the future's type" —
  // and does so only once the warm-up actually throws, replacing a real error
  // with a confusing one. An `async` body produces a genuine `Future<void>`.
  Future<void> warmUp() async {
    await Future.wait([
      _listings.load(() => _service.fetchListings()),
      _homeListings.load(_service.fetchHomeListings),
    ]);
  }

  @override
  List<GalleryListing> get listings => _listings.value;

  @override
  List<CarListing> get homeListings => _homeListings.value;

  @override
  GalleryListing? listingById(String listingId) {
    for (final listing in listings) {
      if (listing.id == listingId) return listing;
    }
    return null;
  }

  @override
  List<GalleryListing> related(GalleryListing listing) => listings
      .where((o) => o.id != listing.id && o.model == listing.model)
      .toList(growable: false);

  @override
  Future<List<GalleryListing>> fetchListings({
    CarsFilter? filter,
    SpecCatalog? specs,
  }) =>
      _service.fetchListings(filter: filter, specs: specs);
}
