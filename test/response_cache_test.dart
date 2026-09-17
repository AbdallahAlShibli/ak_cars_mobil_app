import 'dart:convert';
import 'dart:io';

import 'package:ak_cars_mobil_app/config/app_config.dart';
import 'package:ak_cars_mobil_app/config/app_environment.dart';
import 'package:ak_cars_mobil_app/core/network/dio_api_client.dart';
import 'package:ak_cars_mobil_app/core/network/response_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/memory_token_store.dart';

/// The disk copy start-up paints from (2026-09-15).
///
/// The client half is driven through a real socket, like
/// `api_error_translation_test.dart`, because what matters is whether a
/// request actually reached the server — which only the server can count.
void main() {
  group('FileResponseCache', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('ak_response_cache');
      addTearDown(() => _deleteQuietly(directory));
    });

    test('stores an answer and reads it back', () async {
      final cache = FileResponseCache(directory);

      await cache.write('guest|/cars', [
        {'id': 'a'},
      ]);

      expect(await cache.read('guest|/cars'), [
        {'id': 'a'},
      ]);
    });

    test('an answer older than the maximum age reads as missing', () async {
      var now = DateTime(2026, 9, 15);
      final cache = FileResponseCache(directory, clock: () => now);
      await cache.write('guest|/cars', {'v': 1});

      now = now.add(FileResponseCache.defaultMaxAge + const Duration(hours: 1));

      expect(await cache.read('guest|/cars'), isNull);
    });

    test('a corrupt file reads as missing instead of throwing', () async {
      final cache = FileResponseCache(directory);
      await cache.write('guest|/cars', {'v': 1});
      final stored = directory.listSync().whereType<File>().single;

      await stored.writeAsString('{not json');

      expect(await cache.read('guest|/cars'), isNull);
    });

    test('clear removes every stored answer', () async {
      final cache = FileResponseCache(directory);
      await cache.write('guest|/cars', {'v': 1});

      await cache.clear();

      expect(await cache.read('guest|/cars'), isNull);
    });
  });

  group('DioApiClient with a response cache', () {
    late HttpServer server;
    late List<String> requests;
    late Directory directory;
    late MemoryTokenStore tokens;

    setUp(() async {
      requests = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requests.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        // The profile is an object; every other route here is a list. The
        // counter makes a live answer distinguishable from a stored one.
        final answer = request.uri.path == '/user/profile'
            ? {'n': requests.length}
            : [
                {'n': requests.length},
              ];
        request.response.write(jsonEncode(answer));
        await request.response.close();
      });
      directory = await Directory.systemTemp.createTemp('ak_client_cache');
      tokens = MemoryTokenStore(access: _tokenFor('account-1'));
      addTearDown(() async {
        await server.close(force: true);
        await _deleteQuietly(directory);
      });
    });

    DioApiClient client() => DioApiClient(
      config: AppConfig.forEnvironment(
        AppEnvironment.development,
      ).copyWith(apiBaseUrl: 'http://127.0.0.1:${server.port}'),
      tokens: tokens,
      cache: FileResponseCache(directory),
    );

    test('outside a scope every read reaches the server and nothing is '
        'stored', () async {
      final api = client();

      await api.getList('/cars');
      await api.getList('/cars');

      expect(requests, ['/cars', '/cars']);
      expect(directory.listSync(), isEmpty);
    });

    test('start-up serves the answer the last refresh stored, without a '
        'request', () async {
      final api = client();
      await ResponseCacheScope.record(() => api.getList('/cars'));
      await _untilStored(directory, count: 1);

      final (rows, scope) = await ResponseCacheScope.preferCached(
        () => api.getList('/cars'),
      );

      expect(rows, [
        {'n': 1},
      ]);
      expect(requests, ['/cars']);
      expect(scope.servedFromCache, isTrue);
    });

    test('a start-up miss is fetched, stored, and reported as live', () async {
      final api = client();

      final (rows, scope) = await ResponseCacheScope.preferCached(
        () => api.getList('/cars'),
      );
      await _untilStored(directory, count: 1);

      expect(rows, [
        {'n': 1},
      ]);
      expect(requests, ['/cars']);
      expect(scope.servedFromCache, isFalse);
    });

    test('slots are never answered from disk', () async {
      final api = client();
      const slots = '/service-marketplace/providers/p1/slots';
      await ResponseCacheScope.record(() => api.getList(slots));

      final (_, scope) = await ResponseCacheScope.preferCached(
        () => api.getList(slots),
      );

      expect(requests, [slots, slots]);
      expect(scope.servedFromCache, isFalse);
    });

    test('the profile is served from disk at start-up, like the lists',
        () async {
      final api = client();
      await ResponseCacheScope.record(() => api.get('/user/profile'));
      await _untilStored(directory, count: 1);

      final (profile, scope) = await ResponseCacheScope.preferCached(
        () => api.get('/user/profile'),
      );

      expect(profile, {'n': 1});
      expect(requests, ['/user/profile']);
      expect(scope.servedFromCache, isTrue);
    });

    test('another account on the same phone never reads this account\'s '
        'stored answer', () async {
      final api = client();
      await ResponseCacheScope.record(() => api.getList('/user/vehicles'));
      await _untilStored(directory, count: 1);

      await tokens.save(
        access: _tokenFor('account-2'),
        refresh: 'refresh',
        expiresIn: 3600,
      );
      final (rows, scope) = await ResponseCacheScope.preferCached(
        () => api.getList('/user/vehicles'),
      );

      expect(rows, [
        {'n': 2},
      ]);
      expect(scope.servedFromCache, isFalse);
      // The second account's answer is stored under its own key — and waiting
      // for it keeps teardown from deleting a file Windows still has open.
      await _untilStored(directory, count: 2);
    });
  });
}

/// An unsigned JWT carrying [subject] — the client only decodes the claim.
String _tokenFor(String subject) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part({'sub': subject})}.signature';
}

/// The client stores fire-and-forget, so a test waits for the file to land.
Future<void> _untilStored(Directory directory, {required int count}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final stored = directory.existsSync()
        ? directory
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.json'))
              .length
        : 0;
    if (stored >= count) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Expected $count stored response(s) in ${directory.path}');
}

Future<void> _deleteQuietly(Directory directory) async {
  if (await directory.exists()) await directory.delete(recursive: true);
}
