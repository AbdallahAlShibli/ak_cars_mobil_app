import '../../core/json/json_utils.dart';

/// Oman governorates, their wilayats, and Arabic display names.
///
/// Canonical English names are the stored/filter keys everywhere in the app;
/// Arabic is presentation only. Served by `CatalogRepository`, backed by
/// `GET /locations` in Phase 2.
class LocationCatalog {
  const LocationCatalog({
    required this.governorates,
    required this.arabicNames,
  });

  /// Governorate → its wilayats (states).
  final Map<String, List<String>> governorates;

  /// English key → Arabic display name, for governorates, wilayats and the
  /// common areas providers and listings sit in.
  final Map<String, String> arabicNames;

  static const empty = LocationCatalog(governorates: {}, arabicNames: {});

  List<String> wilayatsOf(String governorate) =>
      governorates[governorate] ?? const [];

  /// Display name for a location key ("Sohar" → "صحار" in Arabic mode).
  /// Falls back to the key itself when no translation exists.
  String localized(String name, bool isAr) =>
      isAr ? (arabicNames[name] ?? name) : name;

  /// Localizes a "City, Governorate" composite (listing regions).
  String localizedRegion(String region, bool isAr) {
    if (!isAr) return region;
    return region
        .split(',')
        .map((part) => localized(part.trim(), true))
        .join('، ');
  }

  factory LocationCatalog.fromJson(JsonMap json) => LocationCatalog(
        governorates: {
          for (final entry
              in (json.objectOrNull('governorates') ?? const {}).entries)
            entry.key: (entry.value as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList(growable: false),
        },
        arabicNames: {
          for (final entry
              in (json.objectOrNull('arabicNames') ?? const {}).entries)
            entry.key: entry.value.toString(),
        },
      );

  JsonMap toJson() => {
        'governorates': governorates,
        'arabicNames': arabicNames,
      };

  LocationCatalog copyWith({
    Map<String, List<String>>? governorates,
    Map<String, String>? arabicNames,
  }) =>
      LocationCatalog(
        governorates: governorates ?? this.governorates,
        arabicNames: arabicNames ?? this.arabicNames,
      );
}
