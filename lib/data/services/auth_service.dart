import '../../core/constants/app_constants.dart';
import '../models/user_profile.dart';

/// Registration and session identity.
///
/// The app's rule is that browsing is open but *transactions* (booking,
/// checkout, publishing an ad) require a completed registration — so this
/// service deals in a [UserProfile], not a token, and the token handling
/// lands with the REST implementation.
///
/// Phase 2: implement `RestAuthService` against `/auth/register`,
/// `/auth/login` and `/auth/refresh`, persisting the JWT under
/// [AppConstants.prefsAuthToken].
abstract interface class AuthService {
  /// The profile of an already-signed-in user, or null when anonymous.
  Future<UserProfile?> fetchCurrentUser();

  /// Completes registration and returns the stored profile.
  Future<UserProfile> register(UserProfile profile);

  Future<UserProfile> updateProfile(UserProfile profile);

  /// Locates an existing account by phone or email, for the login screen.
  ///
  /// Null when nothing matches — the caller offers registration instead of
  /// pretending an OTP would go anywhere. Does not start a session; [login]
  /// does that once the code the screen showed has been confirmed.
  Future<UserProfile?> findAccount(String identifier);

  /// Verifies [code] against the OTP sent to [identifier] and, if it
  /// matches, starts the session.
  ///
  /// Callers must have already resolved [findAccount] to a non-null profile
  /// — this is the step that proves the person holding the phone is that
  /// account's owner, not the step that looks the account up.
  Future<UserProfile> login(String identifier, String code);

  Future<void> signOut();
}
