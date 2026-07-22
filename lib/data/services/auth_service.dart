import '../../config/app_config.dart';
import '../models/user_profile.dart';
import 'mock_service_base.dart';

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

  Future<void> signOut();
}

/// Holds the registered profile in memory for the length of the session.
class MockAuthService with MockServiceBase implements AuthService {
  MockAuthService({required this.config});

  @override
  final AppConfig config;

  UserProfile? _current;

  @override
  Future<UserProfile?> fetchCurrentUser() => respond(_current);

  @override
  Future<UserProfile> register(UserProfile profile) {
    _current = profile;
    return respond(profile);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) {
    _current = profile;
    return respond(profile);
  }

  @override
  Future<void> signOut() {
    _current = null;
    return respond(null);
  }
}
