import 'dart:async' show unawaited;
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_flags.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/jwt_claims.dart';
import '../data/models/service_provider.dart';
import '../data/models/user_profile.dart';
import '../data/models/workshop_application.dart';
import '../di/providers.dart';
import 'session_refresh.dart';

/// Session state.
///
/// Rule: browsing is open, but transactions (booking, checkout, publishing an
/// ad) require a completed registration.
///
/// [onboardingSeen] and [startChoiceMade] are *installation* facts, not
/// account facts: they gate the first-launch flow and are persisted to
/// SharedPreferences so a cold start does not replay the intro.
class AuthState {
  const AuthState({
    this.profile,
    this.onboardingSeen = false,
    this.startChoiceMade = false,
    this.isFounder = false,
  });

  final UserProfile? profile;
  final bool onboardingSeen;
  final bool startChoiceMade;

  /// Whether the stored access token carries the backend's `founder` role
  /// claim — see `jwt_claims.dart`. Decoded once per session (restore,
  /// login, register) rather than re-read on every guard check, the same way
  /// [profile] is cached rather than re-fetched from the server each time.
  final bool isFounder;

  bool get isRegistered => profile != null;

  /// Where a cold start belongs: the intro runs once, then the app opens on
  /// its first tab. Kept here rather than in the router so the rule has one
  /// home and can be unit-tested without building a navigator.
  ///
  /// The destination is [AppFlags.startLocation] rather than a literal, so it
  /// can never name a tab the current build does not register.
  String get initialRoute {
    if (!onboardingSeen) return '/splash';
    if (!startChoiceMade) return '/start-choice';
    return AppFlags.startLocation;
  }

  AuthState copyWith({
    UserProfile? profile,
    bool? onboardingSeen,
    bool? startChoiceMade,
    bool? isFounder,
  }) =>
      AuthState(
        profile: profile ?? this.profile,
        onboardingSeen: onboardingSeen ?? this.onboardingSeen,
        startChoiceMade: startChoiceMade ?? this.startChoiceMade,
        isFounder: isFounder ?? this.isFounder,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  /// Whether this notifier has been torn down.
  ///
  /// [_adoptGuestDataThenWarm] is deliberately fire-and-forget, so it can
  /// still be running when the container goes away. Reading `ref` after that
  /// throws a bare `StateError` into the zone with nobody to catch it, which
  /// is not something a best-effort background upload should be able to do.
  bool _disposed = false;

  /// Bumped by [register], [login] and [signOut] — every operation that
  /// starts a fire-and-forget [SessionRefresh] call. [generation] is how that
  /// call later asks "is anything newer than me now in charge", so its own
  /// completion cannot land on top of a session that has already moved on.
  ///
  /// **The bug this exists to fix, not a defence against one that might
  /// happen:** sign out then sign back in in quick succession — the two
  /// realistic ways this occurs are a fast tap on the login screen right
  /// after signing out, and this file's own tests doing exactly that back to
  /// back. `signOut`'s refresh clears `requestsProvider`/`ordersProvider`;
  /// `login`'s refresh reloads them for the new account. Fire-and-forget on
  /// both sides means whichever finishes *last* wins, not whichever started
  /// *last* — and if the sign-out's clear lands after the sign-in's load,
  /// the new account's own bookings and orders vanish from underneath it.
  /// `SessionRefresh` checks [generation] before its own side-effecting
  /// steps and bails out silently if it has been superseded, so only the
  /// most recent call is ever allowed to finish.
  int _generation = 0;

  int get generation => _generation;

  @override
  AuthState build() {
    ref.onDispose(() => _disposed = true);
    return AuthState(
      onboardingSeen: _prefs.getBool(AppConstants.prefsOnboardingSeen) ?? false,
      startChoiceMade:
          _prefs.getBool(AppConstants.prefsStartChoiceMade) ?? false,
    );
  }

  /// Re-attaches the stored profile after a cold start.
  ///
  /// Called once from bootstrap, before the first frame. Without it the app
  /// came up anonymous every launch: the profile only ever lived in memory,
  /// so a user who had registered was asked to register again at the next
  /// checkout.
  Future<void> restore() async {
    final stored = await ref.read(authRepositoryProvider).currentUser();
    if (stored != null) {
      state = state.copyWith(profile: stored, isFounder: await _readIsFounder());
    }
  }

  /// Decodes the founder claim off whatever access token is currently
  /// stored. Called after every call that can start or restore a session —
  /// see [restore], [login] and [register] — never on a timer or a guard
  /// check, so a guard reads [AuthState.isFounder] synchronously.
  Future<bool> _readIsFounder() async =>
      jwtHasFounderRole(await ref.read(tokenStoreProvider).tryReadAccessToken());

  void markOnboardingSeen() {
    state = state.copyWith(onboardingSeen: true);
    _prefs.setBool(AppConstants.prefsOnboardingSeen, true);
  }

  void markStartChoiceMade() {
    state = state.copyWith(startChoiceMade: true);
    _prefs.setBool(AppConstants.prefsStartChoiceMade, true);
  }

  /// Applies the registration optimistically, then persists it.
  ///
  /// The state is set before the first `await` on purpose: the register
  /// screen pops back to the gated action as soon as this returns control,
  /// and that action re-reads [authProvider] synchronously. Rolling back on
  /// failure keeps the optimism honest.
  Future<void> register(UserProfile profile) async {
    final previous = state;
    state = state.copyWith(
      profile: profile,
      onboardingSeen: true,
      startChoiceMade: true,
    );
    // Someone who registered has, by definition, finished the intro — even if
    // they reached the form from a deep link rather than from onboarding.
    _markFirstRunDone();
    try {
      final stored = await ref.read(authRepositoryProvider).register(profile);
      state = state.copyWith(profile: stored, isFounder: await _readIsFounder());

      // §11 step 1: a workshop account files its application *as part of
      // registering*, not as a follow-up the user could abandon halfway. If it
      // were a second step, an account could exist as `kind: workshop` with no
      // application behind it — a workshop the founder has never been asked
      // about and that the owner believes they submitted.
      //
      // It runs after `register` rather than beside it only because the
      // application has to be filed against the id the server assigns; the two
      // are one operation from the user's point of view and one failure
      // rolls both back.
      final application = stored.workshop;
      if (application != null) {
        await ref
            .read(serviceMarketplaceRepositoryProvider)
            .submitWorkshopApplication(
              ownerUserId: stored.id ?? stored.phone,
              application: application,
              region: stored.region,
            );
      }
      _adoptGuestDataThenWarm(++_generation);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Locates an existing account for the login screen. Null when nothing
  /// matches — the screen offers registration instead.
  Future<UserProfile?> findAccount(String identifier) =>
      ref.read(authRepositoryProvider).findAccount(identifier);

  /// Starts the session once the login screen has verified its OTP.
  ///
  /// Mirrors [register]'s optimism/rollback shape: the caller pops back to
  /// wherever login was reached from as soon as this returns, so the state
  /// is set before the round-trip settles, not after.
  Future<void> login(String identifier, String code) async {
    final previous = state;
    try {
      final stored =
          await ref.read(authRepositoryProvider).login(identifier, code);
      state = state.copyWith(
        profile: stored,
        onboardingSeen: true,
        startChoiceMade: true,
        isFounder: await _readIsFounder(),
      );
      // A returning user has, by definition, finished the intro — same
      // reasoning as [register].
      _markFirstRunDone();
      _adoptGuestDataThenWarm(++_generation);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Hands the server whatever this device built while nobody was signed in,
  /// then re-reads the entire app for the account that now owns it.
  ///
  /// Ordered, and that order is the point: a guest registers their car as step
  /// 3 of 3 of first launch, so by the time they reach this the device may hold
  /// a garage and its maintenance books that the account has never seen.
  /// Refreshing first would pull the server's empty garage over them and the
  /// car would be gone — which is exactly the bug that made a first-run car
  /// vanish on the next cold start.
  ///
  /// What "the rest" means lives in [SessionRefresh], not here. It used to be a
  /// list of four warm-ups in this file, chosen as "the ones bootstrap had to
  /// skip without a session" — which left the parts of the app that *had* been
  /// warmed showing the guest's view of the world to a signed-in user, and left
  /// the bookings, orders, inbox and reviews unfetched entirely.
  ///
  /// Best-effort, and deliberately unawaited: the session is already committed
  /// by the time this runs, so a failure must not block navigation away from
  /// the auth screen. Nothing is lost by failing — the local copy is only
  /// dropped once its upload succeeded, so the next sign-in picks up where this
  /// left off.
  void _adoptGuestDataThenWarm(int generation) {
    Future(() async {
      if (_disposed) return;
      for (final adopter in ref.read(guestDataAdoptersProvider)) {
        try {
          await adopter.adoptGuestData();
        } catch (error, stack) {
          developer.log(
            'Could not hand this device\'s guest data to the new session',
            name: 'AuthNotifier',
            error: error,
            stackTrace: stack,
          );
        }
        if (_disposed) return;
      }
      await ref
          .read(sessionRefreshProvider)
          .refreshEverything(generation: generation);
    });
  }

  /// Re-files a rejected workshop application after the owner corrected it
  /// (§11 step 5).
  ///
  /// Puts the workshop back to [ProviderOnboardingStage.documentsSubmitted], so
  /// it reappears in the founder's pipeline exactly as a first submission does.
  /// Deliberately the same repository call as the original: a re-submission is
  /// the same act with the same rules, and a second path would be a second
  /// place for those rules to drift.
  Future<void> resubmitWorkshopApplication(
    WorkshopApplication application,
  ) async {
    final profile = state.profile;
    if (profile == null) return;
    final updated = profile.copyWith(workshop: application);
    state = state.copyWith(profile: updated);

    await ref.read(authRepositoryProvider).updateProfile(updated);
    await ref
        .read(serviceMarketplaceRepositoryProvider)
        .submitWorkshopApplication(
          ownerUserId: updated.id ?? updated.phone,
          application: application,
          region: updated.region,
        );
  }

  /// Saves edits to an already-registered profile.
  ///
  /// Separate from [register] because editing is not a re-registration: the
  /// account keeps its id, and the details screen must not put the user
  /// through OTP again for changing an address. The repository has had
  /// `updateProfile` since the start — nothing was calling it, which is why
  /// "My details" could only ever re-run the sign-up form.
  Future<void> updateProfile(UserProfile profile) async {
    final previous = state;
    // Keep the server-assigned id: the form has no field for it, so a bare
    // copy would silently detach the profile from its account.
    final merged = profile.copyWith(id: profile.id ?? previous.profile?.id);
    state = state.copyWith(profile: merged);
    try {
      final stored = await ref.read(authRepositoryProvider).updateProfile(merged);
      state = state.copyWith(profile: stored);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Clears the identity but keeps onboarding done — signing out drops the
  /// user back to browsing, not through the intro again.
  ///
  /// The repository call is awaited before the refresh starts: it is what
  /// clears the stored token, and [SessionRefresh.clearAfterSignOut] relies on
  /// that having already happened — its own re-warmed notifiers check for a
  /// session before fetching anything, and must see none.
  ///
  /// **Never lets that call's own failure skip the refresh.** `ApiAuthService.
  /// signOut()` clears the token in its own `finally` regardless of whether
  /// `POST /auth/logout` succeeded — an access token that had already expired
  /// answers that call `401`, which is an ordinary thing to happen to a
  /// session old enough that its owner is signing out of it. Before this, an
  /// uncaught throw here meant the line below never ran: the token was gone
  /// but every screen — garage, inbox, bookings, orders — kept showing the
  /// departed account's data, because nothing ever told their providers to
  /// clear or re-fetch. Logged rather than silently swallowed, the same rule
  /// [SessionRefresh._bestEffort] follows.
  ///
  /// The refresh itself is fire-and-forget, the same as sign-in's
  /// [_adoptGuestDataThenWarm]: the state above is already committed and the
  /// screen behind "sign out" is already showing a guest's shell, so a slow or
  /// failed refresh must not hold that up — it would just leave a screen
  /// showing the previous account's data a moment longer, not sign the user
  /// back in.
  Future<void> signOut() async {
    final generation = ++_generation;
    state = const AuthState(onboardingSeen: true, startChoiceMade: true);
    _markFirstRunDone();
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error, stack) {
      developer.log(
        'Sign-out call failed; the token is still cleared and the app still '
        'refreshes as signed-out',
        name: 'AuthNotifier',
        error: error,
        stackTrace: stack,
      );
    }
    if (_disposed) return;
    unawaited(
      ref.read(sessionRefreshProvider).clearAfterSignOut(generation: generation),
    );
  }

  void _markFirstRunDone() {
    _prefs.setBool(AppConstants.prefsOnboardingSeen, true);
    _prefs.setBool(AppConstants.prefsStartChoiceMade, true);
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
