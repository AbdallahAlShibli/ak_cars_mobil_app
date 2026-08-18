/// Composition root.
///
/// This is the *only* file that names a concrete service implementation.
///
/// **Every binding here is the REST one.** The app used to carry a complete
/// offline data layer beside it and choose between them on a `DataSourceMode`;
/// the demo world was removed from `lib/` on 2026-08-10 and now lives only in
/// `test/fakes/`, which the widget tests inject through
/// `test/helpers/test_harness.dart`. There is no longer any path by which a
/// build can serve invented data: a bad host produces a `NetworkException`
/// naming the URL, which is what we want it to do.
///
/// The two exceptions are [garageServiceProvider] and
/// [maintenanceServiceProvider], and they are not a fallback — see their own
/// comments and [SessionGarageService].
///
/// Repositories, state and every screen are written against the interfaces and
/// stayed untouched through all of it, which is the point.
///
/// Nothing outside this file constructs a service or repository, and no
/// widget ever instantiates one.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/chat_hub.dart';
import '../core/network/dio_api_client.dart';
import '../core/push/push_service.dart';
import '../data/services/api/api_admin_workshop_service.dart';
import '../data/services/api/api_auth_service.dart';
import '../data/services/api/api_cars_service.dart';
import '../data/services/api/api_catalog_service.dart';
import '../data/services/api/api_challenge_service.dart';
import '../data/services/api/api_chat_service.dart';
import '../data/services/api/api_garage_service.dart';
import '../data/services/api/api_maintenance_service.dart';
import '../data/services/api/api_notification_service.dart';
import '../data/services/api/api_order_service.dart';
import '../data/services/api/api_review_service.dart';
import '../data/services/api/api_service_marketplace_service.dart';
import '../data/services/api/api_shop_service.dart';
import '../data/services/api/api_workshop_service.dart';
import '../data/services/token_store.dart';
import '../data/repositories/admin_workshop_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/cars_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/challenge_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/garage_repository.dart';
import '../data/repositories/maintenance_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/repositories/review_repository.dart';
import '../data/repositories/service_marketplace_repository.dart';
import '../data/repositories/shop_repository.dart';
import '../data/repositories/workshop_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/cars_service.dart';
import '../data/services/catalog_service.dart';
import '../data/services/challenge_service.dart';
import '../data/services/chat_service.dart';
import '../data/services/garage_service.dart';
import '../data/services/maintenance_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/order_service.dart';
import '../data/services/review_service.dart';
import '../data/services/service_marketplace_service.dart';
import '../data/services/session_routed_services.dart';
import '../data/services/shop_service.dart';
import '../data/services/admin_workshop_service.dart';
import '../data/services/workshop_service.dart';

// ---------------------------------------------------------------- platform

/// Injected in `main()` once SharedPreferences has loaded.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

/// Runtime configuration for the environment this binary was built for.
/// Override in tests to point at a different environment or add mock latency.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.current());

/// Where the session's access/refresh tokens live — the platform
/// keychain/keystore, never `SharedPreferences`.
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// FCM device registration and the data-only message bridge. A no-op until
/// the native Firebase config is added — see [PushService]'s doc comment.
final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(ref.watch(apiClientProvider)),
);

/// The SignalR connection backing live chat delivery — a single connection
/// shared by every open thread. Only constructed when the API path is bound;
/// nothing touches it on the mock path.
final chatHubProvider = Provider<ChatHub>(
  (ref) => ChatHub(
    config: ref.watch(appConfigProvider),
    tokens: ref.watch(tokenStoreProvider),
  ),
);

/// The HTTP transport every `Api*` service is written against.
///
/// [DioApiClient] against [AppConfig.apiBaseUrl], always. A call that cannot
/// reach the host throws a [NetworkException] naming the base URL, which is
/// the whole point of having no second data source to fall back to.
final apiClientProvider = Provider<ApiClient>(
  (ref) => DioApiClient(
    config: ref.watch(appConfigProvider),
    tokens: ref.watch(tokenStoreProvider),
  ),
);

// ------------------------------------------------------- warm-cache notices

/// How a repository tells the app that the caches *inside* it were refilled.
///
/// The problem it solves: reference data is fetched once and then read
/// synchronously by screens that have no loading state to render, so every
/// repository below keeps its answers in `WarmCache` fields. Riverpod compares
/// a provider's value by identity, and a repository that refills its own cache
/// is the same object it always was — so nothing watching
/// `carsRepositoryProvider` is ever told that `listings` now answers
/// differently, and a screen opened before a refresh goes on showing the world
/// as it was when it opened. That is not hypothetical: it is what made signing
/// in leave the home page, the shop, the services tab and the founder panels on
/// the guest's copy of the data.
///
/// The obvious fix — invalidating the repository providers — would announce the
/// change and also throw the caches away, blanking every one of those screens
/// until the network answered. `Ref.notifyListeners` is Riverpod's own answer
/// for exactly this shape ("typically used for mutable state"): it tells a
/// provider's dependents to read again *without* rebuilding the provider. It
/// can only be called on that provider's own `ref`, which nothing outside its
/// body holds — hence this register.
///
/// The payoff is that no call site has to remember anything. Every
/// `ref.watch(…RepositoryProvider)` in the app — the ~20 providers in
/// `lib/state/` and the ~15 widgets that read the marketplace directly —
/// repaints from one [announce], and a new one written tomorrow does too.
class WarmCacheNotice {
  final _refs = <Ref>[];

  /// Called by a repository provider as it builds. The ref unregisters itself
  /// on dispose, so a container that is torn down and replaced — a hot restart,
  /// the next test — never announces through a dead one.
  void register(Ref ref) {
    _refs.add(ref);
    ref.onDispose(() => _refs.remove(ref));
  }

  /// Tells every registered repository's dependents to read again.
  ///
  /// Call it *after* the caches have been refilled and never from inside a
  /// provider's build — Riverpod forbids one provider mutating another during
  /// initialization, and there would be nothing new to read yet anyway.
  /// [SessionRefresh] is the only caller.
  void announce() {
    // Copied first: a listener rebuilding could dispose a provider and so
    // mutate this list while it is being walked.
    for (final ref in [..._refs]) {
      ref.notifyListeners();
    }
  }
}

final warmCacheNoticeProvider = Provider<WarmCacheNotice>(
  (ref) => WarmCacheNotice(),
);

// ----------------------------------------------------------------- services

final catalogServiceProvider = Provider<CatalogService>(
  (ref) => ApiCatalogService(ref.watch(apiClientProvider)),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => ApiAuthService(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
    ref.watch(pushServiceProvider),
  ),
);

// Not a bare `ApiGarageService`: a guest is invited to register a car as step
// 3 of 3 of first launch, long before the registration gate, and
// `/user/vehicles` is `[Authorize]`d. [LocalGarageStore] is the device's own
// copy for that window — not a mock, and not a fallback for a failed request.
// See [SessionGarageService] for the whole argument: it keeps a guest's cars
// on the device and hands them to the server at sign-in.
final garageServiceProvider = Provider<GarageService>((ref) {
  final local = LocalGarageStore(prefs: ref.watch(sharedPrefsProvider));
  final remote = ApiGarageService(ref.watch(apiClientProvider));
  return SessionGarageService(local, remote, ref.watch(tokenStoreProvider));
});

final serviceMarketplaceServiceProvider = Provider<ServiceMarketplaceService>(
  (ref) => ApiServiceMarketplaceService(ref.watch(apiClientProvider)),
);

final shopServiceProvider = Provider<ShopService>(
  (ref) => ApiShopService(ref.watch(apiClientProvider)),
);

final carsServiceProvider = Provider<CarsService>(
  (ref) => ApiCarsService(ref.watch(apiClientProvider)),
);

final orderServiceProvider = Provider<OrderService>(
  (ref) => ApiOrderService(ref.watch(apiClientProvider)),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => ApiNotificationService(ref.watch(apiClientProvider)),
);

final chatServiceProvider = Provider<ChatService>(
  (ref) =>
      ApiChatService(ref.watch(apiClientProvider), ref.watch(chatHubProvider)),
);

// Same guest rule as the garage: a book belongs to a car, and a guest is
// allowed to have a car. See [SessionMaintenanceService].
final maintenanceServiceProvider = Provider<MaintenanceService>((ref) {
  final local = LocalMaintenanceStore(prefs: ref.watch(sharedPrefsProvider));
  final remote = ApiMaintenanceService(ref.watch(apiClientProvider));
  return SessionMaintenanceService(
    local,
    remote,
    ref.watch(tokenStoreProvider),
  );
});

/// The datasets a guest may have built on this device, in the order they have
/// to be handed to the server: vehicles before the maintenance books that are
/// filed against them.
final guestDataAdoptersProvider = Provider<List<GuestDataAdopter>>(
  (ref) => [
    ref.watch(garageServiceProvider),
    ref.watch(maintenanceServiceProvider),
  ].whereType<GuestDataAdopter>().toList(growable: false),
);

final challengeServiceProvider = Provider<ChallengeService>(
  (ref) => ApiChallengeService(ref.watch(apiClientProvider)),
);

final reviewServiceProvider = Provider<ReviewService>(
  (ref) => ApiReviewService(ref.watch(apiClientProvider)),
);

final workshopServiceProvider = Provider<WorkshopService>(
  (ref) => ApiWorkshopService(ref.watch(apiClientProvider)),
);

final adminWorkshopServiceProvider = Provider<AdminWorkshopService>(
  (ref) => ApiAdminWorkshopService(ref.watch(apiClientProvider)),
);

// ------------------------------------------------------------- repositories

/// The seven repositories below hold `WarmCache` fields that screens read
/// synchronously, so each registers with [WarmCacheNotice] — see that class for
/// why a refilled cache is otherwise invisible to everything watching it. The
/// ones that are not registered (auth, orders, notifications, chat, reviews)
/// have no such cache: every read they serve is a fresh `Future`, so there is
/// nothing to announce.

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  ref.read(warmCacheNoticeProvider).register(ref);
  return CatalogRepositoryImpl(ref.watch(catalogServiceProvider));
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authServiceProvider)),
);

final garageRepositoryProvider = Provider<GarageRepository>((ref) {
  ref.read(warmCacheNoticeProvider).register(ref);
  return GarageRepositoryImpl(ref.watch(garageServiceProvider));
});

final serviceMarketplaceRepositoryProvider =
    Provider<ServiceMarketplaceRepository>((ref) {
      ref.read(warmCacheNoticeProvider).register(ref);
      return ServiceMarketplaceRepositoryImpl(
        ref.watch(serviceMarketplaceServiceProvider),
        config: ref.watch(appConfigProvider),
      );
    });

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  ref.read(warmCacheNoticeProvider).register(ref);
  return ShopRepositoryImpl(ref.watch(shopServiceProvider));
});

final carsRepositoryProvider = Provider<CarsRepository>((ref) {
  ref.read(warmCacheNoticeProvider).register(ref);
  return CarsRepositoryImpl(ref.watch(carsServiceProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepositoryImpl(ref.watch(orderServiceProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(
    ref.watch(notificationServiceProvider),
    config: ref.watch(appConfigProvider),
  ),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(ref.watch(chatServiceProvider)),
);

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  ref.read(warmCacheNoticeProvider).register(ref);
  return MaintenanceRepositoryImpl(ref.watch(maintenanceServiceProvider));
});

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  ref.read(warmCacheNoticeProvider).register(ref);
  return ChallengeRepositoryImpl(ref.watch(challengeServiceProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepositoryImpl(ref.watch(reviewServiceProvider)),
);

final workshopRepositoryProvider = Provider<WorkshopRepository>((ref) {
  ref.read(warmCacheNoticeProvider).register(ref);
  return WorkshopRepositoryImpl(
    ref.watch(workshopServiceProvider),
    ref.watch(serviceMarketplaceServiceProvider),
  );
});

// No WarmCacheNotice registration — unlike the repositories above,
// AdminWorkshopRepositoryImpl holds no cache to refill. It is an
// occasionally-opened founder screen for one workshop at a time, not a hot
// path every screen reads from.
final adminWorkshopRepositoryProvider = Provider<AdminWorkshopRepository>(
  (ref) => AdminWorkshopRepositoryImpl(ref.watch(adminWorkshopServiceProvider)),
);
