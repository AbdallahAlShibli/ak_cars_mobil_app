import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/data/services/auth_service.dart';
import 'package:ak_cars_mobil_app/data/services/cars_service.dart';
import 'package:ak_cars_mobil_app/data/services/garage_service.dart';
import 'package:ak_cars_mobil_app/data/services/session_routed_services.dart';
import 'package:ak_cars_mobil_app/data/services/token_store.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:ak_cars_mobil_app/state/provider_dashboard_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fakes.dart';
import 'fakes/data/mock_service_data.dart';
import 'fakes/data/mock_shop_data.dart';
import 'helpers/test_harness.dart';

/// **Signing in re-reads the whole app, not only the account's own corner of
/// it.**
///
/// The bug these cover: a guest browses, the app warms every catalogue for
/// them, and then they sign in — at which point four warm-ups ran and nothing
/// else did. The home page, the shop, the services tab and the founder panels
/// went on rendering the copy of the world that was fetched before anyone was
/// signed in, and the bookings, orders and reviews that belong to the account
/// were never asked for at all.
const _profile = UserProfile(
  name: 'Salim Al Hinai',
  phone: '+968 92001234',
  email: 'salim@example.om',
  region: 'Muscat',
  address: 'Al Khuwair',
);

/// Registers, then signs out — leaving an account on the "server" that
/// [_signIn] can log back into, and a guest holding the phone.
Future<void> _createAccountThenSignOut(ProviderContainer container) async {
  await container.read(authProvider.notifier).register(_profile);
  await _settle();
  await container.read(authProvider.notifier).signOut();
}

Future<void> _signIn(ProviderContainer container) async {
  await container.read(authProvider.notifier).login(_profile.phone, '0000');
  await _settle();
}

/// The refresh is deliberately fire-and-forget — the auth screen pops the
/// moment the session is committed, and must not wait on it — so a test has to
/// let the event queue drain before asserting on its results.
Future<void> _settle() => pumpEventQueue(times: 40);

void main() {
  group('signing in refreshes the whole app', () {
    test('a platform catalogue that moved while browsing is re-read', () async {
      final marketplace = MockServiceMarketplaceService();
      final container = await createDataContainer(
        overrides: [
          serviceMarketplaceServiceProvider.overrideWithValue(marketplace),
        ],
      );
      await _createAccountThenSignOut(container);

      // Someone else — the founder, on another device — suspends a workshop.
      // The repository's warm cache still holds the roster as it was when this
      // app started, which is the whole point of the setup.
      final target = container
          .read(shopSellersProvider)
          .firstWhere((p) => p.isApproved);
      await marketplace.setProviderStage(
        target.id,
        ProviderOnboardingStage.suspended,
        reason: 'قيد المراجعة',
      );
      expect(
        container.read(shopSellersProvider).firstWhere((p) => p.id == target.id).stage,
        isNot(ProviderOnboardingStage.suspended),
        reason: 'nothing has refreshed yet, so the cache must still be stale',
      );

      await _signIn(container);

      // Refilled *and* announced: `shopSellersProvider` reads the warm cache
      // synchronously and holds no revision of its own, so seeing the new stage
      // proves both halves of the mechanism.
      expect(
        container.read(shopSellersProvider).firstWhere((p) => p.id == target.id).stage,
        ProviderOnboardingStage.suspended,
      );
    });

    test('the account\'s own bookings and orders arrive', () async {
      final marketplace = MockServiceMarketplaceService();
      final orders = MockOrderService();
      final container = await createDataContainer(
        overrides: [
          serviceMarketplaceServiceProvider.overrideWithValue(marketplace),
          orderServiceProvider.overrideWithValue(orders),
        ],
      );
      await _createAccountThenSignOut(container);

      // Placed on the account before this session existed — on another device,
      // or simply the last time the app was open. Written straight to the
      // service, so neither notifier has ever seen them.
      final booking = await marketplace.createRequest(
        CreateServiceRequestDraft(
          offering: MockServiceData.offerings.first,
          car: const Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019),
          plate: '1234 AB',
          fulfillment: Fulfillment.workshop,
          slot: 'Mon 3 Aug · 10:30',
          addOnIds: const {},
        ),
      );
      final order = await orders.placeOrder([
        OrderItem(product: MockShopData.products.first, qty: 1),
      ]);

      expect(container.read(requestsProvider), isEmpty);
      expect(container.read(ordersProvider), isEmpty);

      await _signIn(container);

      expect(
        container.read(requestsProvider).map((r) => r.id),
        contains(booking.id),
      );
      expect(container.read(ordersProvider).map((o) => o.id), contains(order.id));
    });

    test('a warm-up that fails leaves the user signed in', () async {
      final cars = _FailsAfterFirstCall(MockCarsService());
      final container = await createDataContainer(
        overrides: [carsServiceProvider.overrideWithValue(cars)],
      );
      await _createAccountThenSignOut(container);

      // The boot warm-up used its one good answer; every call the refresh makes
      // now throws.
      await _signIn(container);

      expect(
        container.read(authProvider).isRegistered,
        isTrue,
        reason: 'the session is committed before the refresh runs, and a '
            'failed refresh must never take it back',
      );
      expect(
        cars.listingFetches,
        greaterThan(1),
        reason: 'the public feeds are re-read at sign-in too, not just the '
            'auth-gated ones',
      );
      // The feed keeps what it had rather than emptying — `WarmCache` only
      // assigns once a fetch returns.
      expect(container.read(platformListingsProvider), isNotEmpty);
    });
  });

  group('signing out clears the whole app', () {
    test('the account\'s own bookings and orders are dropped, not left '
        'stale for whoever uses the app next', () async {
      final marketplace = MockServiceMarketplaceService();
      final orders = MockOrderService();
      final container = await createDataContainer(
        overrides: [
          serviceMarketplaceServiceProvider.overrideWithValue(marketplace),
          orderServiceProvider.overrideWithValue(orders),
        ],
      );
      await _createAccountThenSignOut(container);
      await _signIn(container);

      final booking = await marketplace.createRequest(
        CreateServiceRequestDraft(
          offering: MockServiceData.offerings.first,
          car: const Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019),
          plate: '1234 AB',
          fulfillment: Fulfillment.workshop,
          slot: 'Mon 3 Aug · 10:30',
          addOnIds: const {},
        ),
      );
      final order = await orders.placeOrder([
        OrderItem(product: MockShopData.products.first, qty: 1),
      ]);
      await container.read(requestsProvider.notifier).load();
      await container.read(ordersProvider.notifier).load();
      expect(
        container.read(requestsProvider).map((r) => r.id),
        contains(booking.id),
      );
      expect(container.read(ordersProvider).map((o) => o.id), contains(order.id));

      await container.read(authProvider.notifier).signOut();
      await _settle();

      // Not "still showing the previous account's list a moment longer" —
      // gone, the same way a fresh guest's would be. Nobody is signed in to
      // fetch a replacement for, so the lists go back to their `build()`
      // default rather than being reloaded.
      expect(container.read(requestsProvider), isEmpty);
      expect(container.read(ordersProvider), isEmpty);
    });

    test('the founder ledger is not left in the service marketplace cache '
        'for the next person to use this device', () async {
      final marketplace = MockServiceMarketplaceService();
      final container = await createDataContainer(
        overrides: [
          serviceMarketplaceServiceProvider.overrideWithValue(marketplace),
        ],
      );
      await _createAccountThenSignOut(container);
      await _signIn(container);
      // `warmUp(includeFounderLedger: true)` ran at that sign-in — the fake
      // does not check whether this account is really a founder (the real
      // API's `403` does that), so the call itself going out is what proves
      // sign-in asks.
      final afterSignIn = marketplace.fetchPayoutsCallCount;
      expect(afterSignIn, greaterThan(0));

      await container.read(authProvider.notifier).signOut();
      await _settle();

      // Sign-out's re-warm must not have asked again — `includeFounderLedger:
      // false` this time — leaving the count exactly where sign-in left it.
      expect(marketplace.fetchPayoutsCallCount, afterSignIn);
    });

    test('the workshop dashboard is not left showing the departed owner\'s '
        'data for whoever signs in next on this device', () async {
      final providerA = MockServiceData.providers[0];
      final providerB = MockServiceData.providers[1];
      final workshop = MockWorkshopService(provider: providerA);
      final container = await createDataContainer(
        overrides: [workshopServiceProvider.overrideWithValue(workshop)],
      );
      await _createAccountThenSignOut(container);
      await _signIn(container);

      // Opening the dashboard once, as this account, is what puts the
      // `AsyncNotifierProvider` in the "has an answer" state that used to
      // survive a sign-out untouched.
      expect(
        (await container.read(myWorkshopProfileProvider.future)).id,
        providerA.id,
      );

      // A second owner signing in on the same device: the real API would
      // resolve their JWT to a *different* workshop without the client
      // asking for anything different — the fake stands in for that by
      // simply answering with a different workshop from here on.
      workshop.provider = providerB;

      await container.read(authProvider.notifier).signOut();
      await _settle();

      // A provider that was never invalidated would still answer from its
      // already-resolved `AsyncData` — `providerA`, stale — rather than
      // asking the service again. This is exactly how a second owner
      // signing in on the same phone used to see the first owner's
      // offerings, inventory, staff and profile before ever making a
      // request of their own.
      expect(
        (await container.read(myWorkshopProfileProvider.future)).id,
        providerB.id,
      );
    });

    test('a plain customer who never opens the workshop dashboard causes '
        'no /my-workshop/* requests at all, on sign-in or sign-out',
        () async {
      final workshop = MockWorkshopService();
      final container = await createDataContainer(
        overrides: [workshopServiceProvider.overrideWithValue(workshop)],
      );

      // Never touches `myWorkshopProfileProvider`/`workshopSummaryProvider`/
      // etc. — this is an ordinary customer session, the common case.
      await _createAccountThenSignOut(container);
      await _signIn(container);
      await container.read(authProvider.notifier).signOut();
      await _settle();

      // A bare `ref.invalidate(provider)` on a provider that was never
      // built used to cause exactly this: Riverpod's own debug-mode
      // circular-dependency assertion initializes the target to check it,
      // which for an `AsyncNotifierProvider` means actually running its
      // `build()` — a real request — purely so the assertion has something
      // to inspect before discarding it. `SessionRefresh._ifBuilt` guards
      // against that with `Ref.exists`, which performs the same check
      // without ever creating an element.
      expect(workshop.callCount, 0);
    });

    test('the operator queue\'s marketplace-wide bookings are dropped too, '
        'not only this account\'s own', () async {
      final marketplace = MockServiceMarketplaceService();
      final container = await createDataContainer(
        overrides: [
          serviceMarketplaceServiceProvider.overrideWithValue(marketplace),
        ],
      );
      await _createAccountThenSignOut(container);
      await _signIn(container);

      // Somebody else's booking — never this account's own — which only
      // `operatorQueueProvider.refresh()` (run as part of sign-in's
      // `loadSessionLists`) could have put in the queue.
      final somebodyElses = await marketplace.createRequest(
        CreateServiceRequestDraft(
          offering: MockServiceData.offerings.first,
          car: const Car(id: 'c9', make: 'Toyota', model: 'Yaris', year: 2021),
          plate: '9999 CD',
          fulfillment: Fulfillment.workshop,
          slot: 'Tue 4 Aug · 11:00',
          addOnIds: const {},
        ),
      );
      await container.read(operatorQueueProvider.notifier).refresh();
      expect(
        container.read(operatorQueueProvider).map((r) => r.id),
        contains(somebodyElses.id),
      );

      await container.read(authProvider.notifier).signOut();
      await _settle();

      // `build()` re-running because `requestsProvider` cleared is not
      // enough — the marketplace-wide half lives in a plain field on the
      // notifier that only an explicit `clear()` resets.
      expect(container.read(operatorQueueProvider), isEmpty);
    });

    test('the account\'s notifications are dropped, not left in the inbox '
        'for whoever uses the app next', () async {
      final container = await createDataContainer();
      await _createAccountThenSignOut(container);
      await _signIn(container);

      await container.read(notificationServiceProvider).push(
            title: const L('إشعار', 'A notification'),
            body: const L('نص', 'Body'),
          );
      await container.read(notificationsProvider.notifier).load();
      expect(container.read(notificationsProvider), isNotEmpty);

      await container.read(authProvider.notifier).signOut();
      await _settle();

      expect(container.read(notificationsProvider), isEmpty);
    });

    test('a signed-in account\'s garage is not shown to the guest left '
        'holding the device', () async {
      final local = _FakeGarage();
      final remote = _FakeGarage();
      final container = await createDataContainer(overrides: [
        garageServiceProvider.overrideWith(
          (ref) =>
              SessionGarageService(local, remote, ref.watch(tokenStoreProvider)),
        ),
        // `MockAuthService` deliberately does not touch `TokenStore` — per
        // `AuthService`'s own doc comment, "the token handling lands with the
        // REST implementation", so the fake correctly leaves it out. But
        // `SessionGarageService` routes on `TokenStore.hasSession()`, which
        // only the *real* `ApiAuthService.signOut()` clears — so this test
        // needs that one extra side effect layered on top of the fake to
        // mean anything about the production wiring it is standing in for.
        authServiceProvider.overrideWith(
          (ref) => _AuthServiceThatClearsTokensOnSignOut(
            MockAuthService(prefs: ref.watch(sharedPrefsProvider)),
            ref.watch(tokenStoreProvider),
          ),
        ),
      ]);
      await _createAccountThenSignOut(container);
      await _signIn(container);

      // Added while signed in, so this only ever reached `remote` — the same
      // shape a real account's garage takes once `adoptGuestData` has already
      // run once at an earlier sign-in.
      await container
          .read(garageProvider.notifier)
          .add(const Car(id: 'signed-in-car', make: 'Toyota', model: 'Yaris', year: 2022));
      expect(container.read(garageProvider).map((c) => c.id), ['signed-in-car']);

      await container.read(authProvider.notifier).signOut();
      await _settle();

      // Routed back to the device store, which this account never wrote to —
      // not the previous session's `remote` copy still sitting in the warm
      // cache.
      expect(container.read(garageProvider), isEmpty);
    });

    test('a sign-out whose server round trip fails still clears the app '
        '— an already-expired access token is an ordinary reason for '
        '`POST /auth/logout` to answer 401, not a reason to leave every '
        'screen showing the departed account', () async {
      final marketplace = MockServiceMarketplaceService();
      final container = await createDataContainer(overrides: [
        serviceMarketplaceServiceProvider.overrideWithValue(marketplace),
        authServiceProvider.overrideWith(
          (ref) => _AuthServiceThatFailsToSignOut(
            MockAuthService(prefs: ref.watch(sharedPrefsProvider)),
          ),
        ),
      ]);
      await _createAccountThenSignOut(container);
      await _signIn(container);

      final booking = await marketplace.createRequest(
        CreateServiceRequestDraft(
          offering: MockServiceData.offerings.first,
          car: const Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019),
          plate: '1234 AB',
          fulfillment: Fulfillment.workshop,
          slot: 'Mon 3 Aug · 10:30',
          addOnIds: const {},
        ),
      );
      await container.read(requestsProvider.notifier).load();
      expect(
        container.read(requestsProvider).map((r) => r.id),
        contains(booking.id),
      );

      await container.read(authProvider.notifier).signOut();
      await _settle();

      // Before this fix, the throw inside `signOut()` skipped the line that
      // starts `SessionRefresh.clearAfterSignOut` entirely — the account's
      // own `requestsProvider` list would still be sitting here.
      expect(container.read(requestsProvider), isEmpty);
      expect(container.read(authProvider).isRegistered, isFalse);
    });
  });

  group('signing out must not reset device preferences that are not '
      'account data', () {
    test('the selected region survives — it is a device preference, not '
        'something a sign-out should touch', () async {
      final container = await createDataContainer();
      final regions = container.read(catalogRepositoryProvider).serviceRegions;
      // A region other than whatever `regionProvider`'s own default would
      // recompute to, so a reset back to that default is distinguishable
      // from the user's real choice surviving.
      final chosen = regions.last;
      container.read(regionProvider.notifier).state = chosen;

      await _createAccountThenSignOut(container);

      // `SessionRefresh._announce()` calls `WarmCacheNotice.announce()` on
      // both sign-in (inside `_createAccountThenSignOut`'s `register`) and
      // sign-out — either one used to be enough to blow the selection away,
      // because `regionProvider` used to `ref.watch` the catalogue
      // repository purely to compute its *initial* value, which made the
      // whole `StateProvider` rebuild — discarding the `.state` write above
      // — every time the repository's warm cache re-announced itself.
      expect(container.read(regionProvider), chosen);
    });
  });
}

/// Answers the first call to each method and throws from then on — so a test
/// can let bootstrap warm normally and still watch the refresh fail.
class _FailsAfterFirstCall implements CarsService {
  _FailsAfterFirstCall(this._inner);

  final CarsService _inner;
  int listingFetches = 0;

  Never _offline() => throw NetworkException('host unreachable');

  @override
  Future<List<GalleryListing>> fetchListings({
    CarsFilter? filter,
    SpecCatalog? specs,
  }) {
    if (++listingFetches > 1) _offline();
    return _inner.fetchListings(filter: filter, specs: specs);
  }

  @override
  Future<List<CarListing>> fetchHomeListings() => _inner.fetchHomeListings();

  @override
  Future<GalleryListing> fetchListing(String listingId) =>
      _inner.fetchListing(listingId);

  @override
  Future<List<GalleryListing>> fetchRelated(String listingId) =>
      _inner.fetchRelated(listingId);

  @override
  Future<List<GalleryListing>> fetchMyAds() => _inner.fetchMyAds();
}

/// [MockAuthService] whose [signOut] always throws — standing in for
/// `POST /auth/logout` answering `401` because the access token had already
/// expired, the ordinary case `AuthNotifier.signOut()` has to survive.
class _AuthServiceThatFailsToSignOut implements AuthService {
  _AuthServiceThatFailsToSignOut(this._inner);

  final AuthService _inner;

  @override
  Future<void> signOut() => throw const UnauthorizedException('token expired');

  @override
  Future<UserProfile?> fetchCurrentUser() => _inner.fetchCurrentUser();

  @override
  Future<UserProfile> register(UserProfile profile) => _inner.register(profile);

  @override
  Future<UserProfile> updateProfile(UserProfile profile) =>
      _inner.updateProfile(profile);

  @override
  Future<UserProfile?> findAccount(String identifier) =>
      _inner.findAccount(identifier);

  @override
  Future<UserProfile> login(String identifier, String code) =>
      _inner.login(identifier, code);
}

/// [MockAuthService] plus the two side effects only `ApiAuthService` carries
/// in production: saving a token on login/register and clearing it on
/// sign-out. See the test that uses this for why the gap matters —
/// `SessionGarageService` is the one thing in this suite that routes on the
/// token store directly rather than on [AuthState]/`prefsSessionActive`, so a
/// fake that leaves the store untouched (correctly, per [AuthService]'s own
/// doc comment — token handling is not this interface's job) cannot tell that
/// routing apart from a no-op.
class _AuthServiceThatClearsTokensOnSignOut implements AuthService {
  _AuthServiceThatClearsTokensOnSignOut(this._inner, this._tokens);

  final AuthService _inner;
  final TokenStore _tokens;

  @override
  Future<void> signOut() async {
    try {
      await _inner.signOut();
    } finally {
      await _tokens.clear();
    }
  }

  Future<UserProfile> _withToken(Future<UserProfile> Function() call) async {
    final profile = await call();
    await _tokens.save(access: 'test-access', refresh: 'test-refresh', expiresIn: 3600);
    return profile;
  }

  @override
  Future<UserProfile?> fetchCurrentUser() => _inner.fetchCurrentUser();

  @override
  Future<UserProfile> register(UserProfile profile) =>
      _withToken(() => _inner.register(profile));

  @override
  Future<UserProfile> updateProfile(UserProfile profile) =>
      _inner.updateProfile(profile);

  @override
  Future<UserProfile?> findAccount(String identifier) =>
      _inner.findAccount(identifier);

  @override
  Future<UserProfile> login(String identifier, String code) =>
      _withToken(() => _inner.login(identifier, code));
}

/// An in-memory [GarageService], same shape as `guest_garage_test.dart`'s —
/// this file needs its own copy rather than importing that one's private
/// class.
class _FakeGarage implements GarageService {
  final List<Car> cars = [];

  @override
  Future<List<Car>> fetchCars() async => List.unmodifiable(cars);

  @override
  Future<Car> addCar(Car car) async {
    cars.add(car);
    return car;
  }

  @override
  Future<void> removeCar(String carId) async =>
      cars.removeWhere((c) => c.id == carId);

  @override
  Future<Car> updateCar(Car car) async => car;

  @override
  Future<Car> updatePlate(String carId, String plate) async => _byId(carId);

  @override
  Future<Car> updateOdometer(String carId, int km) async => _byId(carId);

  @override
  Future<List<Car>> setPrimary(String carId) async => List.unmodifiable(cars);

  Car _byId(String id) => cars.firstWhere((c) => c.id == id);
}
