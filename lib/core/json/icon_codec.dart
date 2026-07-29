import 'package:flutter/material.dart';

/// Translates between [IconData] and the stable string keys an API stores.
///
/// Why a registry rather than serialising `codePoint`/`fontFamily`: building
/// `IconData` from a runtime integer defeats Flutter's `--tree-shake-icons`
/// optimisation, which would ship the entire Material font in every release
/// build. Every icon the backend can name is therefore referenced statically
/// here, and unknown keys degrade to [fallback] instead of throwing.
abstract final class IconCodec {
  /// Rendered when the API sends an icon key this build does not know.
  static const fallback = Icons.circle_outlined;

  static const Map<String, IconData> _byKey = <String, IconData>{
    // --------------------------------------------------- service categories
    'settings_suggest': Icons.settings_suggest_rounded,
    'build': Icons.build_rounded,
    'bolt': Icons.bolt_rounded,
    'car_repair': Icons.car_repair,
    'rv_hookup': Icons.rv_hookup,
    'tire_repair': Icons.tire_repair,
    'local_car_wash': Icons.local_car_wash,
    'battery_charging': Icons.battery_charging_full_rounded,
    'ac_unit': Icons.ac_unit_rounded,
    'monitor_heart': Icons.monitor_heart_outlined,
    'assignment_turned_in': Icons.assignment_turned_in_outlined,

    // ------------------------------------------- electric-car service & parts
    'electric_car': Icons.electric_car_rounded,
    'battery_saver': Icons.battery_saver_rounded,
    'cable': Icons.cable_rounded,
    'ev_station': Icons.ev_station_outlined,
    'electrical_services': Icons.electrical_services_rounded,
    'power': Icons.power_rounded,

    // -------------------------------------------------------- shop products
    'filter_alt': Icons.filter_alt_outlined,
    'battery_full': Icons.battery_full_rounded,
    'album': Icons.album_outlined,
    'lightbulb': Icons.lightbulb_outline_rounded,
    'trip_origin': Icons.trip_origin_rounded,
    'air': Icons.air_rounded,
    'shopping_bag': Icons.shopping_bag_outlined,

    // ------------------------------------------------------------- vehicles
    'car': Icons.directions_car_rounded,
    'car_filled': Icons.directions_car_filled_rounded,
    'car_outlined': Icons.directions_car_outlined,
    'suv': Icons.airport_shuttle_rounded,
    'truck': Icons.local_shipping_rounded,
    'bike': Icons.two_wheeler_rounded,
    'all_vehicles': Icons.apps_rounded,

    // -------------------------------------------------------- notifications
    'notification': Icons.notifications_outlined,
    'thumb_up': Icons.thumb_up_alt_outlined,
    'fact_check': Icons.fact_check_outlined,
    'inventory': Icons.inventory_2_outlined,
    'shipping': Icons.local_shipping_outlined,
    'lock_open': Icons.lock_open_rounded,
    'lock_clock': Icons.lock_clock_outlined,
    'campaign': Icons.campaign_outlined,
    'schedule_send': Icons.schedule_send_outlined,

    // ------------------------------------------------------- fulfillment
    'storefront': Icons.storefront_outlined,
    'warning': Icons.warning_amber_rounded,

    // ------------------------------------------------------------- generic
    'calendar': Icons.calendar_today_outlined,
    'event': Icons.event_outlined,
    'chat': Icons.chat_rounded,
    'credit_card': Icons.credit_card_rounded,
    'factory': Icons.factory_outlined,
    'info': Icons.info_outline_rounded,
    'language': Icons.language_rounded,
    'location': Icons.location_on_outlined,
    'logout': Icons.logout_rounded,
    'manage_accounts': Icons.manage_accounts_outlined,
    'map': Icons.map_outlined,
    'phone': Icons.phone_rounded,
    'settings': Icons.settings_outlined,
    'share': Icons.share_rounded,
    'support_agent': Icons.support_agent_rounded,
    'back': Icons.arrow_back_rounded,
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
