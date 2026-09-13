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

  /// Asks the server to send a one-time code to [identifier], and reports
  /// whether an account was there to send it to.
  ///
  /// False when nothing matches — the caller offers registration instead of
  /// pretending an OTP would go anywhere. Does not start a session; [login]
  /// does that once the code has been confirmed.
  ///
  /// Was `findAccount`, returning the matched `UserProfile`. That handed the
  /// account's name, e-mail and street address to an unauthenticated caller
  /// who supplied nothing but a phone number, and no caller ever read a field
  /// of it — the login screen only checked whether it was null. The server no
  /// longer sends the profile, so there is nothing left to return but the
  /// answer to that check.
  Future<bool> requestOtp(String identifier);

  /// Verifies [code] against the OTP sent to [identifier] and, if it
  /// matches, starts the session.
  ///
  /// Callers must have already had [requestOtp] answer true
  /// — this is the step that proves the person holding the phone is that
  /// account's owner, not the step that looks the account up.
  Future<UserProfile> login(String identifier, String code);

  Future<void> signOut();
}
