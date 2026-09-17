import 'dart:convert';
import 'dart:io';

import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/network/dio_api_client.dart';
import 'package:ak_cars_mobil_app/core/network/network_activity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/memory_token_store.dart';

/// What the app-wide loading bar reads (2026-09-15).
void main() {
  test('busy follows in-flight work, and a same-turn start and stop is no '
      'change at all', () async {
    final activity = NetworkActivity();
    addTearDown(activity.dispose);
    final seen = <bool>[];
    activity.busy.addListener(() => seen.add(activity.busy.value));

    activity
      ..begin()
      ..end();
    await Future<void>.delayed(Duration.zero);
    expect(seen, isEmpty);

    activity.begin();
    await Future<void>.delayed(Duration.zero);
    activity.end();
    await Future<void>.delayed(Duration.zero);
    expect(seen, [true, false]);
  });

  test('a request is busy until its last retry answers, counted once',
      () async {
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final attempt = ++requests;
      try {
        if (attempt == 1) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode([]));
        await request.response.close();
      } on Object {
        // The client gave up on the stalled attempt.
      }
    });
    final activity = NetworkActivity();
    addTearDown(activity.dispose);
    final seen = <bool>[];
    activity.busy.addListener(() => seen.add(activity.busy.value));
    final client = DioApiClient(
      config: AppConfig.forEnvironment(AppEnvironment.development).copyWith(
        apiBaseUrl: 'http://127.0.0.1:${server.port}',
        readTimeout: const Duration(milliseconds: 200),
      ),
      tokens: MemoryTokenStore(),
      activity: activity,
    );

    await client.getList('/cars');
    await Future<void>.delayed(Duration.zero);

    expect(requests, 2);
    expect(seen, [true, false]);
  });
}
