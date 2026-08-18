/// The offline world the widget tests render against.
///
/// This used to be `lib/data/datasources/mock/` plus a `Mock*` implementation
/// of every service, shipped inside the app and selected by a `DataSourceMode`
/// flag. It was removed from `lib/` on 2026-08-10: the app now binds the
/// `Api*` services and nothing else, so there is no build in which invented
/// data can reach a screen.
///
/// The tests still need a deterministic world — asserting that the operator
/// queue colours an overdue job cannot wait on a live SQL Server — so the same
/// doubles live here instead, and are injected by
/// [fakeServiceOverrides] rather than chosen by a flag the app can read.
library;

import 'package:ak_cars_mobil_app/data/services/garage_service.dart';
import 'package:ak_cars_mobil_app/data/services/maintenance_service.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_auth_service.dart';
import 'mock_cars_service.dart';
import 'mock_catalog_service.dart';
import 'mock_challenge_service.dart';
import 'mock_chat_service.dart';
import 'mock_notification_service.dart';
import 'mock_order_service.dart';
import 'mock_review_service.dart';
import 'mock_service_marketplace_service.dart';
import 'mock_shop_service.dart';
import 'mock_workshop_service.dart';
import 'memory_token_store.dart';
import 'offline_api_client.dart';

export 'mock_auth_service.dart';
export 'mock_cars_service.dart';
export 'mock_catalog_service.dart';
export 'mock_challenge_service.dart';
export 'mock_chat_service.dart';
export 'mock_notification_service.dart';
export 'mock_order_service.dart';
export 'mock_review_service.dart';
export 'mock_service_marketplace_service.dart';
export 'mock_shop_service.dart';
export 'mock_workshop_service.dart';
export 'memory_token_store.dart';
export 'offline_api_client.dart';

/// Binds every service provider to its test double.
///
/// Two choices here are worth stating, because the suite's behaviour depends
/// on both:
///
/// **The token store holds a session.** `AppBootstrap.warmUp` skips the
/// auth-gated warm-ups (challenges, the operator queue) when there is no
/// token, and a dozen screens read those repositories synchronously while
/// building. A signed-out harness renders them empty and the tests that check
/// their contents fail for a reason that has nothing to do with what they are
/// testing. The tokens are never sent anywhere — [OfflineApiClient] refuses
/// every request.
///
/// **The garage and its books are bound to the device stores directly**, not
/// to the `Session*` wrappers the app uses. With a session present the wrapper
/// would route them at the API, and these two are the one pair whose *storage*
/// is the thing under test (`garage_persistence_test`). The wrapper's own
/// routing rule has its own test — `guest_garage_test` — built on purpose-made
/// fakes rather than on this harness.
List<Override> fakeServiceOverrides(SharedPreferences prefs) => [
  sharedPrefsProvider.overrideWithValue(prefs),
  // Before anything else: the real store never answers under
  // `flutter_tester` and hangs every warm-up. See [MemoryTokenStore].
  tokenStoreProvider.overrideWithValue(
    MemoryTokenStore(access: 'test-access', refresh: 'test-refresh'),
  ),
  // The floor under everything else. Any service not doubled below would
  // otherwise get a live `DioApiClient` pointed at localhost:7291 and open
  // real sockets from `flutter_tester` — see [OfflineApiClient].
  apiClientProvider.overrideWithValue(const OfflineApiClient()),
  pushServiceProvider.overrideWithValue(const SilentPushService()),
  catalogServiceProvider.overrideWithValue(MockCatalogService()),
  authServiceProvider.overrideWithValue(MockAuthService(prefs: prefs)),
  serviceMarketplaceServiceProvider.overrideWithValue(
    MockServiceMarketplaceService(),
  ),
  shopServiceProvider.overrideWithValue(MockShopService()),
  carsServiceProvider.overrideWithValue(MockCarsService()),
  orderServiceProvider.overrideWithValue(MockOrderService()),
  notificationServiceProvider.overrideWithValue(MockNotificationService()),
  chatServiceProvider.overrideWithValue(MockChatService()),
  challengeServiceProvider.overrideWithValue(MockChallengeService()),
  reviewServiceProvider.overrideWithValue(MockReviewService()),
  garageServiceProvider.overrideWithValue(LocalGarageStore(prefs: prefs)),
  maintenanceServiceProvider.overrideWithValue(
    LocalMaintenanceStore(prefs: prefs),
  ),
  workshopServiceProvider.overrideWithValue(MockWorkshopService()),
];
