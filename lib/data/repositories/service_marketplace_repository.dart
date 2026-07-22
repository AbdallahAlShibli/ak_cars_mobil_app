import '../models/add_on.dart';
import '../models/service_category.dart';
import '../models/service_offering.dart';
import '../models/service_provider.dart';
import '../models/service_request.dart';
import '../services/service_marketplace_service.dart';
import 'warm_cache.dart';

/// Service discovery and booking.
///
/// The catalogue side (categories, providers, offerings, add-ons, slots) is
/// warmed at bootstrap and read synchronously; the transactional side
/// (creating and advancing a request) stays asynchronous.
abstract interface class ServiceMarketplaceRepository {
  Future<void> warmUp();

  List<ServiceCategory> get categories;

  /// Categories rendered as big "Car service" package cards.
  List<ServiceCategory> get primaryCategories;

  /// Categories rendered as "Other services" tiles.
  List<ServiceCategory> get otherCategories;

  List<ServiceProvider> get providers;
  List<ServiceOffering> get offerings;

  /// Governorates that actually have at least one provider, in catalogue
  /// order. The region filter is built from this so it can never offer a
  /// governorate the marketplace does not serve.
  List<String> get providerRegions;

  /// Offerings within one category, optionally limited to one governorate.
  List<ServiceOffering> offeringsFor(String categoryId, {String? region});

  /// How many distinct providers serve a category, optionally within one
  /// governorate.
  int providerCountFor(String categoryId, {String? region});

  /// Cheapest real price in a category, or null when everything in scope is
  /// quote-only. Derived from the offerings rather than stored on the
  /// category, so a "from OMR x" label can never contradict the list it
  /// sits above.
  double? fromPriceFor(String categoryId, {String? region});

  ServiceOffering? offeringById(String offeringId);

  /// Optional extras the given provider sells.
  List<AddOn> addOnsFor(String providerId);

  /// Bookable slots for a provider, and which are already taken.
  BookingAvailability availabilityFor(String providerId);

  Future<ServiceRequest> createRequest(CreateServiceRequestDraft draft);

  Future<List<ServiceRequest>> fetchRequests();

  Future<ServiceRequest> updateRequestStatus(
    String requestId,
    RequestStatus status,
  );
}

class ServiceMarketplaceRepositoryImpl implements ServiceMarketplaceRepository {
  ServiceMarketplaceRepositoryImpl(this._service);

  final ServiceMarketplaceService _service;

  final _categories = WarmCache<List<ServiceCategory>>(fallback: const []);
  final _providers = WarmCache<List<ServiceProvider>>(fallback: const []);
  final _offerings = WarmCache<List<ServiceOffering>>(fallback: const []);

  /// Add-ons and slots are per-provider, so they are warmed lazily and cached
  /// as they are asked for rather than fetched for every provider up front.
  final Map<String, List<AddOn>> _addOns = {};
  final Map<String, BookingAvailability> _availability = {};

  @override
  Future<void> warmUp() async {
    await Future.wait([
      _categories.load(_service.fetchCategories),
      _providers.load(_service.fetchProviders),
      _offerings.load(() => _service.fetchOfferings()),
    ]);
    await Future.wait([
      for (final provider in _providers.value) _warmProvider(provider.id),
    ]);
  }

  Future<void> _warmProvider(String providerId) async {
    _addOns[providerId] = await _service.fetchAddOns(providerId);
    _availability[providerId] = await _service.fetchAvailability(providerId);
  }

  @override
  List<ServiceCategory> get categories => _categories.value;

  @override
  List<ServiceCategory> get primaryCategories =>
      categories.where((c) => c.primary).toList(growable: false);

  @override
  List<ServiceCategory> get otherCategories =>
      categories.where((c) => !c.primary).toList(growable: false);

  @override
  List<ServiceProvider> get providers => _providers.value;

  @override
  List<ServiceOffering> get offerings => _offerings.value;

  @override
  List<String> get providerRegions => {
        for (final provider in providers)
          if (provider.region.isNotEmpty) provider.region,
      }.toList(growable: false);

  @override
  List<ServiceOffering> offeringsFor(String categoryId, {String? region}) =>
      offerings
          .where((o) =>
              o.categoryId == categoryId &&
              (region == null || o.provider.region == region))
          .toList(growable: false);

  @override
  int providerCountFor(String categoryId, {String? region}) =>
      offeringsFor(categoryId, region: region)
          .map((o) => o.provider.id)
          .toSet()
          .length;

  @override
  double? fromPriceFor(String categoryId, {String? region}) {
    double? cheapest;
    for (final offering in offeringsFor(categoryId, region: region)) {
      final price = offering.price;
      if (price != null && (cheapest == null || price < cheapest)) {
        cheapest = price;
      }
    }
    return cheapest;
  }

  @override
  ServiceOffering? offeringById(String offeringId) {
    for (final offering in offerings) {
      if (offering.id == offeringId) return offering;
    }
    return null;
  }

  @override
  List<AddOn> addOnsFor(String providerId) => _addOns[providerId] ?? const [];

  @override
  BookingAvailability availabilityFor(String providerId) =>
      _availability[providerId] ??
      const BookingAvailability(slots: [], bookedSlots: {});

  @override
  Future<ServiceRequest> createRequest(CreateServiceRequestDraft draft) =>
      _service.createRequest(draft);

  @override
  Future<List<ServiceRequest>> fetchRequests() => _service.fetchRequests();

  @override
  Future<ServiceRequest> updateRequestStatus(
    String requestId,
    RequestStatus status,
  ) =>
      _service.updateRequestStatus(requestId, status);
}
