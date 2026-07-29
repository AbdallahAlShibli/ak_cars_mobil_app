/// Phase-1 focus switches.
///
/// The product spec ("AK Cars — مواصفات تعديل التطبيق", §1) narrows the app to
/// one pillar and a half — **booking → escrow → approval**, plus maintenance
/// follow-up — and is explicit about *how* the other two pillars go away:
///
/// > المبدأ الحاكم للتعديل: أخفِ، لا تحذف
/// > (the governing principle: hide, do not delete)
///
/// So the parts store and the cars marketplace keep every line of their code,
/// their models, their services and their tests. What a `false` here removes
/// is the *reachability*: the bottom-navigation branch, the routes, and every
/// entry point that would push into them. Phase 2 is a one-line change per
/// pillar, or a remote-config lookup if the switch needs to happen without
/// shipping a build.
///
/// Deliberately compile-time constants rather than fields on [AppConfig]:
/// the router and the shell read them while building the widget tree, below
/// the DI layer, and a `const` keeps the hidden branches out of the release
/// bundle's reachable code entirely.
abstract final class AppFlags {
  /// Parts store — catalogue, cart, checkout, orders. Phase 2.
  ///
  /// Override for a local check: `--dart-define=AK_PARTS_STORE=true`.
  static const bool partsStoreEnabled =
      bool.fromEnvironment('AK_PARTS_STORE', defaultValue: false);

  /// Used-car marketplace — gallery, listing details, post-an-ad, my ads.
  /// Phase 2.
  static const bool carMarketplaceEnabled =
      bool.fromEnvironment('AK_CAR_MARKETPLACE', defaultValue: false);

  /// Maintenance follow-up — odometer, reminders, service history. Part of
  /// the phase-1 core (spec §4), so this is on; the flag exists so the "سيارتي"
  /// tab has one switch rather than a scatter of conditions.
  static const bool maintenanceEnabled = true;

  /// The weekly challenge. Cheap, user-data-only, and keeps the garage worth
  /// opening between services — kept on.
  static const bool weekChallengeEnabled = true;

  /// The home page.
  ///
  /// Off from the 2026-07-27 refocus until 2026-07-28, because what the old
  /// home page aggregated was mostly the two hidden pillars — the shop and the
  /// cars gallery — and what remained had gained a tab of its own.
  ///
  /// Back on, with a page rebuilt around the pillars this build *does* run: the
  /// user's registered cars and their real service countdowns, live workshop
  /// offers, per-car suggestions, and the two marketplace leaderboards. It is
  /// the first tab and the cold-start destination again ([startLocation]).
  static const bool homeTabEnabled =
      bool.fromEnvironment('AK_HOME_TAB', defaultValue: true);

  /// Where a cold start and every "go back to the top" action land. Tracks
  /// [homeTabEnabled] so neither ever points at a route that is not
  /// registered.
  static String get startLocation => homeTabEnabled ? '/home' : '/services';

  /// "Request a part + installation" — the custom-quote transaction.
  ///
  /// Deliberately *not* the parts store: there is no catalogue, no inventory,
  /// no supplier onboarding and no fitment database behind this. The customer
  /// describes what they need, one workshop prices it in two itemised halves,
  /// and the job then rides the same escrow machine as any other booking.
  static const bool requestPartInstall =
      bool.fromEnvironment('AK_PART_INSTALL', defaultValue: true);

  /// Verified reviews. A review can only exist against a booking that reached
  /// `releasedToWorkshop`, which is the whole verification mechanism — see
  /// `data/models/review.dart`.
  static const bool verifiedReviews =
      bool.fromEnvironment('AK_REVIEWS', defaultValue: true);

  /// The operator panels (workshop, founder). Spec §6: three roles on one
  /// codebase for the pilot. These are internal tools — visible only after
  /// the user switches role in Settings, never advertised to a customer.
  static const bool operatorPanelsEnabled = true;
}
