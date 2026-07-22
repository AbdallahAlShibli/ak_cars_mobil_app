import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_profile.dart';
import '../di/providers.dart';

/// Session state.
///
/// Rule: browsing is open, but transactions (booking, checkout, publishing an
/// ad) require a completed registration.
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
  @override
  AuthState build() => const AuthState();

  void markOnboardingSeen() => state = state.copyWith(onboardingSeen: true);

  void markStartChoiceMade() => state = state.copyWith(startChoiceMade: true);

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
    try {
      final stored = await ref.read(authRepositoryProvider).register(profile);
      state = state.copyWith(profile: stored);
    } catch (_) {
      state = previous;
      rethrow;
    }
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
    await ref.read(authRepositoryProvider).signOut();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
