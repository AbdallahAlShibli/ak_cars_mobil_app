/// The thresholds and windows the home page ranks by (home-page spec §4).
///
/// One place, deliberately. Every number that decides *which* workshop the
/// front page puts first is here rather than scattered across the repository
/// and the widgets, so the rule can be read — and changed — without hunting
/// through call sites. Nothing here is a stored ranking: the boards are
/// computed from live ratings and live booking counts on every read, which is
/// the spec's "لا تُخزّن ترتيباً ثابتاً — احسبه من البيانات الحيّة".
///
/// What is *not* here, and must never be: any notion of a paid placement. The
/// home page ranks on merit only (spec §2), so there is no boost weight, no
/// sponsored slot and no tie-break that money could reach.
abstract final class HomeRankingConfig {
  /// How many customer reviews a workshop needs before it may appear on the
  /// "top rated" board at all.
  ///
  /// The spec suggests 3 as an illustration ("مثال ثابت = 3"). This app uses a
  /// much higher bar for the reason the spec itself gives — a perfect score
  /// from a handful of people is not evidence that a workshop is the best in
  /// the country, and a leaderboard that says otherwise misleads in the
  /// direction that costs a customer money. The demo dataset has a 4.9 from
  /// four reviews specifically to exercise this; at 3 it would top the
  /// national board.
  static const int minReviewsForRanking = 25;

  /// The trailing window "most requested" counts completed bookings over.
  ///
  /// Only bookings that reached `EscrowState.releasedToWorkshop` count — work
  /// that was actually delivered and paid for, not requests that were opened.
  static const int popularWindowDays = 30;

  /// Ceiling on any one home section, so a long list cannot push the sections
  /// below it off the page.
  static const int maxCardsPerSection = 10;

  /// How many rows each workshop board renders. Under [maxCardsPerSection] on
  /// purpose: the front page is a starting point, and the full list is one tap
  /// away on the services tab.
  static const int workshopBoardSize = 3;
}
