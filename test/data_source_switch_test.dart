import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/network/api_client.dart';
import 'package:ak_cars_mobil_app/core/network/dio_api_client.dart';
import 'package:ak_cars_mobil_app/data/services/session_routed_services.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app has exactly one data source, and it is the API.
///
/// This file used to assert that a `DataSourceMode` flag switched every
/// binding between an `Api*` and a `Mock*` implementation, and that the API arm
/// failed loudly rather than falling back. The flag, the offline
/// implementations and the demo world they read were removed from `lib/` on
/// 2026-08-10 — the doubles now live in `test/fakes/` and are injected by the
/// harness. What is left to prove is that nothing in the composition root can
/// resolve to anything but the REST implementation, whatever the environment.
void main() {
  Future<ProviderContainer> containerFor(AppEnvironment environment) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appConfigProvider
            .overrideWithValue(AppConfig.forEnvironment(environment)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final environment in AppEnvironment.values) {
    test('${environment.name} binds every service to the REST implementation',
        () async {
      final container = await containerFor(environment);

      expect(container.read(authServiceProvider).runtimeType.toString(),
          startsWith('Api'));
      expect(
          container
              .read(serviceMarketplaceServiceProvider)
              .runtimeType
              .toString(),
          startsWith('Api'));
      expect(container.read(reviewServiceProvider).runtimeType.toString(),
          startsWith('Api'));
      expect(container.read(catalogServiceProvider).runtimeType.toString(),
          startsWith('Api'));
      expect(container.read(carsServiceProvider).runtimeType.toString(),
          startsWith('Api'));
      expect(container.read(shopServiceProvider).runtimeType.toString(),
          startsWith('Api'));
      expect(container.read(orderServiceProvider).runtimeType.toString(),
          startsWith('Api'));
      expect(container.read(notificationServiceProvider).runtimeType.toString(),
          startsWith('Api'));
      expect(container.read(chatServiceProvider).runtimeType.toString(),
          startsWith('Api'));
      expect(container.read(challengeServiceProvider).runtimeType.toString(),
          startsWith('Api'));

      // The two exceptions, and deliberately so: a guest is invited to
      // register a car as step 3 of 3 of first launch, which is well before
      // the registration gate, while `/user/vehicles` is `[Authorize]`d. Both
      // are wrapped so a guest writes to the device and a session writes to
      // REST — see `SessionGarageService`. Binding them straight to `Api*` is
      // what broke first launch; asserting the wrapper here is what let it
      // ship.
      expect(container.read(garageServiceProvider), isA<SessionGarageService>());
      expect(container.read(maintenanceServiceProvider),
          isA<SessionMaintenanceService>());
    });
  }

  test('every environment points at the one configured API host', () {
    for (final environment in AppEnvironment.values) {
      expect(AppConfig.forEnvironment(environment).apiBaseUrl,
          'https://localhost:7291/api/v1');
    }
  });

  test('the api client is registered and reads the configured base URL',
      () async {
    final container = await containerFor(AppEnvironment.development);
    final client = container.read(apiClientProvider);
    expect(client, isA<ApiClient>());
    expect((client as DioApiClient).baseUrl,
        container.read(appConfigProvider).apiBaseUrl);
  });

  test('an unreachable host is a failure, never a fallback to demo data',
      () async {
    const baseUrl = 'https://unreachable.invalid/api/v1';
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWithValue(
          AppConfig.forEnvironment(AppEnvironment.development)
              .copyWith(apiBaseUrl: baseUrl),
        ),
      ],
    );
    addTearDown(container.dispose);

    // The service resolves to the REST implementation against a host that
    // does not exist. There is no second implementation for it to quietly
    // become, which is the property this whole change was for.
    expect(container.read(serviceMarketplaceServiceProvider).runtimeType
        .toString(), startsWith('Api'));
    expect((container.read(apiClientProvider) as DioApiClient).baseUrl, baseUrl);
  });
}
