/// Relative REST paths for the AK Cars API.
///
/// Paths are relative to [AppConfig.apiBaseUrl] and never carry the host, so
/// switching environment is a config change only. They mirror the controllers
/// in `Backend/AKCarsApi` (Auth, Cars, Products, Orders, ServiceMarketplace,
/// Bookings, Payments) so Phase 2 wiring is a lookup, not a guess.
abstract final class ApiEndpoints {
  // ------------------------------------------------------------------ auth
  /// Looks up an account by phone or email and, when one exists, sends the
  /// OTP. Answers `404` for no match — the client reads that as "no account",
  /// not as a transport error.
  static const login = '/auth/login';

  /// Verifies the code sent by [login] and starts the session.
  static const loginVerify = '/auth/login/verify';
  static const register = '/auth/register';
  static const refreshToken = '/auth/refresh';
  static const logout = '/auth/logout';

  // ------------------------------------------------------------------ user
  static const profile = '/user/profile';
  static const updateProfile = '/user/profile';

  /// The signed-in user's saved cars ("garage").
  static const garage = '/user/vehicles';

  static String garageVehicle(String vehicleId) => '/user/vehicles/$vehicleId';

  static String primaryVehicle(String vehicleId) =>
      '${garageVehicle(vehicleId)}/primary';

  // -------------------------------------------------------- maintenance
  /// Every maintenance book, flattened — each entry carries its own `carId`.
  static const maintenanceBooks = '/user/vehicles/maintenance';

  static String vehicleMaintenance(String carId) =>
      '/user/vehicles/$carId/maintenance';

  static String maintenanceOdometer(String carId) =>
      '${vehicleMaintenance(carId)}/odometer';

  static String maintenanceRecords(String carId) =>
      '${vehicleMaintenance(carId)}/records';

  static String maintenanceRecord(String carId, String recordId) =>
      '${maintenanceRecords(carId)}/$recordId';

  static String maintenanceInterval(String carId, String itemKey) =>
      '${vehicleMaintenance(carId)}/intervals/$itemKey';

  static String maintenanceItems(String carId) =>
      '${vehicleMaintenance(carId)}/items';

  static String maintenanceItem(String carId, String itemId) =>
      '${maintenanceItems(carId)}/$itemId';

  // --------------------------------------------------------------- catalog
  /// Make/model catalog powering the car pickers.
  static const carCatalog = '/cars/catalog';

  /// Canonical vehicle-spec vocabulary (body types, fuels, colors, …).
  static const carSpecOptions = '/cars/spec-options';

  /// Sub-model (trim) options per model.
  static const carTrims = '/cars/trims';

  /// Oman governorates and their wilayats.
  static const locations = '/locations';

  // ------------------------------------------------------- cars marketplace
  static const carListings = '/cars';

  static String carListing(String listingId) => '/cars/$listingId';

  static String relatedCarListings(String listingId) =>
      '/cars/$listingId/related';

  /// Ads published by the signed-in user.
  static const myCarAds = '/cars/my-ads';

  static String myCarAd(String listingId) => '/cars/my-ads/$listingId';

  // ------------------------------------------------------ service marketplace
  static const serviceCategories = '/service-marketplace/categories';
  static const serviceProviders = '/service-marketplace/providers';
  static const serviceOfferings = '/service-marketplace/offerings';

  /// Live promoted offers — the home page's offers rail.
  static const servicePromotions = '/service-marketplace/promotions';

  /// Time-boxed workshop discounts on listed services. The server returns only
  /// founder-approved, in-window offers; the client validates them again
  /// against the catalogue before rendering.
  static const serviceOffers = '/service-marketplace/offers';

  /// Marketplace-wide booking counts per category, aggregated server-side.
  static const serviceCategoryDemand = '/service-marketplace/category-demand';

  /// Completed-booking counts per workshop, aggregated server-side.
  static const serviceWorkshopDemand = '/service-marketplace/workshop-demand';

  /// Customer ratings per workshop. Only rated workshops appear.
  static const serviceWorkshopRatings = '/service-marketplace/ratings';

  static String providerAddOns(String providerId) =>
      '/service-marketplace/providers/$providerId/add-ons';

  static String providerSlots(String providerId) =>
      '/service-marketplace/providers/$providerId/slots';

  static const serviceRequests = '/service-marketplace/requests';

  static String serviceRequest(String requestId) =>
      '/service-marketplace/requests/$requestId';

  static String serviceRequestStatus(String requestId) =>
      '/service-marketplace/requests/$requestId/status';

  /// "Request a part + installation" — a booking that starts without a price
  /// (spec §6). Same collection as [serviceRequests]; a separate path because
  /// the body is a part description rather than an offering id.
  static const partRequests = '/service-marketplace/part-requests';

  /// The workshop's itemised quote against a part request.
  static String requestQuote(String requestId) =>
      '/service-marketplace/requests/$requestId/quote';

  static String serviceOffering(String offeringId) =>
      '$serviceOfferings/$offeringId';

  static String serviceOffer(String offerId) => '$serviceOffers/$offerId';

  static String providerStage(String providerId) =>
      '$serviceProviders/$providerId/stage';

  static const workshopApplications = '/service-marketplace/applications';
  static const operatorRequests = '/service-marketplace/operator/requests';
  static const payouts = '/service-marketplace/payouts';
  static const auditLog = '/service-marketplace/audit';

  // ---------------------------------------------------------- my workshop
  // A workshop owner's own dashboard — nested under the resources they
  // belong to, same convention as `providerAddOns`/`providerSlots` above.
  // Every route resolves the caller's workshop from the JWT server-side;
  // none of these paths ever carry a providerId.
  static const myWorkshop = '/service-marketplace/my-workshop';
  static const myWorkshopSummary = '$myWorkshop/summary';

  static const myWorkshopOfferings = '$myWorkshop/offerings';

  static String myWorkshopOffering(String offeringId) =>
      '$myWorkshopOfferings/$offeringId';

  static String myWorkshopOfferingActive(String offeringId) =>
      '${myWorkshopOffering(offeringId)}/active';

  static const myWorkshopAddOns = '$myWorkshop/add-ons';

  static String myWorkshopAddOn(String addOnId) => '$myWorkshopAddOns/$addOnId';

  static const myWorkshopInventory = '$myWorkshop/inventory';
  static const myWorkshopLowStock = '$myWorkshopInventory/low-stock';

  static String myWorkshopInventoryItem(String itemId) =>
      '$myWorkshopInventory/$itemId';

  static String myWorkshopInventoryMovements(String itemId) =>
      '${myWorkshopInventoryItem(itemId)}/movements';

  static const myWorkshopStaff = '$myWorkshop/staff';

  static String myWorkshopStaffMember(String staffId) =>
      '$myWorkshopStaff/$staffId';

  static String myWorkshopAssignRequest(String requestId) =>
      '$myWorkshop/requests/$requestId/assign';

  static const myWorkshopRequests = '$myWorkshop/requests';

  static const myWorkshopCustomers = '$myWorkshop/customers';

  static String myWorkshopCustomer(String userId) =>
      '$myWorkshopCustomers/$userId';

  static String myWorkshopCustomerNotes(String userId) =>
      '${myWorkshopCustomer(userId)}/notes';

  static const myWorkshopSchedule = '$myWorkshop/schedule';
  static const myWorkshopEarnings = '$myWorkshop/earnings';
  static const myWorkshopMetrics = '$myWorkshop/metrics';

  // ------------------------------------------------------- admin workshop
  // The founder's CRUD over *any* workshop's profile and catalogue — the
  // target provider is always in the path, unlike `myWorkshop*` above.
  static const _adminProviders = '/service-marketplace/admin/providers';

  static String adminProvider(String providerId) =>
      '$_adminProviders/$providerId';

  static String adminProviderOfferings(String providerId) =>
      '${adminProvider(providerId)}/offerings';

  static String adminProviderOffering(String providerId, String offeringId) =>
      '${adminProviderOfferings(providerId)}/$offeringId';

  static String adminProviderOfferingActive(
    String providerId,
    String offeringId,
  ) => '${adminProviderOffering(providerId, offeringId)}/active';

  static String adminProviderAddOns(String providerId) =>
      '${adminProvider(providerId)}/add-ons';

  static String adminProviderAddOn(String providerId, String addOnId) =>
      '${adminProviderAddOns(providerId)}/$addOnId';

  // --------------------------------------------------------------- reviews
  /// Verified reviews. A `POST` here is only valid for a booking that reached
  /// `releasedToWorkshop`, and `(bookingId, direction)` must be unique — the
  /// server owns both rules; the client only mirrors them (spec §8).
  static const reviews = '/reviews';

  static String review(String reviewId) => '/reviews/$reviewId';

  static String providerReviews(String providerId) =>
      '/service-marketplace/providers/$providerId/reviews';

  // ------------------------------------------------------------------ shop
  static const partCategories = '/products/categories';
  static const products = '/products';

  static String product(String productId) => '/products/$productId';

  static const cart = '/cart';
  static const cartItems = '/cart/items';

  static String cartItem(String productId) => '/cart/items/$productId';

  // ---------------------------------------------------------------- orders
  static const orders = '/orders';

  static String order(String orderId) => '/orders/$orderId';

  /// Buyer confirms receipt, releasing escrow to the store.
  static String confirmOrderReceipt(String orderId) =>
      '/orders/$orderId/confirm-receipt';

  static const payments = '/payments';

  // --------------------------------------------------------- notifications
  static const notifications = '/notifications';
  static const markNotificationsRead = '/notifications/read';
  static const notificationDevices = '/notifications/devices';

  static String notificationDevice(String token) =>
      '/notifications/devices/${Uri.encodeComponent(token)}';

  // ------------------------------------------------------------------ chat
  /// `threadId` is a booking GUID **or** `provider:{providerId}` — encoded,
  /// because the colon must reach the server as `%3A`.
  static String chatThreadMessages(String threadId) =>
      '/chat/threads/${Uri.encodeComponent(threadId)}/messages';

  // ------------------------------------------------------------ challenges
  static const challengeBoard = '/challenges/board';
  static const completeCurrentChallenge = '/challenges/current/complete';

  static String toggleChallengeStep(String stepId) =>
      '/challenges/steps/$stepId/toggle';
}
