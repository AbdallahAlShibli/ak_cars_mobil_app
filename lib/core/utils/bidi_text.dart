/// Bidirectional-text helpers for numbers shown inside Arabic copy.
///
/// Arabic paragraphs are right-to-left, and the bidi algorithm reorders any
/// *neutral* character (`+`, `–`, `·`) that sits next to a number according to
/// the paragraph, not the number. Two real cases from the shop-details card:
///
///  * `+96824478120` rendered as `96824478120+` — the dial code's plus jumped
///    to the wrong end of the phone number;
///  * `8:00–20:00` rendered as `20:00–8:00` — the two times swapped, so the
///    opening hours read backwards.
///
/// Wrapping each number in an isolate (`U+2066 LRI` … `U+2069 PDI`) tells the
/// algorithm to lay that run out left-to-right and treat it as a single
/// neutral object in the surrounding Arabic, which fixes both without
/// disturbing the Arabic around it.
///
/// Prefer `Directionality(textDirection: TextDirection.ltr)` when a whole
/// field is Latin (see the phone field in `register_screen.dart`). Use this
/// when the number is embedded in Arabic text that must stay right-to-left.
library;

/// Number runs, including a leading `+` and any internal `: . , / - –`
/// separators, so a phone number or a time range is one run rather than
/// several.
final _numberRun = RegExp(
  r'\+?[0-9٠-٩]+(?:[:.,/–—-][0-9٠-٩]+)*',
);

const _lri = '\u2066';
const _pdi = '\u2069';

/// Isolates every number in [value] so it renders left-to-right.
///
/// A no-op when [rtl] is false: left-to-right paragraphs already lay numbers
/// out correctly, and the isolate characters would only make the rendered
/// string differ from the data for no benefit.
String isolateNumbers(String value, {required bool rtl}) {
  if (!rtl || value.isEmpty) return value;
  return value.replaceAllMapped(_numberRun, (m) => '$_lri${m[0]}$_pdi');
}
