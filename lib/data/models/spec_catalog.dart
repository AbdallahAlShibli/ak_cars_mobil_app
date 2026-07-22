import 'package:flutter/material.dart';

import '../../core/json/color_codec.dart';
import '../../core/json/json_utils.dart';
import 'spec_option.dart';

/// Canonical vehicle-spec vocabulary for the cars marketplace.
///
/// Single source of truth shared by the filter and the post-ad form. Filter
/// facets must be driven by this catalog — never by `distinct()` over the
/// current feed, otherwise buyers only ever see the values that happen to be
/// listed today (e.g. "Petrol" as the only fuel type) and sellers can publish
/// values the filter cannot express.
///
/// This is an immutable value object, not a static class: it is served by
/// `CatalogRepository` and will come from `GET /cars/spec-options` in Phase 2.
class SpecCatalog {
  const SpecCatalog({
    required this.bodyTypes,
    required this.conditions,
    required this.regionalSpecs,
    required this.fuels,
    required this.transmissions,
    required this.drivetrains,
    required this.cylinders,
    required this.engineSizes,
    required this.doors,
    required this.seats,
    required this.sellerTypes,
    required this.dealTypes,
    required this.colors,
    required this.swatches,
  });

  final List<SpecOption<String>> bodyTypes;
  final List<SpecOption<String>> conditions;

  /// Market the car was originally built/imported for — "وارد خليجي /
  /// أمريكي / ياباني". In Oman this drives price, AC and cooling spec,
  /// warranty eligibility and resale value, so it is the spec buyers filter on.
  final List<SpecOption<String>> regionalSpecs;

  final List<SpecOption<String>> fuels;
  final List<SpecOption<String>> transmissions;
  final List<SpecOption<String>> drivetrains;

  /// `0` means an electric drivetrain with no combustion cylinders.
  final List<SpecOption<int>> cylinders;

  final List<EngineBucket> engineSizes;
  final List<SpecOption<int>> doors;

  /// The top option (8) reads as "8 or more".
  final List<SpecOption<int>> seats;

  final List<SpecOption<String>> sellerTypes;
  final List<SpecOption<String>> dealTypes;
  final List<SpecOption<String>> colors;

  /// Paint swatch per colour value.
  final Map<String, Color> swatches;

  /// An empty catalog — only used as a pre-load placeholder so a widget built
  /// before bootstrap completes renders nothing rather than crashing.
  static const empty = SpecCatalog(
    bodyTypes: [],
    conditions: [],
    regionalSpecs: [],
    fuels: [],
    transmissions: [],
    drivetrains: [],
    cylinders: [],
    engineSizes: [],
    doors: [],
    seats: [],
    sellerTypes: [],
    dealTypes: [],
    colors: [],
    swatches: {},
  );

  List<List<SpecOption<String>>> get _allStringOptions => [
        bodyTypes,
        conditions,
        regionalSpecs,
        fuels,
        transmissions,
        drivetrains,
        sellerTypes,
        dealTypes,
        colors,
      ];

  /// Localized display label for a stored spec value ("Sedan" → "سيدان").
  /// Falls back to the raw value when it isn't in the catalog.
  String localized(String value, bool isAr) {
    for (final list in _allStringOptions) {
      for (final option in list) {
        if (option.value == value) return isAr ? option.ar : option.en;
      }
    }
    return value;
  }

  Color swatchOf(String color) => swatches[color] ?? ColorCodec.fallback;

  EngineBucket? bucketOf(String value) {
    for (final bucket in engineSizes) {
      if (bucket.value == value) return bucket;
    }
    return null;
  }

  /// Bucket a raw displacement falls into — used when publishing an ad.
  EngineBucket? bucketFor(double litres) {
    for (final bucket in engineSizes) {
      if (bucket.contains(litres)) return bucket;
    }
    return null;
  }

  factory SpecCatalog.fromJson(JsonMap json) {
    List<SpecOption<String>> strings(String key) => json
        .objectList(key)
        .map((e) => SpecOption<String>.fromJson(e, (raw) => raw?.toString() ?? ''))
        .toList(growable: false);

    List<SpecOption<int>> ints(String key) => json
        .objectList(key)
        .map((e) => SpecOption<int>.fromJson(
              e,
              (raw) => raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0,
            ))
        .toList(growable: false);

    return SpecCatalog(
      bodyTypes: strings('bodyTypes'),
      conditions: strings('conditions'),
      regionalSpecs: strings('regionalSpecs'),
      fuels: strings('fuels'),
      transmissions: strings('transmissions'),
      drivetrains: strings('drivetrains'),
      cylinders: ints('cylinders'),
      engineSizes: json
          .objectList('engineSizes')
          .map(EngineBucket.fromJson)
          .toList(growable: false),
      doors: ints('doors'),
      seats: ints('seats'),
      sellerTypes: strings('sellerTypes'),
      dealTypes: strings('dealTypes'),
      colors: strings('colors'),
      swatches: {
        for (final entry in (json.objectOrNull('swatches') ?? const {}).entries)
          entry.key: ColorCodec.decode(entry.value),
      },
    );
  }

  JsonMap toJson() => {
        'bodyTypes': [for (final o in bodyTypes) o.toJson()],
        'conditions': [for (final o in conditions) o.toJson()],
        'regionalSpecs': [for (final o in regionalSpecs) o.toJson()],
        'fuels': [for (final o in fuels) o.toJson()],
        'transmissions': [for (final o in transmissions) o.toJson()],
        'drivetrains': [for (final o in drivetrains) o.toJson()],
        'cylinders': [for (final o in cylinders) o.toJson()],
        'engineSizes': [for (final o in engineSizes) o.toJson()],
        'doors': [for (final o in doors) o.toJson()],
        'seats': [for (final o in seats) o.toJson()],
        'sellerTypes': [for (final o in sellerTypes) o.toJson()],
        'dealTypes': [for (final o in dealTypes) o.toJson()],
        'colors': [for (final o in colors) o.toJson()],
        'swatches': {
          for (final entry in swatches.entries)
            entry.key: ColorCodec.encode(entry.value),
        },
      };

  SpecCatalog copyWith({
    List<SpecOption<String>>? bodyTypes,
    List<SpecOption<String>>? conditions,
    List<SpecOption<String>>? regionalSpecs,
    List<SpecOption<String>>? fuels,
    List<SpecOption<String>>? transmissions,
    List<SpecOption<String>>? drivetrains,
    List<SpecOption<int>>? cylinders,
    List<EngineBucket>? engineSizes,
    List<SpecOption<int>>? doors,
    List<SpecOption<int>>? seats,
    List<SpecOption<String>>? sellerTypes,
    List<SpecOption<String>>? dealTypes,
    List<SpecOption<String>>? colors,
    Map<String, Color>? swatches,
  }) =>
      SpecCatalog(
        bodyTypes: bodyTypes ?? this.bodyTypes,
        conditions: conditions ?? this.conditions,
        regionalSpecs: regionalSpecs ?? this.regionalSpecs,
        fuels: fuels ?? this.fuels,
        transmissions: transmissions ?? this.transmissions,
        drivetrains: drivetrains ?? this.drivetrains,
        cylinders: cylinders ?? this.cylinders,
        engineSizes: engineSizes ?? this.engineSizes,
        doors: doors ?? this.doors,
        seats: seats ?? this.seats,
        sellerTypes: sellerTypes ?? this.sellerTypes,
        dealTypes: dealTypes ?? this.dealTypes,
        colors: colors ?? this.colors,
        swatches: swatches ?? this.swatches,
      );
}
