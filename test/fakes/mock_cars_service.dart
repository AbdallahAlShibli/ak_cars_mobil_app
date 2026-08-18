import 'package:ak_cars_mobil_app/data/models/car_listing.dart';
import 'package:ak_cars_mobil_app/data/models/cars_filter.dart';
import 'package:ak_cars_mobil_app/data/models/gallery_listing.dart';
import 'package:ak_cars_mobil_app/data/models/spec_catalog.dart';
import 'package:ak_cars_mobil_app/data/services/cars_service.dart';

import 'data/mock_cars_data.dart';
import 'fake_service_base.dart';

class MockCarsService with MockServiceBase implements CarsService {
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

  /// Ads created during a test live in `MyAdsNotifier`; there is nothing
  /// persisted to restore.
  @override
  Future<List<GalleryListing>> fetchMyAds() =>
      respond(const <GalleryListing>[]);
}
