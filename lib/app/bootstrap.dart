import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_endpoints.dart';
import '../core/error/app_exception.dart';
import '../core/network/response_cache.dart';
import '../core/utils/jwt_claims.dart';
import '../di/providers.dart';
import '../state/app_state.dart';
import '../state/startup_state.dart';

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

  /// How long start-up waits for the first load before painting anyway.
  ///
  /// The load itself is not cut short — it carries on in the background, the
  /// app-wide loading bar shows it, and screens show their placeholders until
  /// it lands (see [startupLoadingProvider]). This only decides when the
  /// launch screen goes. Long enough that a start-up the disk cache can answer
  /// (tens of milliseconds) paints complete; short enough that a first launch,
  /// which has nothing stored and waits on the tunnel, is not left on the
  /// launch screen for the several seconds its ~38 requests take.
  static const firstFrameBudget = Duration(milliseconds: 500);

  /// The first load of each container, as [startupSettled] hands it out.
  static final _settled = Expando<Future<void>>('startupSettled');

  /// Completes when [container]'s first load has settled.
  ///
  /// Completes normally when it succeeded, or failed after the disk cache had
  /// already given screens something real to show. Completes with the error
  /// when it failed with nothing stored — `AppLauncher` turns that into the
  /// boot-failure screen. A container bootstrap did not build has nothing to
  /// wait for.
  static Future<void> startupSettled(ProviderContainer container) =>
      _settled[container] ?? Future<void>.value();

  /// Builds a container with platform dependencies injected and every
  /// repository warmed. Callers own the returned container and must dispose
  /// it.
  static Future<ProviderContainer> createContainer({
    List<Override> overrides = const [],
    Duration timeout = bootTimeout,
    Duration firstFrameBudget = AppBootstrap.firstFrameBudget,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance().timeout(timeout);

    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        ...overrides,
      ],
    );
    final settled = _loadFirst(container, timeout);
    _settled[container] = settled;
    try {
      await _settledOrElapsed(settled, firstFrameBudget);
    } catch (_) {
      // Failed inside the budget with nothing stored to show. A container
      // that failed half way through still holds live notifiers and their
      // timers, and retrying the boot builds a second one, so this one goes.
      container.dispose();
      rethrow;
    }
    return container;
  }

  /// The first load: every repository's warm-up and the session's profile,
  /// side by side, reading what the previous run stored before asking the
  /// network — see [ResponseCache]. Bookable slots stay out: they are live
  /// occupancy, fetched by [completeWarmUp] once the first frame is up.
  ///
  /// The profile is re-attached here because the router picks its start route
  /// from auth state. Deliberately outside `warmUp` — that one is reference
  /// data, and the pure-data test container has no SharedPreferences to
  /// restore from.
  ///
  /// A failure after the disk cache has answered is logged and swallowed: the
  /// screens already hold the last run's real data, and [completeWarmUp]
  /// refreshes it. Only a failure with nothing stored is an error.
  static Future<void> _loadFirst(
    ProviderContainer container,
    Duration timeout,
  ) async {
    container.read(startupLoadingProvider.notifier).start();
    final scope = ResponseCacheScope.preferringCache();
    try {
      await scope
          .run(
            () => Future.wait([
              warmUp(container, includeAvailability: false),
              container.read(authProvider.notifier).restore(),
            ], eagerError: true),
          )
          .timeout(timeout);
    } catch (error, stack) {
      if (!scope.servedFromCache) rethrow;
      developer.log(
        'The first load failed part way; screens keep what the last run '
        'stored until the refresh after the first frame',
        name: 'AppBootstrap',
        error: error,
        stackTrace: stack,
      );
    } finally {
      // The first load is over: from here on nothing may be answered from
      // disk, including callbacks that were set up inside it and still run in
      // its zone — see [ResponseCacheScope.close].
      scope.close();
      _tryUpdate(container, () {
        container.read(bootServedFromCacheProvider.notifier).state =
            scope.servedFromCache;
        container.read(startupLoadingProvider.notifier).finish();
      });
    }
  }

  /// Runs [update] unless [container] has already been disposed — a test
  /// tearing down, or a failed boot — which Riverpod reports by throwing.
  static void _tryUpdate(ProviderContainer container, void Function() update) {
    try {
      update();
    } on StateError {
      // Disposed: there is nobody left to tell.
    }
  }

  /// Completes when [settled] does or [budget] has passed, whichever is
  /// first. An error from [settled] inside the budget is rethrown; one after
  /// it is left to whoever else waits on [settled].
  static Future<void> _settledOrElapsed(
    Future<void> settled,
    Duration budget,
  ) {
    final done = Completer<void>();
    final timer = Timer(budget, () {
      if (!done.isCompleted) done.complete();
    });
    settled.then(
      (_) {
        timer.cancel();
        if (!done.isCompleted) done.complete();
      },
      onError: (Object error, StackTrace stack) {
        timer.cancel();
        if (!done.isCompleted) done.completeError(error, stack);
      },
    );
    return done.future;
  }

  /// The half of start-up that runs just after the first frame, never before
  /// it — `AppLauncher` schedules it.
  ///
  /// * **Painted from disk:** every warm cache, the session lists and every
  ///   workshop's slots are fetched live and the screens repaint — the same
  ///   refresh pull-to-refresh runs, which also stores the answers for the
  ///   next start-up.
  /// * **Painted from the network** (a first launch, or a cache the OS
  ///   emptied): everything but the slots is already live, so only those are
  ///   fetched.
  ///
  /// Best-effort: a screen that fails to refresh keeps what it painted with,
  /// and the booking screen asks for its own workshop's slots as it opens.
  ///
  /// **Except when the server cannot be reached at all.** A start-up painted
  /// from disk never touched the network, so it looks healthy with the API
  /// down; it is only here, asking the server first, that this shows. That
  /// throws — the connection error, a timeout, or a 5xx such as the tunnel's
  /// 502 in front of a stopped API — and `AppLauncher` shows the failure
  /// screen instead of a stale app nothing in which can be refreshed, booked
  /// or paid for.
  static Future<void> completeWarmUp(ProviderContainer container) async {
    try {
      await startupSettled(container);
    } catch (_) {
      // Nothing to complete: `AppLauncher` shows the failure screen.
      return;
    }
    if (container.read(bootServedFromCacheProvider)) {
      await _ensureServerReachable(container);
    }
    try {
      if (container.read(bootServedFromCacheProvider)) {
        await Future.wait([
          container.read(sessionRefreshProvider).refreshVisibleData(),
          // The profile came from disk too; this is where an expired session
          // is found out and signed out.
          container.read(authProvider.notifier).restore(revalidate: true),
        ]);
      } else {
        await container
            .read(serviceMarketplaceRepositoryProvider)
            .warmAvailability();
        container.read(warmCacheNoticeProvider).announce();
      }
    } catch (error, stack) {
      developer.log(
        'Could not finish the start-up warm-up; screens keep what they have',
        name: 'AppBootstrap',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Throws when the API cannot be reached; returns when it answered at all.
  ///
  /// Any answer that is not a server fault counts as reachable — a `404` from
  /// an API deployed before `/health` existed included — because the question
  /// is whether anything is there, not whether this route is. Reads retry
  /// stalls (`AppConfig.readRetries`), so one slow round trip through the
  /// tunnel does not fail start-up.
  static Future<void> _ensureServerReachable(ProviderContainer container) async {
    try {
      await container.read(apiClientProvider).get(ApiEndpoints.health);
    } on ApiException catch (error) {
      if (error.isServerError) rethrow;
    } on NetworkException {
      rethrow;
    } on RequestTimeoutException {
      rethrow;
    } on AppException {
      // Answered: 401/403/404/429 and friends all come from a live server.
    }
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
  ///
  /// [includeAvailability] false leaves every workshop's bookable slots for
  /// [completeWarmUp] — see [ServiceMarketplaceRepository.warmUp].
  static Future<void> warmUp(
    ProviderContainer container, {
    bool includeAvailability = true,
  }) async {
    final signedIn = await _signedIn(container);
    final founder = signedIn && await _isFounder(container);
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
      // `includeFounderLedger` is keyed on the *founder* claim, not merely on
      // having a session: the payout and audit ledgers answer every other
      // signed-in account `403`, so passing `signedIn` here put two red lines
      // in every ordinary customer's console on every cold start.
      _optional(
          () => container
              .read(serviceMarketplaceRepositoryProvider)
              .warmUp(
                includeFounderLedger: founder,
                includeAvailability: includeAvailability,
              )),
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

  /// Whether that stored token is a *founder's*.
  ///
  /// Same reason [_signedIn] reads the token store: `restore()` has not run
  /// yet, so `AuthState.isFounder` is still false for everybody here. Gates
  /// the two ledger warm-ups that answer any other account `403`.
  static Future<bool> _isFounder(ProviderContainer container) async =>
      jwtHasFounderRole(
        await container.read(tokenStoreProvider).tryReadAccessToken(),
      );

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

/// Whether start-up painted from the disk cache, so [AppBootstrap
/// .completeWarmUp] knows a live refresh has to follow. Written once, by the
/// bootstrap.
final bootServedFromCacheProvider = StateProvider<bool>((ref) => false);
