/// The official Omani Rial sign (Central Bank of Oman / Ministry of Finance
/// "Omani Rial Sign Guidelines", 2026) — the glyph that replaces plain
/// "OMR"/"ر.ع" text wherever a price is displayed as a widget.
///
/// Unicode has no assigned code point for the sign, so it ships as a masked
/// PNG (alpha channel = shape, no baked-in color) and is tinted at runtime
/// with [ColorFiltered] to match the surrounding text — one asset works on
/// any background/theme instead of needing separate light/dark exports.
///
/// Placement follows the guideline's usage rules exactly: the sign sits
/// immediately to the left of the numeral with no space between them, at
/// the numeral's height, regardless of the surrounding paragraph's
/// direction — so the pair is always rendered inside its own
/// left-to-right run (see `core/utils/bidi_text.dart` for the same
/// isolation problem with plain digit runs).
library;

import 'package:flutter/material.dart';

/// The sign glyph on its own, sized and tinted to fit inline with text.
class RialGlyph extends StatelessWidget {
  const RialGlyph({
    super.key,
    required this.fontSize,
    required this.color,
    this.bold = false,
  });

  final double fontSize;
  final Color color;

  /// Uses the guideline's Bold cut instead of Medium — pick this to match a
  /// bold/emphasized amount (e.g. a grand total) rather than body text.
  final bool bold;

  /// Natural width/height of the source artwork, so the glyph is never
  /// stretched off its designed proportions.
  static const _mediumAspect = 723 / 484;
  static const _boldAspect = 740 / 486;

  @override
  Widget build(BuildContext context) {
    // The guideline states the sign's "Ayn" curve takes the height of a
    // digit, not a full em box — sizing off the cap height keeps it in
    // proportion instead of towering over the numeral next to it.
    final height = fontSize * 0.72;
    final aspect = bold ? _boldAspect : _mediumAspect;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(
        bold
            ? 'assets/currency/rial_bold.png'
            : 'assets/currency/rial_medium.png',
        height: height,
        width: height * aspect,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Builds the `[sign][numeral]` cluster as a single [InlineSpan], for
/// sentences that mention more than one amount (e.g. "OMR 12 instead of
/// OMR 20") and so can't be expressed with [RialAmount]'s single prefix/
/// suffix. Compose these directly inside a [Text.rich]/[TextSpan] tree.
///
/// Pass [amount] for the common fixed-decimals case, or [numeral] with an
/// already-formatted string (e.g. from `NumberFormat('#,##0.##')`, which
/// drops a trailing `.00` a plain `toStringAsFixed` would keep).
InlineSpan rialAmountSpan({
  double? amount,
  String? numeral,
  required TextStyle style,
  int decimals = 2,
  bool bold = false,
}) {
  assert((amount == null) != (numeral == null),
      'pass exactly one of amount or numeral');
  final color = style.color ?? const Color(0xFF000000);
  final fontSize = style.fontSize ?? 14;
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            // `middle`, not `baseline`, and only on this inner span. The
            // glyph's render object is a `RenderImage`, which does not
            // implement `computeDryBaseline` — a baseline-aligned placeholder
            // therefore asserts inside anything that dry-lays-out its
            // children, and `UrgencyCard` wraps its content in an
            // `IntrinsicHeight` for the leading edge bar. Every escrow card
            // and status pill printing a price threw in debug.
            //
            // Alignment is not lost: the glyph is drawn at 0.72em (cap height,
            // per the guideline) and centred on the text's midline, which sits
            // within a fraction of a pixel of where the baseline form put it
            // at these sizes. The *outer* span below still baseline-aligns the
            // whole sign+numeral cluster with the surrounding sentence, and
            // that one is a `RenderParagraph`, which computes a dry baseline
            // perfectly well.
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: RialGlyph(fontSize: fontSize, color: color, bold: bold),
            ),
            TextSpan(text: numeral ?? amount!.toStringAsFixed(decimals)),
          ],
        ),
      ),
    ),
  );
}

/// A price, rendered as `[sign][numeral]` with the official Omani Rial sign
/// — the widget-tree replacement for interpolating `'OMR ${amount}'` or
/// `'${amount} ر.ع'` into a [Text].
///
/// [prefix] and [suffix] carry any surrounding copy ("SAVE ", "from ",
/// " · offered by this provider") so the whole line still reads as one
/// sentence in the caller's language, while only the sign+numeral pair is
/// forced left-to-right.
class RialAmount extends StatelessWidget {
  const RialAmount(
    double this.amount, {
    super.key,
    this.decimals = 2,
    this.style,
    this.bold = false,
    this.prefix,
    this.suffix,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : numeral = null;

  /// For an already-formatted numeral (e.g. a `NumberFormat` that drops
  /// trailing zeros), instead of a plain fixed-decimals [amount].
  const RialAmount.formatted(
    String this.numeral, {
    super.key,
    this.style,
    this.bold = false,
    this.prefix,
    this.suffix,
    this.textAlign,
    this.maxLines,
    this.overflow,
  })  : amount = null,
        decimals = 2;

  final double? amount;
  final String? numeral;
  final int decimals;
  final TextStyle? style;
  final bool bold;
  final String? prefix;
  final String? suffix;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effective = defaultStyle.merge(style);

    return Text.rich(
      TextSpan(
        style: effective,
        children: [
          if (prefix != null) TextSpan(text: prefix),
          rialAmountSpan(
            amount: amount,
            numeral: numeral,
            style: effective,
            decimals: decimals,
            bold: bold,
          ),
          if (suffix != null) TextSpan(text: suffix),
        ],
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
