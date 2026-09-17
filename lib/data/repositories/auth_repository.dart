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

  /// Every server-side registration rule, saving nothing.
  Future<void> validateRegistration(UserProfile profile);

  Future<UserProfile> updateProfile(UserProfile profile);

  /// Sends a one-time code to [identifier]; false when no account matched.
  Future<bool> requestOtp(String identifier);

  /// Whether an account uses [identifier]. Sends nothing.
  Future<bool> accountExists(String identifier);

  /// Verifies [code] and starts the session for the account [identifier]
  /// resolves to.
  Future<UserProfile> login(String identifier, String code);

  /// Starts the session for the account whose phone Firebase verified.
  Future<UserProfile> loginWithVerifiedPhone(String firebaseIdToken);

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
  Future<void> validateRegistration(UserProfile profile) =>
      _service.validateRegistration(profile);

  @override
  Future<UserProfile> updateProfile(UserProfile profile) =>
      _service.updateProfile(profile);

  @override
  Future<bool> requestOtp(String identifier) =>
      _service.requestOtp(identifier);

  @override
  Future<bool> accountExists(String identifier) =>
      _service.accountExists(identifier);

  @override
  Future<UserProfile> login(String identifier, String code) =>
      _service.login(identifier, code);

  @override
  Future<UserProfile> loginWithVerifiedPhone(String firebaseIdToken) =>
      _service.loginWithVerifiedPhone(firebaseIdToken);

  @override
  Future<void> signOut() => _service.signOut();
}