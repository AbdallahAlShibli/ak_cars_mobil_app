import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/error/app_exception.dart';
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
  ///
  /// Most of these need no session and always run: the catalogue, shop and
  /// cars feeds are public, the service marketplace's read half is public too,
  /// and the garage and its maintenance books are session-routed below the
  /// repository (`SessionGarageService`) so a guest reads the device. What is
  /// left — the challenge board, and the per-account lists behind
  /// [SessionRefresh.loadSessionLists] — is genuinely per-account, so it is
  /// only attempted when there is a session to attempt it with:
  ///
  /// * **Signed in.** They run, still swallowing a `401` — [_optional] here,
  ///   `SessionRefresh._bestEffort` there — because a *stored* token is not a
  ///   *valid* one, and an expired session answers `401` just like no session
  ///   at all.
  /// * **Guest.** They are skipped outright. They can only answer `401`
  ///   without a token, so firing them cost a guest's cold start round-trips
  ///   that were guaranteed to fail and buried any real error in console noise
  ///   on the way. This list used to be much longer: most of it was gated
  ///   because the API gated it, not because the data was per-account.
  ///
  /// The `401`s were never fatal — [_optional] has always swallowed them, the
  /// same case [ApiAuthService.fetchCurrentUser] treats as expected rather than
  /// an error. Skipping the calls changes what is *requested*, not what ends up
  /// warmed: an unwarmed repository is exactly where a swallowed `401` left it.
  static Future<void> warmUp(ProviderContainer container) async {
    final signedIn = await _signedIn(container);
    await Future.wait([
      container.read(catalogRepositoryProvider).warmUp(),
      container.read(shopRepositoryProvider).warmUp(),
      container.read(carsRepositoryProvider).warmUp(),
      // The garage and its maintenance books are warmed for *everyone*, not
      // only for a session. They are session-routed
      // (`SessionGarageService`): a guest's cars live on the device, because
      // registering one is step 3 of 3 of first launch and long precedes the
      // registration gate. Skipping these for a guest meant the car they had
      // just registered was written to the device and then never read back —
      // an empty garage on the next launch, and the rest of the app behaving
      // as if they had never registered one, since the start-choice flag
      // *did* survive.
      _optional(() => container.read(garageRepositoryProvider).warmUp()),
      _optional(() => container.read(maintenanceRepositoryProvider).warmUp()),
      // The service marketplace is browse data — who sells what, where, at
      // what price — and the API serves its read half to anonymous callers, on
      // the same rule that already makes `/cars` and `/products` public.
      // Warming it only for a session was the mirror image of that gate on the
      // client: a guest opened the Services tab onto nothing at all.
      _optional(
          () => container
              .read(serviceMarketplaceRepositoryProvider)
              .warmUp(includeFounderLedger: signedIn)),
      if (signedIn) ...[
        _optional(() => container.read(challengeRepositoryProvider).warmUp()),
        // The per-account lists: this session's bookings and orders, and — for
        // a founder — the operator queue. All three are read synchronously by
        // the screens that show them, exactly as the catalogue screens read the
        // catalogue, so they are loaded here rather than behind a loading state
        // the design does not have.
        //
        // Delegated to [SessionRefresh] rather than listed here, because
        // sign-in has to load the same set and then some: a cold start with a
        // stored token and a sign-in a minute later differ only in whether the
        // caches above already hold the right data, and two copies of this list
        // would be two places to forget the same screen. `includeSelfLoading:
        // false` leaves out the inbox and the reviews, which load themselves
        // from their own `build()` — see that method. It is internally
        // best-effort, including the `403` an ordinary customer or workshop
        // gets for the founder-only operator queue.
        container
            .read(sessionRefreshProvider)
            .loadSessionLists(includeSelfLoading: false),
      ],
    ]);
  }

  /// Whether the auth-gated warm-ups are worth attempting at all.
  ///
  /// Deliberately reads the token store rather than [authProvider]: the
  /// profile is only re-attached by `restore()`, which bootstrap runs *after*
  /// this, so auth state is still empty here no matter who is signed in. The
  /// stored token is the one signal available this early.
  static Future<bool> _signedIn(ProviderContainer container) =>
      container.read(tokenStoreProvider).mayHaveSession();

  /// Runs a warm-up that requires a signed-in session. A `401` here means
  /// "nobody is signed in", not "the warm-up failed" — swallowed so it never
  /// turns a guest's first launch into the boot-failure screen. Every other
  /// exception (offline, 5xx, a malformed response) still propagates: those
  /// are real failures and bootstrap should still treat them as fatal.
  ///
  /// Logged as a plain line, with no `error`/`stackTrace`: these are the
  /// *expected* answers, and attaching the exception made `developer.log`
  /// print a full 25-frame dump for each one. A guest's cold start produced
  /// several, which is how an ordinary launch came to look like a stack of
  /// crashes in the console.
  static Future<void> _optional(Future<void> Function() warmUp) async {
    try {
      await warmUp();
    } on UnauthorizedException {
      developer.log(
        'Skipped an auth-gated warm-up — no session yet',
        name: 'AppBootstrap',
      );
    }
  }

}
