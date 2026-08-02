/// Composition root.
///
/// This is the *only* file that names a concrete service implementation.
///
/// Phase 2.5 (§12) finished the job the original note here described: every
/// core service now has an `Api*` implementation beside its `Mock*` one, and
/// each binding picks between them on [AppConfig.dataSource]. Switching the
/// whole app over is a `--dart-define=AK_DATA_SOURCE=api` away, and it fails
/// loudly rather than silently falling back — see [apiClientProvider].
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
import '../core/network/unconfigured_api_client.dart';
import '../data/services/api/api_auth_service.dart';
import '../data/services/api/api_garage_service.dart';
import '../data/services/api/api_maintenance_service.dart';
import '../data/services/api/api_review_service.dart';
import '../data/services/api/api_service_marketplace_service.dart';
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
import '../data/services/shop_service.dart';

// ---------------------------------------------------------------- platform

/// Injected in `main()` once SharedPreferences has loaded.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

/// Runtime configuration for the environment this binary was built for.
/// Override in tests to point at a different environment or add mock latency.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.current());

/// The HTTP transport every `Api*` service is written against.
///
/// Bound to [UnconfiguredApiClient] in this build, which throws a
/// [NetworkException] naming the base URL on any call. That is the §12
/// acceptance behaviour: `AK_DATA_SOURCE=api` boots, and the first request
/// fails with something a reader can act on rather than the app quietly
/// serving demo data and looking healthy.
///
/// Phase 2 swaps this one line for a real adapter. Nothing else moves.
final apiClientProvider = Provider<ApiClient>(
  (ref) => UnconfiguredApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
  ),
);

/// True when the bindings below should resolve to the REST implementations.
bool _useApi(Ref ref) =>
    ref.watch(appConfigProvider).dataSource == DataSourceMode.api;

// ----------------------------------------------------------------- services

final catalogServiceProvider = Provider<CatalogService>(
  (ref) => MockCatalogService(config: ref.watch(appConfigProvider)),
);

// Takes prefs because the mock stands in for the session store too: the
// registered profile has to survive a cold start.
final authServiceProvider = Provider<AuthService>(
  (ref) => _useApi(ref)
      ? ApiAuthService(ref.watch(apiClientProvider))
      : MockAuthService(
          config: ref.watch(appConfigProvider),
          prefs: ref.watch(sharedPrefsProvider),
        ),
);

// Takes prefs for the same reason auth does: the mock stands in for the
// server's storage too, and a car the user registered has to survive a cold
// start.
final garageServiceProvider = Provider<GarageService>(
  (ref) => _useApi(ref)
      ? ApiGarageService(ref.watch(apiClientProvider))
      : MockGarageService(
          config: ref.watch(appConfigProvider),
          prefs: ref.watch(sharedPrefsProvider),
        ),
);

final serviceMarketplaceServiceProvider = Provider<ServiceMarketplaceService>(
  (ref) => _useApi(ref)
      ? ApiServiceMarketplaceService(ref.watch(apiClientProvider))
      : MockServiceMarketplaceService(config: ref.watch(appConfigProvider)),
);

final shopServiceProvider = Provider<ShopService>(
  (ref) => MockShopService(config: ref.watch(appConfigProvider)),
);

final carsServiceProvider = Provider<CarsService>(
  (ref) => MockCarsService(config: ref.watch(appConfigProvider)),
);

final orderServiceProvider = Provider<OrderService>(
  (ref) => MockOrderService(config: ref.watch(appConfigProvider)),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => MockNotificationService(config: ref.watch(appConfigProvider)),
);

final chatServiceProvider = Provider<ChatService>(
  (ref) => MockChatService(config: ref.watch(appConfigProvider)),
);

final maintenanceServiceProvider = Provider<MaintenanceService>(
  (ref) => _useApi(ref)
      ? ApiMaintenanceService(ref.watch(apiClientProvider))
      : MockMaintenanceService(
          config: ref.watch(appConfigProvider),
          prefs: ref.watch(sharedPrefsProvider),
        ),
);

final challengeServiceProvider = Provider<ChallengeService>(
  (ref) => MockChallengeService(config: ref.watch(appConfigProvider)),
);

final reviewServiceProvider = Provider<ReviewService>(
  (ref) => _useApi(ref)
      ? ApiReviewService(ref.watch(apiClientProvider))
      : MockReviewService(config: ref.watch(appConfigProvider)),
);

// ------------------------------------------------------------- repositories

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(ref.watch(catalogServiceProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authServiceProvider)),
);

final garageRepositoryProvider = Provider<GarageRepository>(
  (ref) => GarageRepositoryImpl(ref.watch(garageServiceProvider)),
);

final serviceMarketplaceRepositoryProvider =
    Provider<ServiceMarketplaceRepository>(
      (ref) => ServiceMarketplaceRepositoryImpl(
        ref.watch(serviceMarketplaceServiceProvider),
        config: ref.watch(appConfigProvider),
      ),
    );

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => ShopRepositoryImpl(ref.watch(shopServiceProvider)),
);

final carsRepositoryProvider = Provider<CarsRepository>(
  (ref) => CarsRepositoryImpl(ref.watch(carsServiceProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepositoryImpl(ref.watch(orderServiceProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(ref.watch(notificationServiceProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(ref.watch(chatServiceProvider)),
);

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepositoryImpl(ref.watch(maintenanceServiceProvider)),
);

final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepositoryImpl(ref.watch(challengeServiceProvider)),
);

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepositoryImpl(ref.watch(reviewServiceProvider)),
);
