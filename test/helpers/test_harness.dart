import 'package:ak_cars_mobil_app/app/bootstrap.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a container wired exactly like the app's, including the bootstrap
/// warm-up.
///
/// Screens read reference data (spec vocabulary, makes, locations, the parts
/// catalogue) synchronously while building, on the assumption that bootstrap
/// has already loaded it. Tests must honour that same contract, so they go
/// through [AppBootstrap.warmUp] rather than constructing a bare
/// `ProviderScope`.
Future<ProviderContainer> createTestContainer({
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await AppBootstrap.warmUp(container);
  return container;
}

/// Warmed container for pure-Dart tests that never touch a widget tree.
///
/// Skips the SharedPreferences override — nothing below the settings notifier
/// reads it — so these tests do not need a widget binding.
Future<ProviderContainer> createDataContainer({
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  await AppBootstrap.warmUp(container);
  return container;
}
