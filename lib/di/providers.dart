/// Composition root.
///
/// This is the *only* file that names a concrete service implementation.
/// Phase 2 (real backend) is a change here and nowhere else: add the REST
/// implementations, then make each `*ServiceProvider` return
/// `config.useMockData ? Mock…(…) : Rest…(apiClient: …)`. Repositories, state
/// and every screen are written against the interfaces and stay untouched.
///
/// Nothing outside this file constructs a service or repository, and no
/// widget ever instantiates one.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/cars_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/challenge_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/garage_repository.dart';
import '../data/repositories/maintenance_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/order_repository.dart';
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

// ----------------------------------------------------------------- services

final catalogServiceProvider = Provider<CatalogService>(
  (ref) => MockCatalogService(config: ref.watch(appConfigProvider)),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => MockAuthService(config: ref.watch(appConfigProvider)),
);

final garageServiceProvider = Provider<GarageService>(
  (ref) => MockGarageService(config: ref.watch(appConfigProvider)),
);

final serviceMarketplaceServiceProvider = Provider<ServiceMarketplaceService>(
  (ref) => MockServiceMarketplaceService(config: ref.watch(appConfigProvider)),
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
  (ref) => MockMaintenanceService(config: ref.watch(appConfigProvider)),
);

final challengeServiceProvider = Provider<ChallengeService>(
  (ref) => MockChallengeService(config: ref.watch(appConfigProvider)),
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
