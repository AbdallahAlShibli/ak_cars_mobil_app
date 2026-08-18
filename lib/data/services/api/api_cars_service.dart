import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../models/car_listing.dart';
import '../../models/cars_filter.dart';
import '../../models/gallery_listing.dart';
import '../../models/spec_catalog.dart';
import '../cars_service.dart';

/// The cars marketplace over REST (§12): `GET /cars` and its variants.
///
/// [CarsFilter.toQueryParameters] already shapes multi-select facets as
/// `List<String>`/`List<int>` values — the right shape for a repeated query
/// parameter, but the backend's `CarListingFilter` binds each facet from a
/// single **comma-separated** value (e.g. `?fuels=Petrol,Hybrid`), not
/// repeated `fuels=` pairs. [_flatten] joins every list value before the
/// request goes out so the two sides agree on the wire format.
class ApiCarsService implements CarsService {
  const ApiCarsService(this._client);

  final ApiClient _client;

  /// Listings fetched with no filter and the home rail's trimmed projection
  /// both need *a* page size since the interface has no paging concept of its
  /// own; the server clamps `pageSize` to 100, so that is the most this call
  /// can ever return in one request.
  static const _maxPageSize = 100;

  /// Small enough to read as "a few featured cars", matching the shape of
  /// `MockCarsData.homeListings`.
  static const _homeRailSize = 6;

  Map<String, dynamic> _flatten(Map<String, dynamic> params) => {
        for (final entry in params.entries)
          entry.key: entry.value is List
              ? (entry.value as List).join(',')
              : entry.value,
      };

  @override
  Future<List<GalleryListing>> fetchListings({
    CarsFilter? filter,
    SpecCatalog? specs,
  }) async {
    // [specs] resolves the engine-size facet locally for the mock; the
    // server already filters `engineSizes` itself, so it is intentionally
    // unused here — see the interface's doc comment.
    final query = _flatten({
      ...?filter?.toQueryParameters(),
      'pageSize': _maxPageSize,
    });
    final listings = await _client.getList(
      ApiEndpoints.carListings,
      queryParameters: query,
    );
    return listings.map(GalleryListing.fromJson).toList();
  }

  @override
  Future<GalleryListing> fetchListing(String listingId) async =>
      GalleryListing.fromJson(
        await _client.get(ApiEndpoints.carListing(listingId)),
      );

  @override
  Future<List<GalleryListing>> fetchRelated(String listingId) async =>
      (await _client.getList(ApiEndpoints.relatedCarListings(listingId)))
          .map(GalleryListing.fromJson)
          .toList();

  @override
  Future<List<CarListing>> fetchHomeListings() async {
    final listings = await _client.getList(
      ApiEndpoints.carListings,
      queryParameters: {'sort': GallerySort.newest.key, 'pageSize': _homeRailSize},
    );
    return listings
        .map(GalleryListing.fromJson)
        .map(_toCarListing)
        .toList();
  }

  /// The home rail has no dedicated backend projection — it is built here
  /// from the same [GalleryListing] the full marketplace feed uses.
  /// [CarListing.spec] shows the regional spec ("GCC", "Japanese", …) as the
  /// closest one-line equivalent to the mock's free-text blurb; there is no
  /// server field that means exactly "one-line spec highlight".
  CarListing _toCarListing(GalleryListing listing) => CarListing(
        id: listing.id,
        title: listing.displayTitle,
        year: listing.year,
        km: listing.mileageValue,
        region: listing.governorate,
        price: listing.price ?? 0,
        spec: listing.regionalSpec,
        icon: listing.icon,
        photoCount: listing.photoCount,
      );

  @override
  Future<List<GalleryListing>> fetchMyAds() async =>
      (await _client.getList(ApiEndpoints.myCarAds))
          .map(GalleryListing.fromJson)
          .toList();
}
