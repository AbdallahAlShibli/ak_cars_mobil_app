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
  Future<void> signOut() => _service.signOut();
}
