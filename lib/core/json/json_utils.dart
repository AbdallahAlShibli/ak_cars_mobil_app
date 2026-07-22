import '../error/app_exception.dart';

/// Shape of a decoded JSON object.
typedef JsonMap = Map<String, dynamic>;

/// Null-safe, type-safe readers for decoded JSON.
///
/// A backend field that is missing, null, or the wrong type is a routine fact
/// of life during integration; these helpers make each model's `fromJson`
/// state its own defaults instead of crashing on a cast.
extension JsonMapReaders on JsonMap {
  /// Required string. Throws [SerializationException] when absent — use for
  /// identity fields where a silent default would corrupt data.
  String requireString(String key) {
    final value = this[key];
    if (value is String && value.isNotEmpty) return value;
    if (value != null) return value.toString();
    throw SerializationException('Missing required string field "$key"');
  }

  String stringOr(String key, String fallback) {
    final value = this[key];
    if (value is String) return value;
    return value?.toString() ?? fallback;
  }

  String? stringOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    return value is String ? value : value.toString();
  }

  int requireInt(String key) {
    final value = intOrNull(key);
    if (value == null) {
      throw SerializationException('Missing required int field "$key"');
    }
    return value;
  }

  int intOr(String key, int fallback) => intOrNull(key) ?? fallback;

  int? intOrNull(String key) {
    final value = this[key];
    return switch (value) {
      int() => value,
      num() => value.toInt(),
      String() => int.tryParse(value),
      _ => null,
    };
  }

  double requireDouble(String key) {
    final value = doubleOrNull(key);
    if (value == null) {
      throw SerializationException('Missing required double field "$key"');
    }
    return value;
  }

  double doubleOr(String key, double fallback) => doubleOrNull(key) ?? fallback;

  double? doubleOrNull(String key) {
    final value = this[key];
    return switch (value) {
      double() => value,
      num() => value.toDouble(),
      String() => double.tryParse(value),
      _ => null,
    };
  }

  bool boolOr(String key, bool fallback) => boolOrNull(key) ?? fallback;

  bool? boolOrNull(String key) {
    final value = this[key];
    return switch (value) {
      bool() => value,
      num() => value != 0,
      'true' || 'True' || '1' => true,
      'false' || 'False' || '0' => false,
      _ => null,
    };
  }

  DateTime? dateTimeOrNull(String key) {
    final value = this[key];
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  DateTime dateTimeOr(String key, DateTime fallback) =>
      dateTimeOrNull(key) ?? fallback;

  /// Nested object, or null when absent/not an object.
  JsonMap? objectOrNull(String key) {
    final value = this[key];
    return value is Map ? JsonMap.from(value) : null;
  }

  JsonMap requireObject(String key) {
    final value = objectOrNull(key);
    if (value == null) {
      throw SerializationException('Missing required object field "$key"');
    }
    return value;
  }

  /// List of nested objects; empty when absent.
  List<JsonMap> objectList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(JsonMap.from)
        .toList(growable: false);
  }

  /// List of primitives coerced to [T]; empty when absent.
  List<T> primitiveList<T>(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value.whereType<T>().toList(growable: false);
  }

  List<String> stringList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList(growable: false);
  }

  Set<String> stringSet(String key) => stringList(key).toSet();

  /// Enum decoded by name, falling back when the server sends a value this
  /// build does not know about yet.
  T enumOr<T extends Enum>(String key, List<T> values, T fallback) {
    final raw = stringOrNull(key);
    if (raw == null) return fallback;
    for (final value in values) {
      if (value.name.toLowerCase() == raw.toLowerCase()) return value;
    }
    return fallback;
  }
}

/// Drops null-valued entries so request bodies stay minimal and PATCH-safe.
JsonMap compactJson(JsonMap json) {
  final result = <String, dynamic>{};
  for (final entry in json.entries) {
    if (entry.value != null) result[entry.key] = entry.value;
  }
  return result;
}
