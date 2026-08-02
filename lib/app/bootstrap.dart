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
/// A failed warm-up is **fatal and visible**: this throws, and `AppLauncher`
/// turns the throw into the boot-failure screen. It deliberately does not fall
/// back to an empty container — screens read reference data synchronously on
/// the assumption it is there, so a half-warmed app is a wrong app, not a
/// degraded one. The one thing it must never do is hang: see [bootTimeout].
abstract final class AppBootstrap {
  /// Ceiling on the whole start-up sequence.
  ///
  /// Nothing here is allowed to take longer than this, whatever it is waiting
  /// on. Without it a service that never completes its future — an API call
  /// against an unreachable host, a platform channel that never answers — left
  /// `main()` suspended before `runApp`, so the OS launch screen stayed on
  /// screen forever with no error, no spinner and no way out. A timeout turns
  /// that silent hang into the boot-failure screen, which at least says what
  /// happened and offers a retry.
  static const bootTimeout = Duration(seconds: 20);

  /// Builds a container with platform dependencies injected and every
  /// repository warmed. Callers own the returned container and must dispose
  /// it.
  static Future<ProviderContainer> createContainer({
    List<Override> overrides = const [],
    Duration timeout = bootTimeout,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance().timeout(timeout);

    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        ...overrides,
      ],
    );
    try {
      await warmUp(container).timeout(timeout);
      // Re-attach the stored session before the first frame: the router picks
      // its start route from auth state, so this has to land before anything
      // reads it. Deliberately outside `warmUp` — that one is reference data,
      // and the pure-data test container has no SharedPreferences to restore
      // from.
      await container.read(authProvider.notifier).restore().timeout(timeout);
    } catch (_) {
      // A container that failed half way through still holds live notifiers
      // and their timers. Retrying the boot builds a second one, so the first
      // has to go.
      container.dispose();
      rethrow;
    }
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
