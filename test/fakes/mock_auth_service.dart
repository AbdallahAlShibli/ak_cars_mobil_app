import 'dart:convert';

import 'package:ak_cars_mobil_app/core/constants/app_constants.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/data/models/user_profile.dart';
import 'package:ak_cars_mobil_app/data/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_service_base.dart';

/// Stands in for the server *and* the session store.
///
/// The profile is written to SharedPreferences rather than kept in a field so
/// a test can assert that a registered user survives a cold start, which is
/// what `ApiAuthService` gets from its refresh token.
///
/// [AppConstants.prefsProfile] and "is there a *session*" are deliberately two
/// separate facts: signing out only flips [AppConstants.prefsSessionActive]
/// off; the account stays on the device exactly as a real backend would keep
/// it in its database, so there is something left to log back into.
class MockAuthService with MockServiceBase implements AuthService {
  MockAuthService({required this.prefs});

  final SharedPreferences prefs;

  @override
  Future<UserProfile?> fetchCurrentUser() async {
    if (!(prefs.getBool(AppConstants.prefsSessionActive) ?? false)) {
      return respond(null);
    }
    return respond(await _readStoredAccount());
  }

  /// The phone verification token the last [register] carried.
  String? lastPhoneVerificationToken;

  @override
  Future<UserProfile> register(
    UserProfile profile, {
    String? phoneVerificationToken,
  }) {
    lastPhoneVerificationToken = phoneVerificationToken;
    return _save(profile);
  }

  /// The only registration code [verifyRegistrationOtp] accepts.
  static const validRegistrationCode = '1234';

  /// The verification token a correct code returns: it names the phone, so a
  /// test can check the token that rode along with [register].
  static String tokenFor(String phone) => 'phone-verified:$phone';

  /// Every number a registration code was "texted" to, in order.
  final registrationCodesSentTo = <String>[];

  /// Refuses a phone that already has the stored account, the way
  /// `POST /auth/register/otp` answers `409 account_already_exists`.
  @override
  Future<void> requestRegistrationOtp(String phone) async {
    final account = await _readStoredAccount();
    if (account != null && _matches(account, phone)) {
      throw const BusinessRuleException(
        'An account with that phone already exists.',
        code: 'account_already_exists',
      );
    }
    registrationCodesSentTo.add(phone);
    return respond(null);
  }

  @override
  Future<String> verifyRegistrationOtp(String phone, String code) async {
    if (code != validRegistrationCode) {
      throw const UnauthorizedException(
        'Wrong or expired code.',
        code: 'otp_invalid_or_expired',
      );
    }
    return respond(tokenFor(phone));
  }

  /// The phone verification token the last [updateProfile] carried.
  String? lastProfileUpdateToken;

  /// Refuses a changed phone with no proof, the way `PUT /user/profile`
  /// answers `422 phone_verification_required`.
  @override
  Future<UserProfile> updateProfile(
    UserProfile profile, {
    String? phoneVerificationToken,
  }) async {
    lastProfileUpdateToken = phoneVerificationToken;
    final account = await _readStoredAccount();
    if (account != null &&
        !_matches(account, profile.phone) &&
        phoneVerificationToken != tokenFor(profile.phone)) {
      throw const BusinessRuleException(
        'Verify the phone number first.',
        code: 'phone_verification_required',
      );
    }
    return _save(profile);
  }

  @override
  Future<bool> requestOtp(String identifier) async {
    final account = await _readStoredAccount();
    if (account == null) return respond(false);
    return respond(_matches(account, identifier));
  }

  @override
  Future<UserProfile> login(String identifier, String code) async {
    final account = await _readStoredAccount();
    if (account == null || !_matches(account, identifier)) {
      throw const NotFoundException('No account matches that identifier');
    }
    // No OTP of its own to check against — `code` is threaded through only so
    // the API implementation has somewhere real to put it.
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
