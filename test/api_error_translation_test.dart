import 'dart:convert';
import 'dart:io';

import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/network/dio_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/memory_token_store.dart';

/// What the transport turns the server's failures into.
///
/// This is the half the login screen's own tests cannot see: if `_translate`
/// stopped carrying the envelope's `code`, or stopped recognising `429`, the
/// screen would quietly fall back to "could not log in — try again" and every
/// widget test would still pass.
///
/// Driven by a real socket rather than a stubbed adapter, because the shapes
/// being asserted are the real API's: RFC 9110 problem+json for a `401`, and
/// **plain text** from the IP rate limiter for a `429` — a difference that a
/// hand-written stub would be free to get wrong.
void main() {
  late HttpServer server;
  late DioApiClient client;

  /// What the next request will be answered with.
  late int status;
  late String body;
  late String contentType;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.parse(contentType);
      request.response.write(body);
      await request.response.close();
    });
    client = DioApiClient(
      config: AppConfig.forEnvironment(AppEnvironment.development)
          .copyWith(apiBaseUrl: 'http://127.0.0.1:${server.port}'),
      tokens: MemoryTokenStore(),
    );
    addTearDown(() => server.close(force: true));
  });

  test('a 401 carries the envelope code through to the caller', () async {
    status = 401;
    contentType = 'application/problem+json';
    body = jsonEncode({
      'title': 'otp_invalid_or_expired',
      'status': 401,
      'detail': 'Wrong or expired code.',
      'code': 'otp_invalid_or_expired',
    });

    await expectLater(
      client.post('/auth/login/verify'),
      throwsA(
        isA<UnauthorizedException>()
            .having((e) => e.code, 'code', 'otp_invalid_or_expired')
            .having((e) => e.message, 'message', 'Wrong or expired code.'),
      ),
    );
  });

  test('a 401 with no code still reads as unauthorized', () async {
    status = 401;
    contentType = 'application/problem+json';
    body = jsonEncode({'title': 'unauthorized', 'status': 401});

    await expectLater(
      client.get('/user/profile'),
      throwsA(isA<UnauthorizedException>().having((e) => e.code, 'code', isNull)),
    );
  });

  test('a plain-text 429 is a rate limit, not an unclassified failure',
      () async {
    // Verbatim what AspNetCoreRateLimit returns — no JSON envelope at all.
    status = 429;
    contentType = 'text/plain';
    body = 'API calls quota exceeded! maximum admitted 5 per 1m.';

    await expectLater(
      client.post('/auth/login'),
      throwsA(isA<RateLimitedException>()),
    );
  });

  test('a 403 is still forbidden, not a rate limit', () async {
    status = 403;
    contentType = 'application/problem+json';
    body = jsonEncode({'title': 'forbidden', 'status': 403});

    await expectLater(
      client.get('/service-marketplace/payouts'),
      throwsA(isA<ForbiddenException>()),
    );
  });
}
