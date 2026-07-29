import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/sand_widgets.dart';
import 'app_colors.dart';

/// Sand & Ink theme. Typography: IBM Plex Sans Arabic for text,
/// Chakra Petch for numbers/values (prices, odometer, counters).
abstract final class AppTheme {
  static ThemeData light() => _build(AkColors.light, Brightness.light);

  /// Dark "Ink" theme. Note: the rebuilt core screens read [AkColors]
  /// directly and go dark; a few older detail screens still use the
  /// static light tokens and keep their light styling.
  static ThemeData dark() => _build(AkColors.dark, Brightness.dark);

  /// Numeric style (prices, km, counters) — Chakra Petch per the handoff.
  static TextStyle numeric({
    double size = 14,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.chakraPetch(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static ThemeData _build(AkColors ak, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ak.primary,
        brightness: brightness,
        primary: ak.primary,
        onPrimary: ak.onPrimary,
        surface: ak.bg,
        error: ak.danger,
      ),
      scaffoldBackgroundColor: ak.bg,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme).apply(
      bodyColor: ak.ink,
      displayColor: ak.ink,
    );

    return base.copyWith(
      extensions: [ak],
      textTheme: text,
      dividerColor: ak.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: ak.bg,
        foregroundColor: ak.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 19,
          color: ak.ink,
        ),
      ),
      // Every AppBar back arrow in the app renders as the Sand & Ink circular
      // chevron instead of the stock Material arrow — one place, no per-screen
      // `leading:` overrides to keep in sync.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const SandBackButton.icon(),
        closeButtonIconBuilder: (context) =>
            Icon(LucideIcons.x, size: 20, color: ak.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ak.primary,
          foregroundColor: ak.onPrimary,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ak.ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: ak.ink, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ak.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ak.surface,
        hintStyle: text.bodyMedium?.copyWith(color: ak.inkSub, fontSize: 12.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: ak.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: ak.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: ak.ink, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: ak.border),
        labelStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ak.primary
              : ak.surfaceDim,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ak.bg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ak.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: ak.bg),
        // Keep snackbars above bottom CTAs so they never block taps.
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
