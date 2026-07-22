/// Relative REST paths for the AK Cars API.
///
/// Paths are relative to [AppConfig.apiBaseUrl] and never carry the host, so
/// switching environment is a config change only. They mirror the controllers
/// in `Backend/AKCarsApi` (Auth, Cars, Products, Orders, ServiceMarketplace,
/// Bookings, Payments) so Phase 2 wiring is a lookup, not a guess.
abstract final class ApiEndpoints {
  // ------------------------------------------------------------------ auth
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const refreshToken = '/auth/refresh';
  static const logout = '/auth/logout';

  // ------------------------------------------------------------------ user
  static const profile = '/user/profile';
  static const updateProfile = '/user/profile';

  /// The signed-in user's saved cars ("garage").
  static const garage = '/user/vehicles';

  static String garageVehicle(String vehicleId) => '/user/vehicles/$vehicleId';

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

  static String providerAddOns(String providerId) =>
      '/service-marketplace/providers/$providerId/add-ons';

  static String providerSlots(String providerId) =>
      '/service-marketplace/providers/$providerId/slots';

  static const serviceRequests = '/service-marketplace/requests';

  static String serviceRequest(String requestId) =>
      '/service-marketplace/requests/$requestId';

  static String serviceRequestStatus(String requestId) =>
      '/service-marketplace/requests/$requestId/status';

  static String serviceRequestApproval(String requestId) =>
      '/service-marketplace/requests/$requestId/approve';

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

  // ------------------------------------------------------------------ chat
  static String requestChat(String requestId) => '/chat/requests/$requestId';

  // ---------------------------------------------------- garage maintenance
  static const maintenance = '/maintenance';
  static const maintenanceRecords = '/maintenance/records';
  static const maintenanceOdometer = '/maintenance/odometer';
  static const maintenanceIntervals = '/maintenance/intervals';

  // ------------------------------------------------------------ challenges
  static const challenges = '/challenges';
  static const currentChallenge = '/challenges/current';

  static String completeChallenge(String challengeId) =>
      '/challenges/$challengeId/complete';
}
