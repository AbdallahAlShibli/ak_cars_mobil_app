import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

/// A disk copy of the warm-up `GET` responses, so a cold start can paint from
/// what the last run fetched instead of waiting on the network.
///
/// **Why it exists.** Start-up warms every repository before the first frame
/// (see `AppBootstrap`), which is about 38 requests for a signed-in account.
/// Against the API on `localhost` each answers in ~30 ms; through the
/// Cloudflare tunnel the app actually uses, each takes ~1 s and a single one
/// occasionally stalls for 17–48 s (measured 2026-09-15). Start-up waits for
/// the slowest of them, so the OS launch screen stayed up for as long as the
/// worst request took. With this cache, a start-up after the first reads the
/// same answers from disk in milliseconds, and `AppBootstrap.completeWarmUp`
/// fetches the live ones right after the first frame and repaints.
///
/// **What it is not.** It is not a general HTTP cache. Only requests made
/// inside a [ResponseCacheScope] touch it — the repository warm-ups and the
/// per-account lists — so its size is bounded by that fixed set of endpoints,
/// and nothing a screen fetches on demand is ever served stale.
abstract interface class ResponseCache {
  /// The body stored under [key], or null when there is none, it is older than
  /// the cache's maximum age, or it cannot be read.
  Future<Object?> read(String key);

  /// Stores [body] under [key]. Best-effort: never throws.
  Future<void> write(String key, Object? body);

  /// Deletes everything. Best-effort: never throws.
  Future<void> clear();
}

/// The cache that holds nothing — web, where there is no private file system,
/// and tests.
final class NoResponseCache implements ResponseCache {
  const NoResponseCache();

  @override
  Future<Object?> read(String key) async => null;

  @override
  Future<void> write(String key, Object? body) async {}

  @override
  Future<void> clear() async {}
}

/// One JSON file per request, in the app's temporary directory.
///
/// The temporary directory rather than documents or support: on Android it is
/// the app's private cache directory and on iOS its `tmp`, both of which the
/// OS may empty under storage pressure — exactly the contract a cache wants,
/// and a miss only costs the network round trip start-up used to make anyway.
final class FileResponseCache implements ResponseCache {
  FileResponseCache(
    this._directory, {
    this.maxAge = defaultMaxAge,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  factory FileResponseCache.inTemporaryDirectory() => FileResponseCache(
    Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$directoryName',
    ),
  );

  static const directoryName = 'ak_cars_api_cache';

  /// Past this a stored answer is treated as missing. The live copy replaces
  /// it seconds after every start-up, so this only matters for an app left
  /// unopened for a week — whose first frame should then wait for real data
  /// rather than show a week-old marketplace.
  static const defaultMaxAge = Duration(days: 7);

  final Directory _directory;
  final Duration maxAge;
  final DateTime Function() _now;
  var _writes = 0;

  @override
  Future<Object?> read(String key) async {
    try {
      final file = _fileFor(key);
      if (!await file.exists()) return null;
      final entry = jsonDecode(await file.readAsString());
      // The key is stored beside the body and compared, so two keys that hash
      // to the same file name can never serve each other's answer.
      if (entry is! Map || entry['k'] != key) return null;
      final savedAt = entry['t'];
      if (savedAt is! int) return null;
      final age = _now().difference(
        DateTime.fromMillisecondsSinceEpoch(savedAt),
      );
      return age > maxAge ? null : entry['b'];
    } catch (error, stack) {
      _log('Could not read a cached response; fetching it instead', error, stack);
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? body) async {
    try {
      await _directory.create(recursive: true);
      final target = _fileFor(key);
      // Written beside the target and renamed over it: a start-up that reads
      // while a refresh is writing sees the old file or the new one, never
      // half of either.
      final temporary = File('${target.path}.${_writes++}.tmp');
      await temporary.writeAsString(
        jsonEncode({
          'k': key,
          't': _now().millisecondsSinceEpoch,
          'b': body,
        }),
        flush: true,
      );
      await temporary.rename(target.path);
    } catch (error, stack) {
      _log('Could not store a response for the next start-up', error, stack);
    }
  }

  @override
  Future<void> clear() async {
    try {
      if (await _directory.exists()) await _directory.delete(recursive: true);
    } catch (error, stack) {
      _log('Could not clear the response cache', error, stack);
    }
  }

  File _fileFor(String key) => File(
    '${_directory.path}${Platform.pathSeparator}${fileNameFor(key)}.json',
  );

  /// A short, file-system-safe name for [key]: two 32-bit FNV-1a hashes, over
  /// its UTF-8 bytes forwards and backwards. Keys carry an account id and a
  /// full URL, too long and too punctuated to use as a file name directly.
  static String fileNameFor(String key) {
    final bytes = utf8.encode(key);
    return '${_fnv1a32(bytes)}${_fnv1a32(bytes.reversed)}';
  }

  static String _fnv1a32(Iterable<int> bytes) {
    const offsetBasis = 0x811c9dc5;
    const prime = 0x01000193;
    var hash = offsetBasis;
    for (final byte in bytes) {
      hash = ((hash ^ byte) * prime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static void _log(String message, Object error, StackTrace stack) =>
      developer.log(
        message,
        name: 'ResponseCache',
        error: error,
        stackTrace: stack,
      );
}

/// Which requests may use the [ResponseCache], and how — carried by the zone
/// the warm-up runs in, so no service or repository signature has to change.
///
/// * [preferCached]: a stored answer is returned instead of calling the API,
///   and a miss is fetched and stored. Start-up only.
/// * [record]: every answer is fetched live and stored for the next start-up.
///   Every refresh of the warm caches.
///
/// Outside both, the client never reads or writes the cache.
final class ResponseCacheScope {
  ResponseCacheScope._({required this._readsStoredAnswers});

  static const _zoneKey = #akCarsResponseCacheScope;

  final bool _readsStoredAnswers;
  var _closed = false;

  /// True inside [preferCached] until [close]: a stored answer is returned
  /// before the API is asked. False inside [record].
  bool get readsStoredAnswers => _readsStoredAnswers && !_closed;

  /// Ends the preference for stored answers. The scope lives in a zone, and a
  /// zone outlives the code that entered it: a listener or subscription set
  /// up during start-up keeps running in it for the whole session. Without
  /// this, every refresh such a callback triggered — an app resume hours
  /// later — was answered from disk and never reached the API, so a stale
  /// stored answer (an empty make list behind "Add your car") could never be
  /// replaced. After [close] the scope still records answers for the next
  /// start-up; it just always asks the API first.
  void close() => _closed = true;

  var _served = 0;

  /// Whether any request in this scope was answered from disk — the signal
  /// that a live refresh has to follow the first frame.
  bool get servedFromCache => _served > 0;

  /// Called by the client when it answers from disk.
  void markServedFromCache() => _served++;

  /// The scope the calling code runs in, if any.
  static ResponseCacheScope? get current =>
      Zone.current[_zoneKey] as ResponseCacheScope?;

  /// A start-up scope to [run] code in — for a caller that needs to know what
  /// was served from disk even when the code it ran failed.
  factory ResponseCacheScope.preferringCache() =>
      ResponseCacheScope._(readsStoredAnswers: true);

  /// Runs [body] inside this scope.
  Future<T> run<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: this});

  /// Runs [body] reading stored answers first. Returns its result and the
  /// scope, which says whether anything came from disk.
  static Future<(T, ResponseCacheScope)> preferCached<T>(
    Future<T> Function() body,
  ) async {
    final scope = ResponseCacheScope.preferringCache();
    final result = await scope.run(body);
    return (result, scope);
  }

  /// Runs [body] storing every answer it fetches. Inside an enclosing scope it
  /// keeps that one: the session lists start-up loads through `SessionRefresh`
  /// must still prefer the disk copy.
  static Future<T> record<T>(Future<T> Function() body) {
    if (current != null) return body();
    return runZoned(
      body,
      zoneValues: {_zoneKey: ResponseCacheScope._(readsStoredAnswers: false)},
    );
  }
}
