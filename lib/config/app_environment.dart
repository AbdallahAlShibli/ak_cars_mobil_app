/// Build environments the app can be compiled for.
///
/// Selected at build time with `--dart-define=AK_ENV=staging`; defaults to
/// [AppEnvironment.development] so a plain `flutter run` keeps working.
enum AppEnvironment {
  development('development'),
  staging('staging'),
  production('production');

  const AppEnvironment(this.key);

  /// Value expected in the `AK_ENV` dart-define.
  final String key;

  /// Resolves the `AK_ENV` dart-define, falling back to [production] for
  /// anything unrecognised.
  ///
  /// **Production, deliberately, not development.** This used to answer
  /// [development] for an unknown key, which made a typo in a build command
  /// (`AK_ENV=prod`, `AK_ENV=Production`) silently select the one environment
  /// that turns off TLS certificate validation in `DioApiClient`. Every
  /// environment-gated concession in this app loosens something, so the
  /// unknown case has to land on the strict end. A plain `flutter run` is
  /// unaffected: the define's own default is the exact string
  /// `'development'`, which matches above and never reaches this fallback.
  static AppEnvironment fromKey(String key) {
    for (final env in values) {
      if (env.key == key) return env;
    }
    return AppEnvironment.production;
  }

  bool get isDevelopment => this == AppEnvironment.development;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isProduction => this == AppEnvironment.production;
}
