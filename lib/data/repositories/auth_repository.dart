import '../models/user_profile.dart';
import '../services/auth_service.dart';

/// Registration and session identity.
///
/// Browsing is open; transactions require [UserProfile] to be present. The
/// repository keeps the "is there a session?" question in one place so no
/// screen has to reason about tokens.
abstract interface class AuthRepository {
  Future<UserProfile?> currentUser();

  Future<UserProfile> register(UserProfile profile);

  Future<UserProfile> updateProfile(UserProfile profile);

  /// Locates an existing account by phone or email for the login screen.
  /// Null when nothing matches.
  Future<UserProfile?> findAccount(String identifier);

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
  Future<UserProfile> register(UserProfile profile) =>
      _service.register(profile);

  @override
  Future<UserProfile> updateProfile(UserProfile profile) =>
      _service.updateProfile(profile);

  @override
  Future<UserProfile?> findAccount(String identifier) =>
      _service.findAccount(identifier);

  @override
  Future<UserProfile> login(String identifier, String code) =>
      _service.login(identifier, code);

  @override
  Future<void> signOut() => _service.signOut();
}
