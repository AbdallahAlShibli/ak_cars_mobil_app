/// 4px-based spacing scale — the single source of every gap in the app.
///
/// Before this existed the screens carried ad-hoc numbers (`14`, `13`, `11`,
/// `9`…) that were each individually defensible and collectively made the page
/// look untuned: two cards a hair apart read as one block, two sections a hair
/// apart read as one section. The scale is deliberately short — seven steps —
/// because a value that is not on it is almost always a value that wanted to
/// be one of its neighbours.
///
/// Use the semantic aliases in screen code. `AppSpacing.sectionGap` says *why*
/// the gap is there, which is the thing that has to stay consistent; `24` says
/// only how big it is, which is the thing that may change.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  // -------------------------------------------------- semantic aliases

  /// Padding inside a card.
  static const cardPadding = lg;

  /// Gap between two page sections — the biggest breath on a page.
  static const sectionGap = xl;

  /// Gap between two items of the same list.
  static const itemGap = sm;

  /// Horizontal page margin.
  static const screenMargin = lg;

  /// Gap between a heading and the content it introduces. Tighter than
  /// [sectionGap] on purpose: a title must sit closer to what it names than to
  /// the section above it, or it reads as belonging to the wrong block.
  static const headingGap = md;
}
