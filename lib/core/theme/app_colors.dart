import 'package:flutter/material.dart';

/// AK Cars design tokens — "Sand & Ink" theme (design handoff 2026-07):
/// warm cream background, white cards, ink-black pill buttons, warm amber
/// reserved for offers/near-due, red reserved for roadside SOS only.
///
/// [AppColors] keeps the legacy static token names (light values) so the
/// older screens keep compiling and pick up the sand palette automatically.
/// New / rebuilt screens should read [AkColors.of(context)] instead, which
/// is theme-aware (light "Sand" + dark "Ink").
abstract final class AppColors {
  // Ink scale
  static const ink = Color(0xFF1D1B17);
  static const ink2 = Color(0xFF8B857A);
  static const ink3 = Color(0xFFB0A996);

  static const bg = Color(0xFFF6F3EE);
  static const card = Color(0xFFFFFFFF);
  static const field = Color(0xFFF0EBE1);
  static const border = Color(0xFFECE7DE);

  /// In Sand & Ink the "brand" action color is ink black (pill buttons,
  /// active nav states) — legacy screens using `brand` follow along.
  static const brand = Color(0xFF1D1B17);
  static const brandSoft = Color(0xFFF0EBE1);
  static const brandDark = Color(0xFF1D1B17);

  // Legacy violet slots map onto the warm amber family.
  static const violet = Color(0xFFE9A23B);
  static const violetSoft = Color(0xFFF3D9A4);

  static const amber = Color(0xFFE9A23B);
  static const amberSoft = Color(0xFFF3D9A4);
  static const amberText = Color(0xFFB07818);

  static const good = Color(0xFF3E9B6E);
  static const goodSoft = Color(0xFFEAF5EF);

  static const bad = Color(0xFFD96A64);
  static const badSoft = Color(0xFFFBEBE9);

  static const splashTop = Color(0xFFF6F3EE);

  /// Calm ink gradient — replaces the old electric-blue hero gradient on
  /// legacy screens (white text stays readable).
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D1B17), Color(0xFF3A362E)],
  );

  /// Warm promo gradient (offers, highlights).
  static const sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB07818), Color(0xFFE9A23B)],
  );
}

/// Theme-aware Sand & Ink tokens. Light = "Sand" (default), dark = "Ink".
/// Read with `AkColors.of(context)`.
class AkColors extends ThemeExtension<AkColors> {
  const AkColors({
    required this.bg,
    required this.surface,
    required this.surfaceDim,
    required this.border,
    required this.divider,
    required this.ink,
    required this.inkSub,
    required this.inkFaint,
    required this.primary,
    required this.onPrimary,
    required this.amber,
    required this.amberSoft,
    required this.amberText,
    required this.amberDeep,
    required this.amberBgSoft,
    required this.amberBorder,
    required this.promoBgA,
    required this.promoBgB,
    required this.promoBorder,
    required this.promoTitle,
    required this.promoSub,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.dangerBorder,
    required this.dangerText,
    required this.navBar,
    required this.navIdle,
  });

  final Color bg;
  final Color surface;
  final Color surfaceDim;
  final Color border;
  final Color divider;
  final Color ink;
  final Color inkSub;
  final Color inkFaint;

  /// Primary action: ink black in light, inverted cream in dark.
  final Color primary;
  final Color onPrimary;

  final Color amber;
  final Color amberSoft;
  final Color amberText;
  final Color amberDeep;
  final Color amberBgSoft;
  final Color amberBorder;

  // Promo banner (offers)
  final Color promoBgA;
  final Color promoBgB;
  final Color promoBorder;
  final Color promoTitle;
  final Color promoSub;

  final Color success;
  final Color successSoft;

  // SOS red — roadside help, notification dots, cancel/exit only.
  final Color danger;
  final Color dangerSoft;
  final Color dangerBorder;
  final Color dangerText;

  final Color navBar;
  final Color navIdle;

  static const light = AkColors(
    bg: Color(0xFFF6F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceDim: Color(0xFFF0EBE1),
    border: Color(0xFFECE7DE),
    divider: Color(0xFFF0EBE1),
    ink: Color(0xFF1D1B17),
    inkSub: Color(0xFF8B857A),
    inkFaint: Color(0xFFB0A996),
    primary: Color(0xFF1D1B17),
    onPrimary: Color(0xFFF6F3EE),
    amber: Color(0xFFE9A23B),
    amberSoft: Color(0xFFF3D9A4),
    amberText: Color(0xFFB07818),
    amberDeep: Color(0xFF7A6534),
    amberBgSoft: Color(0xFFFDF6E8),
    amberBorder: Color(0xFFF0DFBB),
    promoBgA: Color(0xFFF3D9A4),
    promoBgB: Color(0xFFF3D9A4),
    promoBorder: Color(0x00000000),
    promoTitle: Color(0xFF1D1B17),
    promoSub: Color(0xFF7A6534),
    success: Color(0xFF3E9B6E),
    successSoft: Color(0xFFEAF5EF),
    danger: Color(0xFFD96A64),
    dangerSoft: Color(0xFFFBEBE9),
    dangerBorder: Color(0xFFF2D4D1),
    dangerText: Color(0xFFC05650),
    navBar: Color(0xFFFFFFFF),
    navIdle: Color(0xFFA8A296),
  );

  static const dark = AkColors(
    bg: Color(0xFF171613),
    surface: Color(0xFF211F1B),
    surfaceDim: Color(0xFF2A2822),
    border: Color(0x12FFFFFF),
    divider: Color(0x14FFFFFF),
    ink: Color(0xFFF2EFE8),
    inkSub: Color(0xFFA29B8D),
    inkFaint: Color(0xFF847E71),
    primary: Color(0xFFF6F3EE),
    onPrimary: Color(0xFF1D1B17),
    amber: Color(0xFFE9A23B),
    amberSoft: Color(0x59E9A23B),
    amberText: Color(0xFFF0D9A8),
    amberDeep: Color(0xFFB7A87F),
    amberBgSoft: Color(0x26E9A23B),
    amberBorder: Color(0x40E9A23B),
    promoBgA: Color(0xFF3B3122),
    promoBgB: Color(0xFF2A2419),
    promoBorder: Color(0x40E9A23B),
    promoTitle: Color(0xFFF0D9A8),
    promoSub: Color(0xFFB7A87F),
    success: Color(0xFF6FBE95),
    successSoft: Color(0x1F6FBE95),
    danger: Color(0xFFE28B86),
    dangerSoft: Color(0x1AD96A64),
    dangerBorder: Color(0x40D96A64),
    dangerText: Color(0xFFE28B86),
    navBar: Color(0xFF1D1B17),
    navIdle: Color(0xFF847E71),
  );

  static AkColors of(BuildContext context) =>
      Theme.of(context).extension<AkColors>() ?? light;

  @override
  AkColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceDim,
    Color? border,
    Color? divider,
    Color? ink,
    Color? inkSub,
    Color? inkFaint,
    Color? primary,
    Color? onPrimary,
    Color? amber,
    Color? amberSoft,
    Color? amberText,
    Color? amberDeep,
    Color? amberBgSoft,
    Color? amberBorder,
    Color? promoBgA,
    Color? promoBgB,
    Color? promoBorder,
    Color? promoTitle,
    Color? promoSub,
    Color? success,
    Color? successSoft,
    Color? danger,
    Color? dangerSoft,
    Color? dangerBorder,
    Color? dangerText,
    Color? navBar,
    Color? navIdle,
  }) =>
      AkColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceDim: surfaceDim ?? this.surfaceDim,
        border: border ?? this.border,
        divider: divider ?? this.divider,
        ink: ink ?? this.ink,
        inkSub: inkSub ?? this.inkSub,
        inkFaint: inkFaint ?? this.inkFaint,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        amber: amber ?? this.amber,
        amberSoft: amberSoft ?? this.amberSoft,
        amberText: amberText ?? this.amberText,
        amberDeep: amberDeep ?? this.amberDeep,
        amberBgSoft: amberBgSoft ?? this.amberBgSoft,
        amberBorder: amberBorder ?? this.amberBorder,
        promoBgA: promoBgA ?? this.promoBgA,
        promoBgB: promoBgB ?? this.promoBgB,
        promoBorder: promoBorder ?? this.promoBorder,
        promoTitle: promoTitle ?? this.promoTitle,
        promoSub: promoSub ?? this.promoSub,
        success: success ?? this.success,
        successSoft: successSoft ?? this.successSoft,
        danger: danger ?? this.danger,
        dangerSoft: dangerSoft ?? this.dangerSoft,
        dangerBorder: dangerBorder ?? this.dangerBorder,
        dangerText: dangerText ?? this.dangerText,
        navBar: navBar ?? this.navBar,
        navIdle: navIdle ?? this.navIdle,
      );

  @override
  AkColors lerp(ThemeExtension<AkColors>? other, double t) {
    if (other is! AkColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AkColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceDim: l(surfaceDim, other.surfaceDim),
      border: l(border, other.border),
      divider: l(divider, other.divider),
      ink: l(ink, other.ink),
      inkSub: l(inkSub, other.inkSub),
      inkFaint: l(inkFaint, other.inkFaint),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      amber: l(amber, other.amber),
      amberSoft: l(amberSoft, other.amberSoft),
      amberText: l(amberText, other.amberText),
      amberDeep: l(amberDeep, other.amberDeep),
      amberBgSoft: l(amberBgSoft, other.amberBgSoft),
      amberBorder: l(amberBorder, other.amberBorder),
      promoBgA: l(promoBgA, other.promoBgA),
      promoBgB: l(promoBgB, other.promoBgB),
      promoBorder: l(promoBorder, other.promoBorder),
      promoTitle: l(promoTitle, other.promoTitle),
      promoSub: l(promoSub, other.promoSub),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      dangerBorder: l(dangerBorder, other.dangerBorder),
      dangerText: l(dangerText, other.dangerText),
      navBar: l(navBar, other.navBar),
      navIdle: l(navIdle, other.navIdle),
    );
  }
}
