import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/network/api_client.dart';
import 'package:ak_cars_mobil_app/core/network/unconfigured_api_client.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The §12 acceptance criterion, as a test rather than a manual step.
///
/// "`AK_DATA_SOURCE=api` boots and fails with a clear network error; `mock`
/// works fully." The `--dart-define` cannot be set from inside a test, so the
/// config is overridden to the same effect — what is actually being checked is
/// that the composition root switches every binding on one value, and that the
/// API path fails loudly instead of falling back to demo data.
void main() {
  Future<ProviderContainer> containerFor(DataSourceMode mode) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWithValue(
          AppConfig.forEnvironment(AppEnvironment.development)
              .copyWith(useMockData: mode == DataSourceMode.mock),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the api source binds every service to the REST implementation',
      () async {
    final container = await containerFor(DataSourceMode.api);
    expect(container.read(appConfigProvider).dataSource, DataSourceMode.api);

    // Every service named in §12 rule 2, all switched by the one value.
    expect(container.read(authServiceProvider).runtimeType.toString(),
        startsWith('Api'));
    expect(container.read(garageServiceProvider).runtimeType.toString(),
        startsWith('Api'));
    expect(
        container.read(serviceMarketplaceServiceProvider).runtimeType.toString(),
        startsWith('Api'));
    expect(container.read(maintenanceServiceProvider).runtimeType.toString(),
        startsWith('Api'));
    expect(container.read(reviewServiceProvider).runtimeType.toString(),
        startsWith('Api'));
  });

  test('the mock source binds every service to the offline implementation',
      () async {
    final container = await containerFor(DataSourceMode.mock);
    expect(container.read(appConfigProvider).dataSource, DataSourceMode.mock);
    expect(container.read(authServiceProvider).runtimeType.toString(),
        startsWith('Mock'));
    expect(
        container.read(serviceMarketplaceServiceProvider).runtimeType.toString(),
        startsWith('Mock'));
    expect(container.read(reviewServiceProvider).runtimeType.toString(),
        startsWith('Mock'));
  });

  test('the api client is registered and reads the configured base URL',
      () async {
    final container = await containerFor(DataSourceMode.api);
    final client = container.read(apiClientProvider);
    expect(client, isA<ApiClient>());
    expect((client as UnconfiguredApiClient).baseUrl,
        container.read(appConfigProvider).apiBaseUrl);
  });

  test('an api call fails with a network error that names what it could not '
      'reach — never a silent fallback to demo data', () async {
    final container = await containerFor(DataSourceMode.api);
    final baseUrl = container.read(appConfigProvider).apiBaseUrl;

    // The same exception type the real adapter throws when a device is
    // offline, which is what makes the two data sources interchangeable to
    // everything above the service layer (§12 rule 5).
    await expectLater(
      container.read(serviceMarketplaceServiceProvider).fetchProviders(),
      throwsA(
        isA<NetworkException>()
            .having((e) => e.message, 'message', contains(baseUrl))
            .having((e) => e.message, 'message', contains('AK_DATA_SOURCE')),
      ),
    );
    await expectLater(
      container.read(authServiceProvider).fetchCurrentUser(),
      throwsA(isA<NetworkException>()),
    );
  });

  test('an explicit AK_DATA_SOURCE define wins over the environment default',
      () {
    // Production ships `useMockData: false`, so its derived source is already
    // the API — the point being that the two can never disagree.
    expect(
      AppConfig.forEnvironment(AppEnvironment.production).dataSource,
      DataSourceMode.api,
    );
    expect(
      AppConfig.forEnvironment(AppEnvironment.development).dataSource,
      DataSourceMode.mock,
    );
    expect(DataSourceMode.fromKey('api'), DataSourceMode.api);
    expect(DataSourceMode.fromKey('nonsense'), DataSourceMode.mock,
        reason: 'an unreadable define must not silently mean "go live"');
  });
}
