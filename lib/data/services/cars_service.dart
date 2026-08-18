import '../models/car_listing.dart';
import '../models/cars_filter.dart';
import '../models/gallery_listing.dart';
import '../models/spec_catalog.dart';

/// The cars marketplace: browsing listings and publishing ads.
///
/// Phase 2: implement `RestCarsService` against `/cars`. [fetchListings]
/// already accepts the filter, whose [CarsFilter.toQueryParameters] is the
/// query string that endpoint expects.
abstract interface class CarsService {
  /// The platform feed, optionally narrowed by [filter].
  ///
  /// [specs] resolves the engine-size facet locally; the REST implementation
  /// ignores it and lets the server filter.
  Future<List<GalleryListing>> fetchListings({
    CarsFilter? filter,
    SpecCatalog? specs,
  });

  Future<GalleryListing> fetchListing(String listingId);

  /// Other listings of the same model.
  Future<List<GalleryListing>> fetchRelated(String listingId);

  /// Compact summaries for the home screen rail.
  Future<List<CarListing>> fetchHomeListings();

  /// Ads published by the signed-in user.
  Future<List<GalleryListing>> fetchMyAds();
}
