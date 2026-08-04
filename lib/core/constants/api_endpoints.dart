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

  static String serviceRequestApproval(String requestId) =>
      '/service-marketplace/requests/$requestId/approve';

  /// "Request a part + installation" — a booking that starts without a price
  /// (spec §6). Same collection as [serviceRequests]; a separate path because
  /// the body is a part description rather than an offering id.
  static const partRequests = '/service-marketplace/part-requests';

  /// The workshop's itemised quote against a part request.
  static String requestQuote(String requestId) =>
      '/service-marketplace/requests/$requestId/quote';

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
