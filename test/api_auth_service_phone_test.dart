import 'package:ak_cars_mobil_app/core/constants/api_endpoints.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/json/json_utils.dart';
import 'package:ak_cars_mobil_app/core/network/api_client.dart';
import 'package:ak_cars_mobil_app/data/models/user_profile.dart';
import 'package:ak_cars_mobil_app/data/services/api/api_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/memory_token_store.dart';
import 'fakes/offline_api_client.dart';

/// What `ApiAuthService` actually sends for phone verification, and how it
/// reads the answers. The widget tests stop at `AuthService`; this is the
/// layer that has to agree with the API's contract.
void main() {
  const profile = UserProfile(
    name: 'New Customer',
    phone: '+968 9200 0009',
    email: '',
    region: 'Muscat',
    address: '',
  );

  JsonMap session() => {
    'accessToken': 'access-1',
    'refreshToken': 'refresh-1',
    'expiresIn': 3600,
    'user': {...profile.toJson(), 'id': 'user-1'},
  };

  late _RecordingApiClient client;
  late MemoryTokenStore tokens;
  late ApiAuthService auth;

  setUp(() {
    client = _RecordingApiClient();
    tokens = MemoryTokenStore();
    auth = ApiAuthService(client, tokens, const SilentPushService());
  });

  test('register carries the phone verification token with the profile', () async {
    client.answers[ApiEndpoints.register] = session();

    await auth.register(profile, phoneVerificationToken: 'firebase-id-token');

    final body = client.bodyOf(ApiEndpoints.register);
    expect(body['phoneVerificationToken'], 'firebase-id-token');
    expect(body['phone'], profile.phone);
  });

  test('register without a token sends no token field at all', () async {
    client.answers[ApiEndpoints.register] = session();

    await auth.register(profile);

    expect(client.bodyOf(ApiEndpoints.register).containsKey('phoneVerificationToken'), isFalse);
  });

  test('the registration check posts the profile and saves no session', () async {
    await auth.validateRegistration(profile);

    expect(client.bodyOf(ApiEndpoints.registerCheck)['phone'], profile.phone);
    expect(await tokens.readAccessToken(), isNull);
  });

  test('the registration check rethrows a refusal as the same exception', () async {
    client.answers[ApiEndpoints.registerCheck] = const BusinessRuleException(
      'An account with that phone or email already exists.',
      code: 'account_already_exists',
    );

    expect(
      () => auth.validateRegistration(profile),
      throwsA(isA<BusinessRuleException>()
          .having((e) => e.code, 'code', 'account_already_exists')),
    );
  });

  test('account check reads 204 as yes and 404 as no', () async {
    expect(await auth.accountExists('+968 9200 0009'), isTrue);

    client.answers[ApiEndpoints.loginCheck] = const NotFoundException('none');
    expect(await auth.accountExists('+968 9200 0001'), isFalse);
  });

  test('phone login trades the Firebase token for a stored session', () async {
    client.answers[ApiEndpoints.loginPhone] = session();

    final user = await auth.loginWithVerifiedPhone('firebase-id-token');

    expect(client.bodyOf(ApiEndpoints.loginPhone), {'idToken': 'firebase-id-token'});
    expect(user.id, 'user-1');
    expect(await tokens.readAccessToken(), 'access-1');
  });
}

/// Records each POST and answers from [answers]: a map is returned, an
/// exception is thrown, and a missing entry is an empty `204`.
class _RecordingApiClient implements ApiClient {
  final answers = <String, Object>{};
  final posts = <String, Object?>{};

  Map<String, dynamic> bodyOf(String path) =>
      Map<String, dynamic>.from(posts[path]! as Map);

  @override
  Future<JsonMap> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    posts[path] = body;
    final answer = answers[path];
    if (answer is AppException) throw answer;
    return answer == null ? <String, dynamic>{} : answer as JsonMap;
  }

  @override
  Future<JsonMap> get(String path, {Map<String, dynamic>? queryParameters, Map<String, String>? headers}) =>
      throw UnimplementedError(path);

  @override
  Future<JsonMap> put(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) =>
      throw UnimplementedError(path);

  @override
  Future<JsonMap> patch(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) =>
      throw UnimplementedError(path);

  @override
  Future<JsonMap> delete(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) =>
      throw UnimplementedError(path);

  @override
  Future<List<JsonMap>> getList(String path, {Map<String, dynamic>? queryParameters, Map<String, String>? headers}) =>
      throw UnimplementedError(path);

  @override
  Future<List<JsonMap>> postList(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) =>
      throw UnimplementedError(path);

  @override
  Future<List<JsonMap>> putList(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) =>
      throw UnimplementedError(path);

  @override
  Future<List<JsonMap>> deleteList(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) =>
      throw UnimplementedError(path);
}