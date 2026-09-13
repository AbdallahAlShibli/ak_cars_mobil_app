/// Cross-cutting values that are neither theme tokens nor API paths.
abstract final class AppConstants {
  /// Marketing version, kept in step with `pubspec.yaml`'s `version:`.
  ///
  /// One constant because there were two hardcoded strings that had already
  /// drifted apart — the profile screen claimed "v1.0.0" while Settings
  /// claimed "v2.0" on the same build. A version the app cannot state
  /// consistently is worse than one it does not show at all, since it is the
  /// first thing a support conversation asks for.
  static const appVersion = '1.0.0';

  /// ISO code of the only currency the app trades in.
  static const currencyCode = 'OMR';

  /// Omani Rial is quoted to three decimals officially, but the marketplace
  /// prices parts and services in two — keep display consistent app-wide.
  static const priceDecimals = 2;

  /// Oman standard VAT rate (Royal Decree 121/2020, in force since April
  /// 2021). Shop prices are quoted VAT-inclusive, so this is only used to
  /// show the buyer how much of a price is tax.
  static const vatRate = 0.05;

  /// Cars-market feed page size (matches [AppConfig.defaultPageSize]).
  static const listingsPageSize = 20;

  /// Escrow is released only after the buyer confirms receipt.
  static const escrowEnabled = true;

  /// SharedPreferences keys. Kept together so no two features collide.
  static const prefsLanguage = 'akcars_lang';
  static const prefsTheme = 'akcars_theme';
  static const prefsNotifications = 'akcars_notifications';
  static const prefsAuthToken = 'akcars_auth_token';

  /// First-run flags. These are what make the intro a *first launch* thing
  /// rather than something the user re-watches on every cold start, so they
  /// have to outlive the process — uninstalling the app is the only thing
  /// that should clear them.
  static const prefsOnboardingSeen = 'akcars_onboarding_seen';
  static const prefsStartChoiceMade = 'akcars_start_choice_made';

  /// The registered profile, cached so a returning user is still registered
  /// after a cold start. Stands in for the session the REST implementation
  /// will restore from [prefsAuthToken].
  static const prefsProfile = 'akcars_profile';

  /// Whether [prefsProfile] is an *active session* rather than just an
  /// account on file. Signing out clears this and keeps the profile —
  /// otherwise nobody could ever log back in, since the mock has nowhere
  /// else to remember the account existed.
  static const prefsSessionActive = 'akcars_session_active';

  /// The user's own records, stored on the device until the backend owns them.
  /// Registering a car is the app's first real piece of data entry — losing it
  /// on the next launch reads as the Save button never having worked.
  /// Which workshop-application status the owner has dismissed the "My
  /// account" status card for. Holds the *stage key* rather than a boolean on
  /// purpose: dismissing "your workshop is approved" must not also swallow a
  /// later suspension, so the card comes back the moment the decision
  /// changes. Device-local — hiding a card is a preference, not account data.
  static const prefsWorkshopNoticeDismissedStage =
      'akcars_workshop_notice_dismissed_stage';

  static const prefsGarage = 'akcars_garage';
  static const prefsMaintenance = 'akcars_maintenance';
}
