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

    await auth.register(profile, phoneVerificationToken: 'phone-token-1');

    final body = client.bodyOf(ApiEndpoints.register);
    expect(body['phoneVerificationToken'], 'phone-token-1');
    expect(body['phone'], profile.phone);
  });

  test('register without a token sends no token field at all', () async {
    client.answers[ApiEndpoints.register] = session();

    await auth.register(profile);

    expect(client.bodyOf(ApiEndpoints.register).containsKey('phoneVerificationToken'), isFalse);
  });

  test('asking for a registration code posts the phone and saves no session', () async {
    await auth.requestRegistrationOtp(profile.phone);

    expect(client.bodyOf(ApiEndpoints.registerOtp), {'phone': profile.phone});
    expect(await tokens.readAccessToken(), isNull);
  });

  test('a number that already has an account is rethrown as that refusal', () async {
    client.answers[ApiEndpoints.registerOtp] = const BusinessRuleException(
      'An account with that phone already exists.',
      code: 'account_already_exists',
    );

    expect(
      () => auth.requestRegistrationOtp(profile.phone),
      throwsA(isA<BusinessRuleException>()
          .having((e) => e.code, 'code', 'account_already_exists')),
    );
  });

  test('a correct registration code returns the verification token and no session', () async {
    client.answers[ApiEndpoints.registerOtpVerify] = {
      'phoneVerificationToken': 'phone-token-1',
      'expiresIn': 1800,
    };

    final token = await auth.verifyRegistrationOtp(profile.phone, '4821');

    expect(client.bodyOf(ApiEndpoints.registerOtpVerify), {'phone': profile.phone, 'code': '4821'});
    expect(token, 'phone-token-1');
    expect(await tokens.readAccessToken(), isNull);
  });

  test('a wrong registration code is rethrown for the sheet to word', () async {
    client.answers[ApiEndpoints.registerOtpVerify] = const UnauthorizedException(
      'Wrong or expired code.',
      code: 'otp_invalid_or_expired',
    );

    expect(
      () => auth.verifyRegistrationOtp(profile.phone, '0000'),
      throwsA(isA<UnauthorizedException>()
          .having((e) => e.code, 'code', 'otp_invalid_or_expired')),
    );
  });

  test('a profile save carries the new phone\'s verification token only when given one', () async {
    client.putAnswer = {...profile.toJson(), 'id': 'user-1'};

    await auth.updateProfile(profile);
    expect((client.puts[ApiEndpoints.updateProfile]! as Map).containsKey('phoneVerificationToken'), isFalse);

    await auth.updateProfile(profile, phoneVerificationToken: 'phone-token-2');
    expect((client.puts[ApiEndpoints.updateProfile]! as Map)['phoneVerificationToken'], 'phone-token-2');
  });

  test('phone login posts the number and code and stores the session', () async {
    client.answers[ApiEndpoints.loginVerify] = session();

    final user = await auth.login(profile.phone, '4821');

    expect(client.bodyOf(ApiEndpoints.loginVerify), {'identifier': profile.phone, 'code': '4821'});
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

  JsonMap putAnswer = {};
  final puts = <String, Object?>{};

  @override
  Future<JsonMap> put(String path, {Object? body, Map<String, dynamic>? queryParameters, Map<String, String>? headers}) async {
    puts[path] = body;
    return putAnswer;
  }

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