import '../../../core/constants/api_endpoints.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../models/user_profile.dart';
import '../auth_service.dart';

/// Registration and session identity over REST (§12).
///
/// Both account kinds go through the same `POST /auth/register`: the body
/// carries `kind`, and a workshop's body additionally carries the `workshop`
/// object — which is exactly what [UserProfile.toJson] already emits, and why
/// there is no second endpoint here (see `docs/api_contract.md`).
class ApiAuthService implements AuthService {
  const ApiAuthService(this._client);

  final ApiClient _client;

  @override
  Future<UserProfile?> fetchCurrentUser() async {
    try {
      return UserProfile.fromJson(await _client.get(ApiEndpoints.profile));
    } on UnauthorizedException {
      // Not an error: "nobody is signed in" is the ordinary answer for a fresh
      // install, and the mock returns null for it too. Both paths must agree,
      // or the router's cold-start branch would differ between them.
      return null;
    }
  }

  @override
  Future<UserProfile> register(UserProfile profile) async =>
      UserProfile.fromJson(
        await _client.post(ApiEndpoints.register, body: profile.toJson()),
      );

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async =>
      UserProfile.fromJson(
        await _client.put(ApiEndpoints.updateProfile, body: profile.toJson()),
      );

  @override
  Future<void> signOut() => _client.post(ApiEndpoints.logout);
}
