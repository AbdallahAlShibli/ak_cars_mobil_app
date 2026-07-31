import 'package:flutter/material.dart';

/// The app's typographic hierarchy — **four levels, and no more**.
///
/// It builds on the IBM Plex Sans Arabic text theme configured in
/// [AppTheme], it does not replace it: these getters only fix the size and
/// weight of the four roles the design actually distinguishes.
///
/// Before this existed, screens set `fontSize:` by hand — 21, 19, 15, 14.5,
/// 13.5, 12.5, 11.5, 10.5, 9.5 all appeared, often two of them one step apart
/// inside a single card. Nine sizes that close together is not a hierarchy;
/// it is nine ways of saying "normal", and the eye cannot rank them. Four
/// levels can be ranked at a glance, which is the entire point.
///
/// If a screen seems to need a fifth level, it almost certainly needs one of
/// these four instead — reach for a weight or a color before a new size.
///
/// Usage: `Theme.of(context).textTheme.cardTitle`, or via the shorter
/// [AppTextX] accessor: `context.text.cardTitle`.
extension AppTypographyX on TextTheme {
  /// The one thing a screen is about. One per screen, at the top.
  TextStyle get screenTitle =>
      titleLarge!.copyWith(fontSize: 20, fontWeight: FontWeight.w700);

  /// The name of a card, a section, or a row — the second rank.
  TextStyle get cardTitle =>
      titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600);

  /// Ordinary reading text.
  TextStyle get bodyPrimary => bodyMedium!.copyWith(fontSize: 14);

  /// Supporting text: captions, metadata, the second line of a row. Its color
  /// (`AkColors.inkSub`) comes from the theme's `bodySmall`, so it is dimmer
  /// than [bodyPrimary] without every call site restating it.
  TextStyle get bodySecondary => bodySmall!.copyWith(fontSize: 12.5);

  /// A price. **Not a fifth level** — it is [cardTitle] at a heavier weight.
  ///
  /// The rule it enforces (design review §2): on any card that carries one, the
  /// price outranks the service name. The price is what the customer is
  /// comparing between two workshops; the service name is the same on both.
  TextStyle get price =>
      cardTitle.copyWith(fontWeight: FontWeight.w800, height: 1.15);

  /// The same rank as [bodySecondary] but at card-title weight — for the small
  /// bold labels on tiles and pills, where the *number* is the content and the
  /// label under it is the caption.
  TextStyle get labelStrong =>
      bodySmall!.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700);
}

/// `context.text` — shorthand for `Theme.of(context).textTheme`.
extension AppTextX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
}
