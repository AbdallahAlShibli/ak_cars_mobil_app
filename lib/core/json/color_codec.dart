import 'package:flutter/painting.dart';

/// Translates between [Color] and the `#RRGGBB` / `#AARRGGBB` strings an API
/// stores for colour swatches (listing paint colours, category tints).
abstract final class ColorCodec {
  static const fallback = Color(0xFF9CA3AF);

  /// Accepts `#RRGGBB`, `#AARRGGBB`, `RRGGBB`, `AARRGGBB`, or an int ARGB
  /// value. Anything unparseable yields [fallback].
  static Color decode(Object? value) {
    if (value is int) return Color(value);
    if (value is! String || value.isEmpty) return fallback;

    var hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;

    final argb = int.tryParse(hex, radix: 16);
    return argb == null ? fallback : Color(argb);
  }

  /// Encodes as `#AARRGGBB` so alpha survives the round trip.
  static String encode(Color color) {
    String channel(double value) =>
        (value * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');

    return '#${channel(color.a)}${channel(color.r)}'
            '${channel(color.g)}${channel(color.b)}'
        .toUpperCase();
  }
}
