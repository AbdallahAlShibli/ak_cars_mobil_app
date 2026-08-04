import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';
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

/// Stands in for the server *and* the session store.
///
/// The profile is written to SharedPreferences rather than kept in a field:
/// holding it in memory meant every cold start came back anonymous, so a
/// registered user was sent through the sign-up form again the next time they
/// tried to check out. The REST implementation restores the same way, from
/// [AppConstants.prefsAuthToken].
///
/// [AppConstants.prefsProfile] and "is there a *session*" are deliberately two
/// separate facts: signing out used to delete the profile outright, which
/// modelled "log out" as "forget this account ever existed" and made login
/// impossible to demo — there was nothing left to log back into. Now sign-out
/// only flips [AppConstants.prefsSessionActive] off; the account stays on the
/// device exactly as a real backend would keep it in its database.
class MockAuthService with MockServiceBase implements AuthService {
  MockAuthService({required this.config, required this.prefs});

  @override
  final AppConfig config;

  final SharedPreferences prefs;

  @override
  Future<UserProfile?> fetchCurrentUser() async {
    if (!(prefs.getBool(AppConstants.prefsSessionActive) ?? false)) {
      return respond(null);
    }
    return respond(await _readStoredAccount());
  }

  @override
  Future<UserProfile> register(UserProfile profile) => _save(profile);

  @override
  Future<UserProfile> updateProfile(UserProfile profile) => _save(profile);

  @override
  Future<UserProfile?> findAccount(String identifier) async {
    final account = await _readStoredAccount();
    if (account == null) return respond(null);
    return respond(_matches(account, identifier) ? account : null);
  }

  @override
  Future<UserProfile> login(String identifier, String code) async {
    final account = await _readStoredAccount();
    if (account == null || !_matches(account, identifier)) {
      throw const NotFoundException('No account matches that identifier');
    }
    // The mock has no OTP of its own to check against — the login screen
    // already compared [code] to the staging code it displayed, the same way
    // the register screen does. `code` is threaded through only so the API
    // implementation has somewhere real to put it.
    await prefs.setBool(AppConstants.prefsSessionActive, true);
    return respond(account);
  }

  @override
  Future<void> signOut() {
    prefs.setBool(AppConstants.prefsSessionActive, false);
    return respond(null);
  }

  Future<UserProfile> _save(UserProfile profile) async {
    await prefs.setString(
        AppConstants.prefsProfile, jsonEncode(profile.toJson()));
    await prefs.setBool(AppConstants.prefsSessionActive, true);
    return respond(profile);
  }

  Future<UserProfile?> _readStoredAccount() async {
    final raw = prefs.getString(AppConstants.prefsProfile);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A stored profile from an older build shouldn't wedge the app on
      // launch — drop it and come up anonymous.
      await prefs.remove(AppConstants.prefsProfile);
      await prefs.setBool(AppConstants.prefsSessionActive, false);
      return null;
    }
  }

  /// Whether [identifier] — typed as a phone or an email, in any of the
  /// formats the register screen accepts — names [account].
  ///
  /// Oman-local phone digits so "+968 9200 1234", "96892001234" and
  /// "9200 1234" all compare equal; case/whitespace-insensitive on email.
  static bool _matches(UserProfile account, String identifier) {
    final raw = identifier.trim();
    if (raw.isEmpty) return false;
    if (raw.contains('@')) {
      return raw.toLowerCase() == account.email.trim().toLowerCase();
    }
    String local(String v) {
      final digits = v.replaceAll(RegExp(r'\D'), '');
      return digits.startsWith('968') ? digits.substring(3) : digits;
    }

    return local(raw) == local(account.phone);
  }
}
