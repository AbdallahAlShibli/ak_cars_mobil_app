import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Translates between [IconData] and the stable string keys an API stores.
///
/// Why a registry rather than serialising `codePoint`/`fontFamily`: building
/// `IconData` from a runtime integer defeats Flutter's `--tree-shake-icons`
/// optimisation, which would ship the entire icon font in every release
/// build. Every icon the backend can name is therefore referenced statically
/// here, and unknown keys degrade to [fallback] instead of throwing.
///
/// **The values are Lucide; the keys are not.** The keys are the wire format
/// and several of them still read as Material names (`tire_repair`,
/// `rv_hookup`) because renaming them would break every stored record for a
/// cosmetic gain. What matters is that this table is the one place the app
/// decides what a key *looks* like — moving the whole product onto one icon
/// set (§7) was a change to this file plus the two mock-data files, and no
/// change at all to the API.
///
/// Every value must be **distinct**: [encode] reverses the map by code point,
/// so two keys sharing an icon would make one of them un-encodable. There is a
/// test that asserts this.
abstract final class IconCodec {
  /// Rendered when the API sends an icon key this build does not know.
  static const fallback = LucideIcons.circleDashed;

  static const Map<String, IconData> _byKey = <String, IconData>{
    // --------------------------------------------------- service categories
    'settings_suggest': LucideIcons.settings,
    'build': LucideIcons.wrench,
    'bolt': LucideIcons.zap,
    'car_repair': LucideIcons.carFront,
    'rv_hookup': LucideIcons.siren,
    'tire_repair': LucideIcons.lifeBuoy,
    'local_car_wash': LucideIcons.sparkles,
    'battery_charging': LucideIcons.batteryCharging,
    'ac_unit': LucideIcons.snowflake,
    'monitor_heart': LucideIcons.activity,
    'assignment_turned_in': LucideIcons.clipboardCheck,

    // ------------------------------------------- electric-car service & parts
    'electric_car': LucideIcons.batteryFull,
    'battery_saver': LucideIcons.batteryWarning,
    'cable': LucideIcons.cable,
    'ev_station': LucideIcons.plugZap,
    'electrical_services': LucideIcons.plug,
    'power': LucideIcons.power,

    // -------------------------------------------------------- shop products
    'filter_alt': LucideIcons.funnel,
    'battery_full': LucideIcons.batteryMedium,
    'album': LucideIcons.disc,
    'lightbulb': LucideIcons.lightbulb,
    'trip_origin': LucideIcons.circleDot,
    'air': LucideIcons.wind,
    'shopping_bag': LucideIcons.shoppingBag,

    // ------------------------------------------------------------- vehicles
    'car': LucideIcons.car,
    'car_filled': LucideIcons.carTaxiFront,
    'car_outlined': LucideIcons.caravan,
    'suv': LucideIcons.bus,
    'truck': LucideIcons.truck,
    'bike': LucideIcons.bike,
    'all_vehicles': LucideIcons.layoutGrid,

    // -------------------------------------------------------- notifications
    'notification': LucideIcons.bell,
    'thumb_up': LucideIcons.thumbsUp,
    'fact_check': LucideIcons.clipboardList,
    'inventory': LucideIcons.package,
    'shipping': LucideIcons.truckElectric,
    'lock_open': LucideIcons.lockOpen,
    'lock_clock': LucideIcons.shieldCheck,
    'campaign': LucideIcons.megaphone,
    'schedule_send': LucideIcons.sendHorizontal,
    // The escrow machine's own notifications. These were rendering from the
    // repository but had no key here, so any that went through JSON came back
    // as the fallback circle — registering them keeps a stored notification
    // looking like the one that was sent.
    'request_quote': LucideIcons.receiptText,
    'star': LucideIcons.star,
    'build_circle': LucideIcons.hammer,
    'lock': LucideIcons.lock,
    'gavel': LucideIcons.scale,
    'undo': LucideIcons.undo2,
    'hourglass': LucideIcons.hourglass,

    // ------------------------------------------------------- fulfillment
    'storefront': LucideIcons.store,
    'warning': LucideIcons.triangleAlert,

    // ------------------------------------------------------------- generic
    'calendar': LucideIcons.calendar,
    'event': LucideIcons.calendarDays,
    'chat': LucideIcons.messageCircle,
    'credit_card': LucideIcons.creditCard,
    'factory': LucideIcons.factory,
    'info': LucideIcons.info,
    'language': LucideIcons.languages,
    'location': LucideIcons.mapPin,
    'logout': LucideIcons.logOut,
    'manage_accounts': LucideIcons.userCog,
    'map': LucideIcons.map,
    'phone': LucideIcons.phone,
    'settings': LucideIcons.settings2,
    'share': LucideIcons.share2,
    'support_agent': LucideIcons.headset,
    'back': LucideIcons.arrowLeft,
  };

  static final Map<int, String> _keyByCodePoint = {
    for (final entry in _byKey.entries) entry.value.codePoint: entry.key,
  };

  /// Resolves an API icon key. Unknown or null keys yield [fallback].
  static IconData decode(String? key) =>
      key == null ? fallback : (_byKey[key] ?? fallback);

  /// Reverse lookup for `toJson`. Icons outside the registry encode as null so
  /// a round-trip degrades to [fallback] rather than emitting a bogus key.
  static String? encode(IconData? icon) =>
      icon == null ? null : _keyByCodePoint[icon.codePoint];

  /// Every key the backend may send. Handy for contract tests.
  static Iterable<String> get keys => _byKey.keys;
}
