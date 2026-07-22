import '../../config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../datasources/mock/mock_service_data.dart';
import '../models/add_on.dart';
import '../models/service_category.dart';
import '../models/service_offering.dart';
import '../models/service_provider.dart';
import '../models/service_request.dart';
import 'mock_service_base.dart';

/// Slots a provider can be booked into, plus the ones already taken.
class BookingAvailability {
  const BookingAvailability({required this.slots, required this.bookedSlots});

  final List<String> slots;
  final Set<String> bookedSlots;

  bool isAvailable(String slot) => !bookedSlots.contains(slot);
}

/// Service discovery and booking.
///
/// Phase 2: implement `RestServiceMarketplaceService` against the
/// `/service-marketplace/*` endpoints and swap the binding in
/// `lib/di/providers.dart`.
abstract interface class ServiceMarketplaceService {
  Future<List<ServiceCategory>> fetchCategories();

  Future<List<ServiceProvider>> fetchProviders();

  /// All offerings, or only those in [categoryId] when given.
  Future<List<ServiceOffering>> fetchOfferings({String? categoryId});

  Future<ServiceOffering> fetchOffering(String offeringId);

  /// Optional extras the given provider sells.
  Future<List<AddOn>> fetchAddOns(String providerId);

  /// Bookable slots for a provider on a given day, and which are taken.
  Future<BookingAvailability> fetchAvailability(
    String providerId, {
    DateTime? date,
  });

  /// Prices and places a booking, returning the created request.
  Future<ServiceRequest> createRequest(CreateServiceRequestDraft draft);

  /// Bookings belonging to the signed-in user.
  Future<List<ServiceRequest>> fetchRequests();

  /// Moves a request to [status]. Provider-driven in production; the staging
  /// build calls it from the simulated provider portal and the demo button.
  Future<ServiceRequest> updateRequestStatus(
    String requestId,
    RequestStatus status,
  );
}

class MockServiceMarketplaceService
    with MockServiceBase
    implements ServiceMarketplaceService {
  MockServiceMarketplaceService({required this.config});

  @override
  final AppConfig config;

  /// Bookings placed during this session, newest first.
  final List<ServiceRequest> _requests = [];

  /// Mirrors a server-side identity sequence.
  int _nextRequestNumber = 1042;

  @override
  Future<List<ServiceCategory>> fetchCategories() =>
      respond(MockServiceData.categories);

  @override
  Future<List<ServiceProvider>> fetchProviders() =>
      respond(MockServiceData.providers);

  @override
  Future<List<ServiceOffering>> fetchOfferings({String? categoryId}) => respond(
        categoryId == null
            ? MockServiceData.offerings
            : MockServiceData.offerings
                .where((o) => o.categoryId == categoryId)
                .toList(growable: false),
      );

  @override
  Future<ServiceOffering> fetchOffering(String offeringId) {
    ServiceOffering? match;
    for (final offering in MockServiceData.offerings) {
      if (offering.id == offeringId) match = offering;
    }
    return respondRequired(match, 'Offering $offeringId');
  }

  @override
  Future<List<AddOn>> fetchAddOns(String providerId) =>
      respond(MockServiceData.addOnsByProvider[providerId] ?? const []);

  @override
  Future<BookingAvailability> fetchAvailability(
    String providerId, {
    DateTime? date,
  }) =>
      respond(
        const BookingAvailability(
          slots: MockServiceData.slots,
          bookedSlots: MockServiceData.bookedSlots,
        ),
      );

  @override
  Future<ServiceRequest> createRequest(CreateServiceRequestDraft draft) async {
    final available = await fetchAddOns(draft.offering.provider.id);
    final selected =
        available.where((a) => draft.addOnIds.contains(a.id)).toList();

    final request = ServiceRequest(
      id: '${_nextRequestNumber++}',
      offering: draft.offering,
      car: draft.car,
      plate: draft.plate,
      fulfillment: draft.fulfillment,
      slot: draft.slot,
      addOns: selected,
      total: calculateRequestTotal(
        offering: draft.offering,
        addOns: selected,
        fulfillment: draft.fulfillment,
      ),
      status: RequestStatus.requested,
    );
    _requests.insert(0, request);
    return respond(request);
  }

  @override
  Future<List<ServiceRequest>> fetchRequests() =>
      respond(List<ServiceRequest>.unmodifiable(_requests));

  @override
  Future<ServiceRequest> updateRequestStatus(
    String requestId,
    RequestStatus status,
  ) {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) {
      throw NotFoundException('Service request $requestId not found');
    }
    final updated = _requests[index].copyWith(status: status);
    _requests[index] = updated;
    return respond(updated);
  }
}
