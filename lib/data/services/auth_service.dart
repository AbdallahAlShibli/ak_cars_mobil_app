import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../core/constants/app_constants.dart';
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

/// Stands in for the server *and* the session store.
///
/// The profile is written to SharedPreferences rather than kept in a field:
/// holding it in memory meant every cold start came back anonymous, so a
/// registered user was sent through the sign-up form again the next time they
/// tried to check out. The REST implementation restores the same way, from
/// [AppConstants.prefsAuthToken].
class MockAuthService with MockServiceBase implements AuthService {
  MockAuthService({required this.config, required this.prefs});

  @override
  final AppConfig config;

  final SharedPreferences prefs;

  @override
  Future<UserProfile?> fetchCurrentUser() {
    final raw = prefs.getString(AppConstants.prefsProfile);
    if (raw == null) return respond(null);
    try {
      return respond(
        UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      );
    } catch (_) {
      // A stored profile from an older build shouldn't wedge the app on
      // launch — drop it and come up anonymous.
      prefs.remove(AppConstants.prefsProfile);
      return respond(null);
    }
  }

  @override
  Future<UserProfile> register(UserProfile profile) => _save(profile);

  @override
  Future<UserProfile> updateProfile(UserProfile profile) => _save(profile);

  @override
  Future<void> signOut() {
    prefs.remove(AppConstants.prefsProfile);
    return respond(null);
  }

  Future<UserProfile> _save(UserProfile profile) {
    prefs.setString(AppConstants.prefsProfile, jsonEncode(profile.toJson()));
    return respond(profile);
  }
}
