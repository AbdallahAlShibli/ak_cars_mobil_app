/// Cross-cutting values that are neither theme tokens nor API paths.
abstract final class AppConstants {
  /// ISO code of the only currency the app trades in.
  static const currencyCode = 'OMR';

  /// Omani Rial is quoted to three decimals officially, but the marketplace
  /// prices parts and services in two — keep display consistent app-wide.
  static const priceDecimals = 2;

  /// Cars-market feed page size (matches [AppConfig.defaultPageSize]).
  static const listingsPageSize = 20;

  /// Escrow is released only after the buyer confirms receipt.
  static const escrowEnabled = true;

  /// SharedPreferences keys. Kept together so no two features collide.
  static const prefsLanguage = 'akcars_lang';
  static const prefsTheme = 'akcars_theme';
  static const prefsNotifications = 'akcars_notifications';
  static const prefsAuthToken = 'akcars_auth_token';
}
