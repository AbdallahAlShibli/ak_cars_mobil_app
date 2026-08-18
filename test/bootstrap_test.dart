import 'package:ak_cars_mobil_app/app/bootstrap.dart';
import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fakes.dart';

/// Guards the contract the whole synchronous-read design rests on: after
/// bootstrap, every repository a screen reads while building is populated.
///
/// If this fails, screens will render empty lists on their first frame.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('createContainer wires platform dependencies and warms every '
      'repository', () async {
    // This test is about the warm-up contract, not the network. The app has
    // no offline data source to fall back on any more, so the doubles are
    // injected explicitly — the same set the widget harness uses.
    final container = await AppBootstrap.createContainer(
      overrides: fakeServiceOverrides(await SharedPreferences.getInstance()),
    );
    addTearDown(container.dispose);

    // Platform dependency injected rather than thrown.
    expect(container.read(sharedPrefsProvider), isNotNull);

    final catalog = container.read(catalogRepositoryProvider);
    expect(catalog.vehicles.makes, isNotEmpty);
    expect(catalog.vehicles.plateLetters, isNotEmpty);
    expect(catalog.specs.bodyTypes, isNotEmpty);
    expect(catalog.specs.engineSizes, isNotEmpty);
    expect(catalog.locations.governorates, isNotEmpty);
    expect(catalog.serviceRegions, isNotEmpty);

    final marketplace = container.read(serviceMarketplaceRepositoryProvider);
    expect(marketplace.categories, isNotEmpty);
    expect(marketplace.primaryCategories, isNotEmpty);
    expect(marketplace.otherCategories, isNotEmpty);
    expect(marketplace.providers, isNotEmpty);
    expect(marketplace.offerings, isNotEmpty);
    // Per-provider data is warmed too, not fetched lazily on first paint.
    expect(marketplace.addOnsFor(marketplace.providers.first.id), isNotEmpty);
    expect(
      marketplace.availabilityFor(marketplace.providers.first.id).slots,
      isNotEmpty,
    );

    final shop = container.read(shopRepositoryProvider);
    expect(shop.products, isNotEmpty);
    expect(shop.partCategories, isNotEmpty);

    final cars = container.read(carsRepositoryProvider);
    expect(cars.listings, isNotEmpty);
    expect(cars.homeListings, isNotEmpty);

    // Maintenance is per car and never seeded: a fresh install has no cars,
    // so it has no maintenance history either. This used to warm a global
    // demo log, which is what made a brand-new car show services it had
    // never had.
    expect(container.read(maintenanceRepositoryProvider).books, isEmpty);
    expect(container.read(challengeRepositoryProvider).board.current,
        isNotNull);
  });

  test('the default build points at the real API host', () {
    // Every environment shares one fixed API host, and since 2026-08-10 there
    // is no other data source to point anywhere else — `AppConfig.current()`
    // with no override is the production/staging/dev-with-no-flags path. This
    // checks the config value directly rather than booting a container: a
    // warm-up without the fakes would genuinely try to reach the API and hang
    // for `bootTimeout` with nothing listening.
    expect(AppConfig.current().apiBaseUrl, 'https://localhost:7291/api/v1');
  });
}
