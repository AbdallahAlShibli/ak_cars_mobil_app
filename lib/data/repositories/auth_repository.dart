import '../models/user_profile.dart';
import '../services/auth_service.dart';

/// Registration and session identity.
///
/// Browsing is open; transactions require [UserProfile] to be present. The
/// repository keeps the "is there a session?" question in one place so no
/// screen has to reason about tokens.
abstract interface class AuthRepository {
  Future<UserProfile?> currentUser();

  /// [phoneVerificationToken]: see [AuthService.register].
  Future<UserProfile> register(
    UserProfile profile, {
    String? phoneVerificationToken,
  });

  /// Texts a registration code to [phone]; see [AuthService.requestRegistrationOtp].
  Future<void> requestRegistrationOtp(String phone);

  /// The phone verification token for a correct code; see
  /// [AuthService.verifyRegistrationOtp].
  Future<String> verifyRegistrationOtp(String phone, String code);

  /// [phoneVerificationToken]: see [AuthService.updateProfile].
  Future<UserProfile> updateProfile(
    UserProfile profile, {
    String? phoneVerificationToken,
  });

  /// Sends a one-time code to [identifier]; false when no account matched.
  Future<bool> requestOtp(String identifier);

  /// Verifies [code] and starts the session for the account [identifier]
  /// resolves to.
  Future<UserProfile> login(String identifier, String code);

  Future<void> signOut();
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._service);

  final AuthService _service;

  @override
  Future<UserProfile?> currentUser() => _service.fetchCurrentUser();

  @override
  Future<UserProfile> register(
    UserProfile profile, {
    String? phoneVerificationToken,
  }) => _service.register(
    profile,
    phoneVerificationToken: phoneVerificationToken,
  );

  @override
  Future<void> requestRegistrationOtp(String phone) =>
      _service.requestRegistrationOtp(phone);

  @override
  Future<String> verifyRegistrationOtp(String phone, String code) =>
      _service.verifyRegistrationOtp(phone, code);

  @override
  Future<UserProfile> updateProfile(
    UserProfile profile, {
    String? phoneVerificationToken,
  }) => _service.updateProfile(
    profile,
    phoneVerificationToken: phoneVerificationToken,
  );

  @override
  Future<bool> requestOtp(String identifier) => _service.requestOtp(identifier);

  @override
  Future<UserProfile> login(String identifier, String code) =>
      _service.login(identifier, code);

  @override
  Future<void> signOut() => _service.signOut();
}
