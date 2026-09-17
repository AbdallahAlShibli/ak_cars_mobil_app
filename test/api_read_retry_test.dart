import 'dart:convert';
import 'dart:io';

import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/network/dio_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/memory_token_store.dart';

/// Reads that stall are asked again; writes never are (2026-09-15).
///
/// Through the Cloudflare tunnel an ordinary request answers in about a
/// second, but one occasionally stalls for 17–48 s while the next attempt
/// answers at once. A real socket that stalls on command stands in for it.
void main() {
  late HttpServer server;
  late int requests;

  /// Which attempts (1-based) the server sits on before answering.
  late Set<int> stalledAttempts;

  const stall = Duration(seconds: 1);

  setUp(() async {
    requests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final attempt = ++requests;
      try {
        if (stalledAttempts.contains(attempt)) {
          await Future<void>.delayed(stall);
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.method == 'GET'
                ? [
                    {'attempt': attempt},
                  ]
                : {'attempt': attempt},
          ),
        );
        await request.response.close();
      } on Object {
        // The client gave up on this attempt and closed the connection.
      }
    });
    addTearDown(() => server.close(force: true));
  });

  DioApiClient client() => DioApiClient(
    config: AppConfig.forEnvironment(AppEnvironment.development).copyWith(
      apiBaseUrl: 'http://127.0.0.1:${server.port}',
      readTimeout: const Duration(milliseconds: 200),
      receiveTimeout: const Duration(milliseconds: 300),
      readRetries: 2,
    ),
    tokens: MemoryTokenStore(),
  );

  test('a read that stalls is asked again and answers', () async {
    stalledAttempts = {1};

    final rows = await client().getList('/cars');

    expect(rows, [
      {'attempt': 2},
    ]);
    expect(requests, 2);
  });

  test(
    'a read that keeps stalling gives up after the configured retries',
    () async {
      stalledAttempts = {1, 2, 3};

      await expectLater(
        client().getList('/cars'),
        throwsA(isA<RequestTimeoutException>()),
      );
      expect(requests, 3);
    },
  );

  test('a write that stalls is never sent twice', () async {
    stalledAttempts = {1};

    await expectLater(
      client().post('/orders', body: {'items': []}),
      throwsA(isA<RequestTimeoutException>()),
    );
    // Long enough for a retry to have arrived, had one been sent.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(requests, 1);
  });
}
