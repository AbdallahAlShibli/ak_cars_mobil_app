import 'package:ak_cars_mobil_app/data/services/token_store.dart';

/// A [TokenStore] that keeps the session in memory instead of the platform
/// keychain.
///
/// **This is what made the suite hang, and it is worth writing down.** The real
/// store is backed by `flutter_secure_storage`, whose plugin is not registered
/// under `flutter_tester` — and its `read` does not throw there, it simply
/// never completes. That was invisible while the app had a mock data source,
/// because `AppBootstrap._signedIn` short-circuited to `true` without ever
/// asking the store. With the offline path gone, every warm-up asks, and every
/// widget test sat on an unresolvable future until its own ten-minute deadline.
///
/// Starts empty, which is the state the widget tests want: a guest. That keeps
/// `SessionGarageService` routed to [LocalGarageStore] — a guest writing to the
/// device, which is the real production path for anyone who has not signed in
/// yet, rather than a double standing in for it.
class MemoryTokenStore extends TokenStore {
  MemoryTokenStore({String? access, String? refresh}) {
    _access = access;
    _refresh = refresh;
  }

  String? _access;
  String? _refresh;
  DateTime? _expiresAt;

  @override
  Future<void> save({
    required String access,
    required String refresh,
    required int expiresIn,
  }) async {
    _access = access;
    _refresh = refresh;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
  }

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<DateTime?> readExpiresAt() async => _expiresAt;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _expiresAt = null;
  }
}
