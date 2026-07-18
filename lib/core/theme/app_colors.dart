import 'package:flutter/material.dart';

/// AK Cars design tokens — v2 "alive" palette: electric blue brand with
/// a violet edge, warm orange for money-in-escrow, fresh mint for success.
abstract final class AppColors {
  static const ink = Color(0xFF101A3A);
  static const ink2 = Color(0xFF4A5578);
  static const ink3 = Color(0xFF93A0C2);

  static const bg = Color(0xFFF2F5FC);
  static const card = Color(0xFFFFFFFF);
  static const field = Color(0xFFEEF2FA);
  static const border = Color(0xFFE2E8F7);

  static const brand = Color(0xFF2E5BFF);
  static const brandSoft = Color(0xFFE6EDFF);
  static const brandDark = Color(0xFF1B33B5);

  static const violet = Color(0xFF7C5CFF);
  static const violetSoft = Color(0xFFEFEAFF);

  static const amber = Color(0xFFFF8A2A);
  static const amberSoft = Color(0xFFFFEEDD);
  static const amberText = Color(0xFFA35312);

  static const good = Color(0xFF0FB981);
  static const goodSoft = Color(0xFFDCF7EC);

  static const bad = Color(0xFFF43F5E);
  static const badSoft = Color(0xFFFFE7EC);

  static const splashTop = Color(0xFF0A1030);

  /// Vivid 3-stop hero gradient — blue with a violet edge.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B33B5), Color(0xFF2E5BFF), Color(0xFF6A5CFF)],
  );

  /// Warm promo gradient (offers, highlights).
  static const sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A2A), Color(0xFFFF5E7A)],
  );
}
