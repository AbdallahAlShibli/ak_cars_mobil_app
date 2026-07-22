import '../../config/app_config.dart';
import '../datasources/mock/mock_cars_data.dart';
import '../models/car_listing.dart';
import '../models/cars_filter.dart';
import '../models/gallery_listing.dart';
import '../models/spec_catalog.dart';
import 'mock_service_base.dart';

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

class MockCarsService with MockServiceBase implements CarsService {
  MockCarsService({required this.config});

  @override
  final AppConfig config;

  @override
  Future<List<GalleryListing>> fetchListings({
    CarsFilter? filter,
    SpecCatalog? specs,
  }) =>
      respond(
        filter == null
            ? MockCarsData.galleryListings
            : filter.apply(
                MockCarsData.galleryListings,
                specs ?? SpecCatalog.empty,
              ),
      );

  @override
  Future<GalleryListing> fetchListing(String listingId) {
    GalleryListing? match;
    for (final listing in MockCarsData.galleryListings) {
      if (listing.id == listingId) match = listing;
    }
    return respondRequired(match, 'Listing $listingId');
  }

  @override
  Future<List<GalleryListing>> fetchRelated(String listingId) async {
    final listing = await fetchListing(listingId);
    return MockCarsData.galleryListings
        .where((o) => o.id != listing.id && o.model == listing.model)
        .toList(growable: false);
  }

  @override
  Future<List<CarListing>> fetchHomeListings() =>
      respond(MockCarsData.homeListings);

  /// Ads created during a mock session live in `MyAdsNotifier`; there is
  /// nothing persisted to restore.
  @override
  Future<List<GalleryListing>> fetchMyAds() =>
      respond(const <GalleryListing>[]);
}
