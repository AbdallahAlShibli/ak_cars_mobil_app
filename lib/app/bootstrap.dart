import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/providers.dart';
import '../state/app_state.dart';

/// Start-up sequence, shared by `main()` and the widget tests.
///
/// Reference data (spec vocabulary, makes, locations, the parts catalogue,
/// the cars feed) is fetched once here, before the first frame, so screens
/// can keep reading it synchronously while building. That is what lets this
/// refactor introduce a real async data layer without adding loading states
/// the design does not have.
///
/// When the REST services land, this is also the natural place to decide what
/// a failed warm-up means — retry, fall back to a cached snapshot, or show an
/// error screen. Today the mock services cannot fail.
abstract final class AppBootstrap {
  /// Builds a container with platform dependencies injected and every
  /// repository warmed. Callers own the returned container and must dispose
  /// it.
  static Future<ProviderContainer> createContainer({
    List<Override> overrides = const [],
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        ...overrides,
      ],
    );
    await warmUp(container);
    // Re-attach the stored session before the first frame: the router picks
    // its start route from auth state, so this has to land before anything
    // reads it. Deliberately outside `warmUp` — that one is reference data,
    // and the pure-data test container has no SharedPreferences to restore
    // from.
    await container.read(authProvider.notifier).restore();
    return container;
  }

  /// Fetches the reference data every screen assumes is already present.
  ///
  /// The repositories are warmed in parallel because none depends on another.
  static Future<void> warmUp(ProviderContainer container) => Future.wait([
        container.read(catalogRepositoryProvider).warmUp(),
        container.read(serviceMarketplaceRepositoryProvider).warmUp(),
        container.read(shopRepositoryProvider).warmUp(),
        container.read(carsRepositoryProvider).warmUp(),
        container.read(garageRepositoryProvider).warmUp(),
        container.read(maintenanceRepositoryProvider).warmUp(),
        container.read(challengeRepositoryProvider).warmUp(),
        // The operator panels read their queue synchronously while building,
        // exactly as the catalogue screens do, so it is warmed here with the
        // rest rather than behind a loading state the design does not have.
        container.read(operatorQueueProvider.notifier).refresh(),
      ]);
}
