import '../../../core/constants/api_endpoints.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/json/json_utils.dart';
import '../../../core/network/api_client.dart';
import '../../../core/push/push_service.dart';
import '../../models/user_profile.dart';
import '../auth_service.dart';
import '../token_store.dart';

/// Registration and session identity over REST (§12).
///
/// Both account kinds go through the same `POST /auth/register`: the body
/// carries `kind`, and a workshop's body additionally carries the `workshop`
/// object — which is exactly what [UserProfile.toJson] already emits, and why
/// there is no second endpoint here (see `docs/api_contract.md`).
class ApiAuthService implements AuthService {
  const ApiAuthService(this._client, this._tokens, this._push);

  final ApiClient _client;
  final TokenStore _tokens;
  final PushService _push;

  @override
  Future<UserProfile?> fetchCurrentUser() async {
    // With no stored token there is no session to fetch: the request could
    // only answer `401`, and the catch below would turn that straight back
    // into the same `null` this returns now — one guaranteed-failed round trip
    // on every guest cold start, and a red line in the console for it.
    if (!await _tokens.mayHaveSession()) return null;
    try {
      return UserProfile.fromJson(await _client.get(ApiEndpoints.profile));
    } on UnauthorizedException {
      // Not an error: "nobody is signed in" is the ordinary answer for a fresh
      // install, and the mock returns null for it too. Both paths must agree,
      // or the router's cold-start branch would differ between them. Still
      // reachable above the guard: a *stored* token can be an *expired* one.
      return null;
    }
  }

  @override
  Future<UserProfile> register(
    UserProfile profile, {
    String? phoneVerificationToken,
  }) async {
    final json = await _client.post(
      ApiEndpoints.register,
      body: {
        ...profile.toJson(),
        'phoneVerificationToken': ?phoneVerificationToken,
      },
    );
    return _startSession(json);
  }

  @override
  Future<void> validateRegistration(UserProfile profile) async {
    // `204` when it would be accepted. Every refusal arrives as the same
    // exception `register` would throw, so the screen reports both one way.
    await _client.post(ApiEndpoints.registerCheck, body: profile.toJson());
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async =>
      UserProfile.fromJson(
        await _client.put(ApiEndpoints.updateProfile, body: profile.toJson()),
      );

  @override
  Future<bool> requestOtp(String identifier) async {
    try {
      // The response body is a fixed acknowledgement, and is deliberately
      // ignored. The server stopped returning the account here: anyone who
      // could guess an eight-digit Oman mobile number was being handed that
      // person's name, e-mail and street address. A 404 is still how "no such
      // account" is reported, which is all the login screen ever needed.
      await _client.post(ApiEndpoints.login, body: {'identifier': identifier});
      return true;
    } on NotFoundException {
      return false;
    }
  }

  @override
  Future<bool> accountExists(String identifier) async {
    try {
      await _client.post(
        ApiEndpoints.loginCheck,
        body: {'identifier': identifier},
      );
      return true;
    } on NotFoundException {
      return false;
    }
  }

  @override
  Future<UserProfile> loginWithVerifiedPhone(String firebaseIdToken) async {
    final json = await _client.post(
      ApiEndpoints.loginPhone,
      body: {'idToken': firebaseIdToken},
    );
    return _startSession(json);
  }

  @override
  Future<UserProfile> login(String identifier, String code) async {
    final json = await _client.post(ApiEndpoints.loginVerify, body: {
      'identifier': identifier,
      'code': code,
    });
    return _startSession(json);
  }

  Future<UserProfile> _startSession(JsonMap json) async {
    await _tokens.save(
      access: json.requireString('accessToken'),
      refresh: json.requireString('refreshToken'),
      expiresIn: json.intOr('expiresIn', 3600),
    );
    // Opens the live notification channel for this account. Not awaited on
    // purpose: a slow or unreachable hub must never hold up signing in.
    _push.start().ignore();
    return UserProfile.fromJson(json.requireObject('user'));
  }

  @override
  Future<void> signOut() async {
    try {
      // Push goes first, while the session still authenticates: it stops the
      // background service and deletes this install's push key on the
      // server, which after logout could need a refresh token already
      // revoked. It never throws. The next account on a shared phone never
      // receives this one's notifications.
      await _push.stop();
      await _client.post(ApiEndpoints.logout);
    } finally {
      // Clears the local session even when the network call above failed —
      // a logout that leaves a token behind because the server was
      // unreachable is the worst kind of bug on a shared phone.
      await _tokens.clear();
    }
  }
}
