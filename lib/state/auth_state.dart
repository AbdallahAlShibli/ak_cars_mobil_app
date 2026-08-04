import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_flags.dart';
import '../core/constants/app_constants.dart';
import '../data/models/service_provider.dart';
import '../data/models/user_profile.dart';
import '../data/models/workshop_application.dart';
import '../di/providers.dart';

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
  });

  final UserProfile? profile;
  final bool onboardingSeen;
  final bool startChoiceMade;

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
  }) =>
      AuthState(
        profile: profile ?? this.profile,
        onboardingSeen: onboardingSeen ?? this.onboardingSeen,
        startChoiceMade: startChoiceMade ?? this.startChoiceMade,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AuthState build() => AuthState(
        onboardingSeen:
            _prefs.getBool(AppConstants.prefsOnboardingSeen) ?? false,
        startChoiceMade:
            _prefs.getBool(AppConstants.prefsStartChoiceMade) ?? false,
      );

  /// Re-attaches the stored profile after a cold start.
  ///
  /// Called once from bootstrap, before the first frame. Without it the app
  /// came up anonymous every launch: the profile only ever lived in memory,
  /// so a user who had registered was asked to register again at the next
  /// checkout.
  Future<void> restore() async {
    final stored = await ref.read(authRepositoryProvider).currentUser();
    if (stored != null) state = state.copyWith(profile: stored);
  }

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
      state = state.copyWith(profile: stored);

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
      );
      // A returning user has, by definition, finished the intro — same
      // reasoning as [register].
      _markFirstRunDone();
    } catch (_) {
      state = previous;
      rethrow;
    }
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
  Future<void> signOut() async {
    state = const AuthState(onboardingSeen: true, startChoiceMade: true);
    _markFirstRunDone();
    await ref.read(authRepositoryProvider).signOut();
  }

  void _markFirstRunDone() {
    _prefs.setBool(AppConstants.prefsOnboardingSeen, true);
    _prefs.setBool(AppConstants.prefsStartChoiceMade, true);
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
