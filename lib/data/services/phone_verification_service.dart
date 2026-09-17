import '../../core/error/app_exception.dart';

/// Proves that the person using the app holds a phone number, by SMS.
///
/// The code is sent and checked by Firebase Authentication, not by the AK Cars
/// API. What comes back is a Firebase ID token naming the verified number,
/// which the API checks itself before it starts a session
/// (`POST /auth/login/phone`) or creates an account (`POST /auth/register`).
/// The app never tells the API "this number is verified" on its own word.
abstract interface class PhoneVerificationService {
  /// Whether phone verification can run on this platform (Android, iOS, web).
  /// Desktop cannot; the login screen falls back to the API's own code there.
  bool get isSupported;

  /// Texts a code to [e164Phone] (`+96892001234`).
  ///
  /// Throws [PhoneVerificationException].
  Future<PhoneVerificationSession> sendCode(String e164Phone);

  /// Checks [smsCode] against [session] and returns the Firebase ID token.
  ///
  /// Throws [PhoneVerificationException]; a mistyped code is
  /// [PhoneVerificationFailure.invalidCode].
  Future<String> confirmCode(PhoneVerificationSession session, String smsCode);
}

/// One code sent to one number.
class PhoneVerificationSession {
  const PhoneVerificationSession({
    required this.phone,
    required this.handle,
    this.idToken,
  });

  /// The number the code was sent to, in E.164.
  final String phone;

  /// Owned by the implementation: a verification id, a web confirmation.
  final Object handle;

  /// Set when the platform verified the number without the user typing a
  /// code (Android instant verification). Nothing is left to confirm.
  final String? idToken;

  bool get isAlreadyVerified => idToken != null;
}