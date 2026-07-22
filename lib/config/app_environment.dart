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

  static AppEnvironment fromKey(String key) {
    for (final env in values) {
      if (env.key == key) return env;
    }
    return AppEnvironment.development;
  }

  bool get isDevelopment => this == AppEnvironment.development;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isProduction => this == AppEnvironment.production;
}
