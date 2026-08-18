import 'app_environment.dart';

/// Immutable, environment-scoped runtime configuration.
///
/// This is the single place that answers "which backend do we talk to?".
/// Nothing else in the app should read `String.fromEnvironment` directly.
///
/// There is no longer a second answer to that question. The app used to ship a
/// complete offline data layer beside the REST one and pick between them on a
/// `DataSourceMode`; the demo world has been removed from `lib/` entirely
/// (2026-08-10) and now exists only as test doubles under `test/fakes/`. Every
/// binding in `di/providers.dart` resolves to an `Api*` service, so a
/// misconfigured host fails loudly with a [NetworkException] naming the URL it
/// could not reach, instead of quietly serving invented data and looking
/// healthy.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 20),
    this.defaultPageSize = 20,
    this.approvalWindow = const Duration(hours: 72),
    this.approvalReminderLead = const Duration(hours: 24),
    this.platformCommission = 0.10,
    this.earningsWindow = const Duration(days: 30),
  });

  final AppEnvironment environment;

  /// Root of the AK Cars REST API, without a trailing slash.
  final String apiBaseUrl;

  final Duration connectTimeout;
  final Duration receiveTimeout;

  final int defaultPageSize;

  /// How long a customer has to approve or dispute completed work before the
  /// escrow releases itself (spec §3, note 1).
  ///
  /// The window protects the *workshop* from a customer who disappears after
  /// collecting their car. Three days sits at the short end of the 3–7 day
  /// range these platforms normally use, which suits a market where the
  /// workshop and the customer are usually in the same wilayat.
  final Duration approvalWindow;

  /// How far before the deadline the customer is warned that the release is
  /// coming. A silent automatic release is indistinguishable from the app
  /// taking the workshop's side.
  final Duration approvalReminderLead;

  /// The platform's cut of a released booking, as a fraction (spec §3).
  ///
  /// A single number, read by the workshop's Earnings tab and the founder's
  /// Money tab alike, so the two can never quote different commissions for the
  /// same job. It lives in config rather than in either screen because it is a
  /// commercial term, not a display choice — and because the pilot will
  /// certainly change it before launch.
  final double platformCommission;

  /// How far back the Earnings tab's "recently released" figure looks.
  final Duration earningsWindow;

  static const _envKey =
      String.fromEnvironment('AK_ENV', defaultValue: 'development');

  /// Use the remote vehicle-image CDNs (studio photos, brand logos) — **on by
  /// default**, so mobile shows the same real logos and studio photos the web
  /// app does.
  ///
  /// Turn it off to force the offline drawings:
  /// `flutter run --dart-define=AK_REMOTE_CAR_IMAGES=false`.
  ///
  /// Deliberately a compile-time constant rather than an environment field: the
  /// widgets that read it (`CarImage`, `MakeLogo`) sit below the DI layer and
  /// never see an [AppConfig] instance.
  ///
  /// Either way the app never shows an empty box: a car that fails to load
  /// falls back to `assets/cars/` and then to the drawn silhouette in
  /// `core/widgets/car_artwork.dart`.
  static const bool useRemoteVehicleImages =
      bool.fromEnvironment('AK_REMOTE_CAR_IMAGES', defaultValue: true);

  /// Configuration for the environment this binary was built for.
  ///
  /// [_apiBaseUrlOverride], when set, replaces the environment's
  /// [apiBaseUrl] outright — for a physical device on `adb reverse` (which
  /// forwards the device's own loopback, not `10.0.2.2`) or any other host the
  /// per-environment defaults do not cover:
  /// `--dart-define=AK_API_BASE_URL=http://127.0.0.1:5116/api/v1`.
  factory AppConfig.current() {
    final base = forEnvironment(AppEnvironment.fromKey(_envKey));
    return _apiBaseUrlOverride.isEmpty
        ? base
        : base.copyWith(apiBaseUrl: _apiBaseUrlOverride);
  }

  static const _apiBaseUrlOverride =
      String.fromEnvironment('AK_API_BASE_URL', defaultValue: '');

  // One fixed API host for every environment, set by the user 2026-08-09 —
  // do not change until told to. https, not AKCarsMobileAPI's plain-http
  // launch profile: its `UseHttpsRedirection()` runs unconditionally, so the
  // http port only ever 307s. Port 7291 is the `https` profile in
  // Properties/launchSettings.json. DioApiClient trusts its self-signed dev
  // certificate for [AppEnvironment.development] only — see its constructor.
  static const _sharedApiBaseUrl = 'https://localhost:7291/api/v1';

  static AppConfig forEnvironment(AppEnvironment environment) => AppConfig(
        environment: environment,
        apiBaseUrl: _sharedApiBaseUrl,
      );

  AppConfig copyWith({
    AppEnvironment? environment,
    String? apiBaseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    int? defaultPageSize,
    Duration? approvalWindow,
    Duration? approvalReminderLead,
    double? platformCommission,
    Duration? earningsWindow,
  }) =>
      AppConfig(
        environment: environment ?? this.environment,
        apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
        connectTimeout: connectTimeout ?? this.connectTimeout,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        defaultPageSize: defaultPageSize ?? this.defaultPageSize,
        approvalWindow: approvalWindow ?? this.approvalWindow,
        approvalReminderLead: approvalReminderLead ?? this.approvalReminderLead,
        platformCommission: platformCommission ?? this.platformCommission,
        earningsWindow: earningsWindow ?? this.earningsWindow,
      );
}
