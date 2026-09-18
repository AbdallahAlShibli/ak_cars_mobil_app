import 'dart:convert';
import 'dart:io';

import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/network/app_signer.dart';
import 'package:ak_cars_mobil_app/core/network/dio_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/memory_token_store.dart';

/// Every API request is signed so the API can refuse anything that is not
/// this app (2026-09-18, the API's `AppSignatureMiddleware`).
void main() {
  const secret = 'test-secret-0123456789abcdef';

  test('the signature is the one the API computes for the same request', () {
    // Computed independently with Python's hmac module; the API's own tests
    // check its Sign() against the same value.
    final signer = AppSigner(clientId: 'test-app', secret: secret);

    expect(
      signer.sign(
        'get',
        '/api/v1/services?q=%D8%B2%D9%8A%D8%AA',
        '1758200000',
        '00112233445566778899aabbccddeeff',
      ),
      '90adca6f488785716fddd457e796814b91cad1f95c67e670d4496a435ac206b9',
    );
  });

  test('the signed target is the path and query as sent, never the host', () {
    expect(
      AppSigner.targetOf(Uri.parse('https://api.example/api/v1/cars?page=2')),
      '/api/v1/cars?page=2',
    );
    expect(AppSigner.targetOf(Uri.parse('https://api.example')), '/');
  });

  test('two requests never share a nonce', () {
    final signer = AppSigner(clientId: 'test-app', secret: secret);
    final uri = Uri.parse('https://api.example/api/v1/cars');

    final a = signer.headersFor('GET', uri)[AppSigner.nonceHeader];
    final b = signer.headersFor('GET', uri)[AppSigner.nonceHeader];

    expect(a, hasLength(32));
    expect(a, isNot(b));
  });

  group('through the real client', () {
    late HttpServer server;
    late List<HttpHeaders> received;
    late List<Uri> targets;

    /// What the server's clock says, in unix seconds.
    late int serverNow;

    setUp(() async {
      received = [];
      targets = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        received.add(request.headers);
        targets.add(request.uri);
        final sentAt = int.tryParse(
          request.headers.value(AppSigner.timestampHeader) ?? '',
        );
        request.response.headers.contentType = ContentType.json;
        if (sentAt != null && (sentAt - serverNow).abs() > 300) {
          request.response.statusCode = 403;
          request.response.headers.set(AppSigner.serverTimeHeader, '$serverNow');
          request.response.write(jsonEncode({'code': AppSigner.clockSkewCode}));
        } else {
          request.response.write(jsonEncode({'ok': true}));
        }
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
    });

    DioApiClient client(AppSigner? signer) => DioApiClient(
      config: AppConfig.forEnvironment(
        AppEnvironment.development,
      ).copyWith(apiBaseUrl: 'http://127.0.0.1:${server.port}/api/v1'),
      tokens: MemoryTokenStore(),
      signer: signer,
    );

    test('each request carries a signature over what the server received', () async {
      serverNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signer = AppSigner(clientId: 'test-app', secret: secret);

      await client(signer).get('/services', queryParameters: {'q': 'زيت'});

      final headers = received.single;
      final target = AppSigner.targetOf(targets.single);
      expect(target, startsWith('/api/v1/services?q=%'));
      expect(headers.value(AppSigner.clientHeader), 'test-app');
      expect(
        headers.value(AppSigner.signatureHeader),
        signer.sign(
          'GET',
          target,
          headers.value(AppSigner.timestampHeader)!,
          headers.value(AppSigner.nonceHeader)!,
        ),
      );
    });

    test('a device clock an hour behind is corrected from the API and retried once', () async {
      serverNow = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

      final body = await client(
        AppSigner(clientId: 'test-app', secret: secret),
      ).get('/cars');

      expect(body, {'ok': true});
      expect(received, hasLength(2));
      final retriedAt = int.parse(received.last.value(AppSigner.timestampHeader)!);
      expect((retriedAt - serverNow).abs(), lessThan(5));
      // A fresh nonce for the retry: the API would refuse a repeated one.
      expect(
        received.last.value(AppSigner.nonceHeader),
        isNot(received.first.value(AppSigner.nonceHeader)),
      );
    });

    test('a build without a secret sends no signature at all', () async {
      serverNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await client(null).get('/cars');

      expect(received.single.value(AppSigner.signatureHeader), isNull);
    });
  });
}
