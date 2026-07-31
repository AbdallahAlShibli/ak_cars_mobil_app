import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';

/// How a car is driven.
///
/// This is the one fact the rest of the app personalises on: an EV owner must
/// not be reminded about engine oil, and a petrol owner must not be offered a
/// high-voltage battery diagnostic. It is deliberately a small closed set —
/// the same five values the cars marketplace already sells under
/// `SpecCatalog.fuels`, so a listing and a garage car can talk about the same
/// thing.
enum Powertrain { petrol, diesel, hybrid, pluginHybrid, electric }

extension PowertrainX on Powertrain {
  /// Stable wire value, persisted on a saved car.
  String get key => name;

  L get label => switch (this) {
        Powertrain.petrol => const L('بنزين', 'Petrol'),
        Powertrain.diesel => const L('ديزل', 'Diesel'),
        Powertrain.hybrid => const L('هجين', 'Hybrid'),
        Powertrain.pluginHybrid =>
          const L('هجين قابل للشحن', 'Plug-in hybrid'),
        Powertrain.electric => const L('كهربائي', 'Electric'),
      };

  /// Short badge wording for a car card.
  L get badge => switch (this) {
        Powertrain.pluginHybrid => const L('هجين شحن', 'PHEV'),
        _ => label,
      };

  IconData get icon => switch (this) {
        Powertrain.petrol || Powertrain.diesel =>
          LucideIcons.fuel,
        Powertrain.hybrid => LucideIcons.leaf,
        Powertrain.pluginHybrid => LucideIcons.plugZap,
        Powertrain.electric => LucideIcons.zap,
      };

  /// Has a combustion engine to change oil in.
  bool get hasEngine => this != Powertrain.electric;

  /// Carries a traction (high-voltage) battery pack whose health is worth
  /// inspecting.
  bool get hasHighVoltageBattery =>
      this == Powertrain.hybrid ||
      this == Powertrain.pluginHybrid ||
      this == Powertrain.electric;

  /// Plugs into a charger, so charging cables, ports and home chargers are
  /// part of ownership.
  bool get plugsIn =>
      this == Powertrain.pluginHybrid || this == Powertrain.electric;

  /// Driven by electricity alone. The EV-specific experience keys off this
  /// rather than [plugsIn]: a plug-in hybrid still needs its oil changed, so
  /// replacing its maintenance list with an EV one would be wrong.
  bool get isFullyElectric => this == Powertrain.electric;

  /// The `SpecCatalog.fuels` value a marketplace listing stores for this
  /// powertrain — the two vocabularies have to line up or an EV ad and an EV
  /// garage car would be unrelatable.
  String get specFuel => switch (this) {
        Powertrain.petrol => 'Petrol',
        Powertrain.diesel => 'Diesel',
        Powertrain.hybrid => 'Hybrid',
        Powertrain.pluginHybrid => 'Plug-in Hybrid',
        Powertrain.electric => 'Electric',
      };

  /// Accepts either the wire [key] or a `SpecCatalog.fuels` value, so a car
  /// saved from a marketplace listing parses without a translation table at
  /// the call site. Unknown values yield null — "not recorded", never a guess.
  static Powertrain? fromKey(String? key) {
    if (key == null) return null;
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    for (final value in Powertrain.values) {
      if (value.name.toLowerCase() == normalized) return value;
      if (value.specFuel.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '') ==
          normalized) {
        return value;
      }
    }
    return null;
  }
}
