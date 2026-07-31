import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/json/json_utils.dart';

/// A collection of user-owned records the mock services keep on the device.
///
/// The mock services stand in for the server *and* its database. Anything the
/// user creates therefore has to outlive the process, or the app silently
/// loses it: a car registered on one launch is simply gone on the next, with
/// nothing on screen to explain where it went. `MockAuthService` already
/// stores the profile for exactly that reason — this is the same store,
/// generalised to a list.
///
/// Reference data (the makes catalogue, the parts feed, providers) does *not*
/// belong here: it comes from the server on every launch and would only go
/// stale on the device.
///
/// Phase 2 deletes this — the REST services read the same records back from
/// the backend — so nothing above the service layer knows it exists.
class PrefsCollection<T> {
  const PrefsCollection({
    required this.prefs,
    required this.key,
    required this.fromJson,
    required this.toJson,
  });

  final SharedPreferences prefs;

  /// SharedPreferences key this collection owns outright.
  final String key;

  final T Function(JsonMap json) fromJson;
  final JsonMap Function(T value) toJson;

  /// Everything stored under [key], oldest first.
  ///
  /// A record written by an older build in a shape this one cannot read is
  /// dropped rather than thrown: stale storage must never wedge the launch,
  /// which is the same rule the stored profile follows.
  List<T> load() {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      final rows = jsonDecode(raw);
      if (rows is! List) return [];
      return [
        for (final row in rows)
          if (row is Map) ?_decode(JsonMap.from(row)),
      ];
    } catch (_) {
      prefs.remove(key);
      return [];
    }
  }

  /// Replaces the stored collection wholesale. The services call this after
  /// every mutation, so the device copy is never a write behind the in-memory
  /// one.
  void save(Iterable<T> values) {
    prefs.setString(key, jsonEncode([for (final v in values) toJson(v)]));
  }

  T? _decode(JsonMap json) {
    try {
      return fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
