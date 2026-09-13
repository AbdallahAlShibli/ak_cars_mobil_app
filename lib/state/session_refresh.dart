import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../core/utils/jwt_claims.dart';
import '../di/providers.dart';
import 'admin_content_state.dart';
import 'auth_state.dart';
import 'cars_state.dart';
import 'challenge_state.dart';
import 'chat_state.dart';
import 'garage_state.dart';
import 'maintenance_state.dart';
import 'notifications_state.dart';
import 'operator_queue_state.dart';
import 'orders_state.dart';
import 'provider_dashboard_state.dart';
import 'requests_state.dart';
import 'reviews_state.dart';

/// Re-reads the whole app for the account that is now signed in.
///
/// **Why this is one object and not a line in the login screen.** Signing in
/// does not just add an identity, it changes the answer to almost every
/// question the app has already asked. The catalogue is the same, but the
/// garage, the maintenance books, the bookings, the orders, the inbox, the
/// reviews, the challenge board, the founder's ledger and the operator queue
/// are all somebody's, and until sign-in they were nobody's — or, after a
/// sign-out and a sign-in on the same phone, they were *somebody else's*. A
/// refresh that covers four of those and forgets the rest is worse than none,
/// because the screens it forgot look authoritative.
///
/// So the rule lives in one place, is applied in one order, and every caller
/// gets all of it:
///
/// 1. **Refill every warm cache** ([_refillWarmCaches]). Old values stay
///    readable throughout — `WarmCache.load` only assigns once the fetch
///    returns — so no screen is ever momentarily empty.
/// 2. **Announce it** ([_announce]). The caches are plain fields on long-lived
///    repositories, so nothing above them knows they moved until they are told.
///    See [WarmCacheNotice] for why it is done this way round.
/// 3. **Reload the per-account lists** ([loadSessionLists]), which are held in
///    notifiers rather than in caches and so are fetched rather than announced.
///
/// Every step is **best-effort**. By the time this runs the session is already
/// committed and the auth screen is already popping, so a failure here must
/// leave the user signed in and looking at whatever that screen had — never
/// stranded on a login form because their inbox would not load. What it must
/// not do is fail *silently*: [_bestEffort] logs everything, and distinguishes
/// the two answers that are ordinary ("no session", "not a founder") from the
/// ones that are not.
class SessionRefresh {
  SessionRefresh(this._ref);

  final Ref _ref;

  /// Whether the container has gone away underneath us.
  ///
  /// [refreshEverything] is started fire-and-forget from `AuthNotifier`, so it
  /// can still be in flight when the app is torn down or hot-restarted;
  /// touching `_ref` after that throws a bare `StateError` into the zone with
  /// nobody to catch it. Same guard, and same reason, as `AuthNotifier`'s.
  bool _disposed = false;

  void dispose() => _disposed = true;

  /// The whole thing: caches, announcement, per-account lists.
  ///
  /// [generation] is `AuthNotifier.generation` as it stood the moment this
  /// call was started — see that field's own doc comment for the race this
  /// closes. Checked after the one step slow enough for a newer call to
  /// finish first (the network round trip in [_refillWarmCaches]); the two
  /// synchronous steps after it run together once that check passes, so nothing
  /// can interleave between them.
  Future<void> refreshEverything({required int generation}) async {
    await _refillWarmCaches(includeFounderLedger: await _isFounder());
    if (_disposed || _supersededBy(generation)) return;
    _announce();
    await loadSessionLists();
  }

  /// The same three steps, run because **the user asked for them** — the
  /// pull-to-refresh gesture on the five customer tabs.
  ///
  /// It takes no [generation] because there is no race to lose: the identity
  /// is not changing underneath this call the way it is during a sign-in, so
  /// there is no newer refresh whose result this one could overwrite. The
  /// [_disposed] guard stays, since the container can still go away while the
  /// round trip is in flight.
  ///
  /// Deliberately the *whole* refresh and not a per-screen one. The five tabs
  /// read across almost every cache between them — the home page alone shows
  /// the garage, the maintenance books, the offers and the workshop boards —
  /// so a refresh scoped to "what this tab reads" would be four-fifths of this
  /// anyway, and would have to be re-derived every time a section moved
  /// between tabs. Every step is best-effort ([_bestEffort]), so a tab whose
  /// data fails to reload keeps what it had rather than emptying.
  Future<void> refreshVisibleData() async {
    await _refillWarmCaches(includeFounderLedger: await _isFounder());
    if (_disposed) return;
    _announce();
    await loadSessionLists();
  }

  /// The mirror image of [refreshEverything], run after a sign-out.
  ///
  /// Signing out changes the answer to the same questions signing in does —
  /// just back to "nobody's" rather than to somebody new's. Without this, the
  /// warm caches and the per-account notifiers went on holding the departed
  /// account's data until the next cold start: the garage tab kept that
  /// account's cars, "My orders" kept their orders, and — worse — a founder's
  /// payout ledger stayed in the service marketplace cache for whoever (or
  /// whichever guest) used the app next on the same device.
  ///
  /// Same shape as [refreshEverything], with two differences instead of a
  /// fetch to run per account:
  ///
  /// 1. The warm caches are refilled **without** the founder ledger — there is
  ///    no session to ask it for any more, and refetching drops whatever a
  ///    founder's sign-in had put there.
  /// 2. There is nobody to fetch [loadSessionLists] *for*, so the per-account
  ///    notifiers are told to [RequestsNotifier.clear] themselves rather than
  ///    reloaded. **Not** `ref.invalidate` — see [RequestsNotifier.clear]'s
  ///    doc comment for the two independent reasons that would be wrong here:
  ///    a real disposal race reproduced by this file's own tests, and (for
  ///    the inbox specifically) a second push subscription left open.
  ///    `operatorQueueProvider` needs its own explicit
  ///    [OperatorQueueNotifier.clear] call too — it watches `requestsProvider`
  ///    and so *rebuilds* when that clears, but its marketplace-wide half
  ///    lives in a plain field a rebuild does not reset (see that method's
  ///    doc comment; this was found, not assumed, once this entry's own
  ///    reasoning was checked against the field it was describing).
  ///
  /// [generation] — see [refreshEverything]'s doc comment for what this
  /// guards against and why it is checked in the same place.
  Future<void> clearAfterSignOut({required int generation}) async {
    await _refillWarmCaches(includeFounderLedger: false);
    if (_disposed || _supersededBy(generation)) return;
    _announce();
    _ref.read(requestsProvider.notifier).clear();
    _ref.read(ordersProvider.notifier).clear();
    _ref.read(notificationsProvider.notifier).clear();
    _ref.read(reviewsProvider.notifier).clear();
    _ref.read(operatorQueueProvider.notifier).clear();
  }

  /// Whether some other `login`/`register`/`signOut` has started since
  /// [generation] was captured — see `AuthNotifier.generation`'s doc comment.
  bool _supersededBy(int generation) =>
      _ref.read(authProvider.notifier).generation != generation;

  /// Whether this session's stored token carries the backend's founder role.
  ///
  /// Three of the fetches below are founder-only, and this file used to ask
  /// for all three unconditionally on the grounds that "there is no claim on
  /// the profile that says whether this session is a founder's — the `403`
  /// *is* the check". That was true of the *profile* and false of the
  /// *token*: `TokenService.GenerateAccessToken` puts the role in the JWT, and
  /// [jwtHasFounderRole] has read it since the `/admin` route guard needed it.
  /// So every ordinary customer's sign-in fired three requests that could only
  /// ever answer `403`, and printed three red lines in the console on the way.
  ///
  /// Read off the token rather than [AuthState.isFounder] because bootstrap
  /// calls [loadSessionLists] *before* `AuthNotifier.restore()` re-attaches
  /// the profile — auth state is still empty there no matter who is signed in,
  /// exactly as `AppBootstrap._signedIn` describes. The token is already
  /// stored in both paths: a cold start reads the one persisted last session,
  /// and `login()`/`register()` save it before they return.
  ///
  /// **Not a trust boundary** — see [jwtHasFounderRole]. Skipping a call the
  /// server would refuse anyway cannot grant access; the endpoints still
  /// enforce the role themselves.
  Future<bool> _isFounder() async => jwtHasFounderRole(
    await _ref.read(tokenStoreProvider).tryReadAccessToken(),
  );

  /// Re-fetches everything the repositories hold in warm caches.
  ///
  /// In parallel, because none of them depends on another — and *all* of them,
  /// not only the `[Authorize]`d ones. The public feeds are refetched too: they
  /// were loaded when this process started and may be minutes or hours old by
  /// the time somebody signs in or out, and both are moments the user already
  /// expects the app to go and look.
  ///
  /// [includeFounderLedger] is the one thing that differs between the two
  /// callers: [refreshEverything] asks for it only when [_isFounder] says the
  /// session's token carries the role (a `403` is still swallowed by
  /// [_bestEffort] if the claim and the server ever disagree), while
  /// [clearAfterSignOut] asks it to be dropped, since there is no session left
  /// to hold it for.
  Future<void> _refillWarmCaches({required bool includeFounderLedger}) async {
    await Future.wait([
      _bestEffort(
        'vehicle & location catalogues',
        () => _ref.read(catalogRepositoryProvider).warmUp(),
      ),
      _bestEffort(
        'parts catalogue',
        () => _ref.read(shopRepositoryProvider).warmUp(),
      ),
      _bestEffort(
        'cars feed',
        () => _ref.read(carsRepositoryProvider).warmUp(),
      ),
      _bestEffort(
        'service marketplace',
        () => _ref
            .read(serviceMarketplaceRepositoryProvider)
            .warmUp(includeFounderLedger: includeFounderLedger),
      ),
      _bestEffort('garage', () => _ref.read(garageRepositoryProvider).warmUp()),
      _bestEffort(
        'maintenance books',
        () => _ref.read(maintenanceRepositoryProvider).warmUp(),
      ),
      _bestEffort(
        'challenge board',
        () => _ref.read(challengeRepositoryProvider).warmUp(),
      ),
    ]);
  }

  /// Tells the widget tree that the caches underneath it have moved.
  ///
  /// One call reaches everything that reads a repository directly — every
  /// provider in `lib/state/` and every widget that watches one — because it
  /// notifies the repository providers themselves. See [WarmCacheNotice].
  ///
  /// The `invalidate`s are for the notifiers that take a *copy* of a
  /// repository's data in `build()` instead of reading through it on every
  /// access. Notifying cannot reach those: the copy was taken once, and for
  /// [maintenanceProvider] it was taken with a `read` that never subscribed at
  /// all. They are listed explicitly rather than left to whether each happens
  /// to have used `watch` or `read`, because that distinction is exactly the
  /// kind of thing an unrelated edit changes without noticing.
  ///
  /// The last two hold nothing but this session's own scratch work — ads
  /// posted, threads opened — and are cleared rather than reloaded, because on
  /// this phone they may belong to whoever was signed in before.
  ///
  /// **The workshop dashboard providers** (`provider_dashboard_state.dart`)
  /// are a second category entirely: unlike everything else this method
  /// touches, `WorkshopRepository` is not part of [_refillWarmCaches] at
  /// all — it is fetched on demand, only once a signed-in owner opens
  /// `/workshop/dashboard`, since a plain customer or a founder has no
  /// workshop to warm one for. Its `AsyncNotifierProvider`s therefore never
  /// had anything invalidating them: signing out and a *different* workshop
  /// owner signing in on the same device left every dashboard screen
  /// (summary, offerings, add-ons, inventory, staff, requests, customers,
  /// schedule, earnings, metrics, and the workshop's own profile) showing
  /// whichever account had opened the dashboard last, because Riverpod has no
  /// way to know the account changed underneath a provider nothing told it
  /// to re-run. Invalidating rather than reloading, same as the five above:
  /// nobody is guaranteed to be looking at the dashboard the moment this
  /// runs, so there is nothing to reload *for* — the next open re-fetches
  /// through the guard in `app_router.dart`, which already keeps a
  /// non-owner out.
  void _announce() {
    _ref.read(warmCacheNoticeProvider).announce();

    _ref.invalidate(garageProvider);
    _ref.invalidate(maintenanceProvider);
    _ref.invalidate(challengeProvider);
    _ref.invalidate(myAdsProvider);
    _ref.invalidate(chatProvider);

    // `_ifBuilt` and not a bare `_ref.invalidate` — see that helper's doc
    // comment. Skipped here, not for these four: `Ref.invalidate` on a bare
    // `.family` provider (no argument) only ever touches instances that
    // already exist — Riverpod's own `ProviderContainer.invalidate` special-
    // cases a `Family` target to loop over its *existing* `_stateReaders*
    // rather than creating one — so these were never at risk of the eager
    // build the single-provider ones needed guarding against.
    _ref.invalidate(workshopCustomerDetailProvider);
    _ref.invalidate(workshopScheduleProvider);
    _ref.invalidate(workshopDashboardEarningsProvider);
    _ref.invalidate(workshopDashboardMetricsProvider);

    _ifBuilt(workshopSummaryProvider);
    _ifBuilt(myWorkshopProfileProvider);
    _ifBuilt(workshopOfferingsProvider);
    _ifBuilt(workshopAddOnsProvider);
    _ifBuilt(workshopInventoryProvider);
    _ifBuilt(workshopStaffProvider);
    _ifBuilt(workshopRequestsProvider);
    _ifBuilt(workshopCustomersProvider);
    _ifBuilt(workshopScheduleConfigProvider);

    // Same reasoning as the workshop-dashboard block above: founder-only,
    // fetched on demand via `ref.read` inside `build()`, never reached by
    // `warmCacheNoticeProvider`.
    _ifBuilt(adminOffersProvider);
    _ifBuilt(adminPromotionsProvider);
  }

  /// [Ref.invalidate], but only for a provider that has actually been built
  /// at least once — i.e. one that could actually be holding a previous
  /// account's data to leak.
  ///
  /// **Not a style preference — plain `ref.invalidate()` on a provider that
  /// was never built fires a real network request for every sign-in and
  /// sign-out, for every account, including a plain customer who has never
  /// opened `/workshop/dashboard` and never will.** `Ref.invalidate` asserts
  /// `_debugAssertCanDependOn(provider)` before invalidating — a debug-mode-
  /// only safety check against circular dependencies — and that assertion's
  /// own implementation, to check the target is not mid-construction,
  /// initializes it: `_container.readProviderElement(listenable)`, verbatim,
  /// in `element.dart`. For an `AsyncNotifierProvider` never touched this
  /// session, "initializing" means actually running its `build()` — a real
  /// `GET /my-workshop/*` call — for the sole purpose of an assertion that
  /// then throws the result away. Asserts strip out of `--release` builds,
  /// so this never showed up there; it showed up as a wave of `403`s in the
  /// browser console on every sign-in/out of a debug build, because every
  /// account, workshop owner or not, was suddenly asking `/my-workshop/*`
  /// questions it had never asked before. [Ref.exists] performs the same
  /// "does an element already exist" check `_debugAssertCanDependOn` needs,
  /// without the assert and without ever creating one — so guarding with it
  /// costs nothing for an account that was never a workshop owner, and still
  /// invalidates correctly for one that was.
  void _ifBuilt(ProviderBase<Object?> provider) {
    if (_ref.exists(provider)) _ref.invalidate(provider);
  }

  /// Fetches the lists that belong to one account rather than to the platform.
  ///
  /// Separate from [refreshEverything] so `AppBootstrap` can call just this
  /// half: a cold start with a stored session has already warmed the caches on
  /// its way here, but nothing has yet asked the server for *this* user's
  /// bookings, orders or operator queue. Before this existed
  /// `OrderRepository.fetchOrders` and `ServiceMarketplaceRepository
  /// .fetchRequests` had no caller anywhere in the app, so "طلباتي" and
  /// "حجوزاتي" showed only what had been placed since the app was last opened.
  ///
  /// [includeSelfLoading] covers the two lists that already load themselves
  /// from their own `build()` — the inbox and the reviews. False at boot, where
  /// the notifiers do not exist yet and reaching for them here would only make
  /// the same request a moment earlier. True at sign-in, where they very much
  /// do exist and are holding the empty list a guest was given.
  Future<void> loadSessionLists({bool includeSelfLoading = true}) async {
    // Resolved before the batch, not inside it: the operator queue is the only
    // founder-only entry here, and reading the claim is a store read rather
    // than a round trip.
    final founder = await _isFounder();
    await Future.wait([
      _bestEffort(
        'bookings',
        () => _ref.read(requestsProvider.notifier).load(),
      ),
      _bestEffort('orders', () => _ref.read(ordersProvider.notifier).load()),
      if (includeSelfLoading) ...[
        _bestEffort(
          'inbox',
          () => _ref.read(notificationsProvider.notifier).load(),
        ),
        _bestEffort(
          'reviews',
          () => _ref.read(reviewsProvider.notifier).load(),
        ),
      ],
      // Founder-only (`GetAllRequestsQueryHandler` answers everyone else
      // `403`), so it is asked for only when the token says founder. It used
      // to be asked for unconditionally, on the grounds that the `403` *was*
      // the check — see [_isFounder] for why that was the wrong place to look.
      // Still best-effort: the claim describes the token, and only the server
      // decides.
      if (founder)
        _bestEffort(
          'operator queue',
          () => _ref.read(operatorQueueProvider.notifier).refresh(),
        ),
    ]);
  }

  /// Runs one step of the refresh and never lets it take the rest down.
  ///
  /// `401` and `403` are logged as plain lines: they are what the server says
  /// when the session expired between the sign-in and this call, or when the
  /// account is simply not a founder, and neither is a fault. Attaching an
  /// `error`/`stackTrace` to those made `developer.log` print a 25-frame dump
  /// for each, which is how an ordinary launch came to look like a stack of
  /// crashes (see the 2026-08-11 entry in `EDIT_LOG.md`). Everything else keeps
  /// its stack, because a warm-up that fails for a real reason is a screen that
  /// renders stale or empty with nothing to explain it.
  Future<void> _bestEffort(String what, Future<void> Function() step) async {
    try {
      await step();
    } on UnauthorizedException {
      developer.log(
        'Skipped $what — no session, or it expired mid-refresh',
        name: 'SessionRefresh',
      );
    } on ForbiddenException {
      developer.log(
        'Skipped $what — this session is not allowed to read it',
        name: 'SessionRefresh',
      );
    } catch (error, stack) {
      developer.log(
        'Could not refresh $what; its screens keep whatever they already had',
        name: 'SessionRefresh',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

final sessionRefreshProvider = Provider<SessionRefresh>((ref) {
  final refresh = SessionRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});
