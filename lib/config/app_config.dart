import 'app_environment.dart';

/// Where the app's data comes from (§12).
///
/// Replaces the old `useMockData` boolean as the thing the composition root
/// switches on. A boolean answered "are we still on demo data?"; this answers
/// "which implementation of every service is bound", which is the question
/// `di/providers.dart` actually asks — and it leaves room for a third source
/// (a recorded fixture, an offline cache) without every binding growing a
/// second condition.
enum DataSourceMode {
  /// The `Mock*` services and `MockSeed`'s world. Fully working offline.
  mock,

  /// The `Api*` services against [AppConfig.apiBaseUrl].
  api;

  String get key => name;

  static DataSourceMode fromKey(String? key) {
    for (final value in DataSourceMode.values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return DataSourceMode.mock;
  }
}

/// Immutable, environment-scoped runtime configuration.
///
/// This is the single place that answers "which backend do we talk to, and
/// are we still on demo data?". Nothing else in the app should read
/// `String.fromEnvironment` directly.
///
/// Phase 2 (real backend): flip [useMockData] to `false` for an environment
/// and register the REST services in `lib/di/providers.dart` — no screen,
/// state or repository code has to change.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.useMockData,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 20),
    this.mockLatency = Duration.zero,
    this.simulateProviderLifecycle = true,
    this.defaultPageSize = 20,
    this.approvalWindow = const Duration(hours: 72),
    this.approvalReminderLead = const Duration(hours: 24),
    this.platformCommission = 0.10,
    this.earningsWindow = const Duration(days: 30),
  });

  final AppEnvironment environment;

  /// Root of the AK Cars REST API, without a trailing slash.
  final String apiBaseUrl;

  /// When true the DI layer binds the `Mock*` services instead of REST ones.
  ///
  /// Kept as the *stored* field so every existing environment definition and
  /// test override goes on meaning what it meant. [dataSource] is what the
  /// composition root reads, and it is derived from this plus the
  /// `AK_DATA_SOURCE` define — so there is one answer, not two that can
  /// disagree.
  final bool useMockData;

  /// Which set of service implementations to bind (§12).
  ///
  /// `--dart-define=AK_DATA_SOURCE=api` forces the REST path on any
  /// environment, which is how the acceptance check is run: the app boots and
  /// the first request fails with a clear [NetworkException] naming the base
  /// URL, rather than silently falling back to demo data and looking like it
  /// works.
  DataSourceMode get dataSource {
    final override = DataSourceMode.fromKey(_dataSourceKey);
    if (_dataSourceKey.isNotEmpty) return override;
    return useMockData ? DataSourceMode.mock : DataSourceMode.api;
  }

  static const _dataSourceKey =
      String.fromEnvironment('AK_DATA_SOURCE', defaultValue: '');

  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Artificial delay applied by the mock services so the app exercises the
  /// same asynchronous code paths it will use against a real network.
  ///
  /// Kept at zero by default: a non-zero value would introduce loading states
  /// the current UI does not render.
  final Duration mockLatency;

  /// Drives the demo timers that walk a service request / order through its
  /// status lifecycle. The real backend pushes these transitions instead.
  final bool simulateProviderLifecycle;

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

  static const _envKey = String.fromEnvironment('AK_ENV', defaultValue: 'development');

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
  factory AppConfig.current() => forEnvironment(AppEnvironment.fromKey(_envKey));

  static AppConfig forEnvironment(AppEnvironment environment) =>
      switch (environment) {
        AppEnvironment.development => const AppConfig(
            environment: AppEnvironment.development,
            apiBaseUrl: 'https://localhost:5001/api',
            useMockData: true,
          ),
        AppEnvironment.staging => const AppConfig(
            environment: AppEnvironment.staging,
            apiBaseUrl: 'https://staging-api.akcars.om/api',
            useMockData: true,
          ),
        AppEnvironment.production => const AppConfig(
            environment: AppEnvironment.production,
            apiBaseUrl: 'https://api.akcars.om/api',
            useMockData: false,
          ),
      };

  AppConfig copyWith({
    AppEnvironment? environment,
    String? apiBaseUrl,
    bool? useMockData,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? mockLatency,
    bool? simulateProviderLifecycle,
    int? defaultPageSize,
    Duration? approvalWindow,
    Duration? approvalReminderLead,
    double? platformCommission,
    Duration? earningsWindow,
  }) =>
      AppConfig(
        environment: environment ?? this.environment,
        apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
        useMockData: useMockData ?? this.useMockData,
        connectTimeout: connectTimeout ?? this.connectTimeout,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        mockLatency: mockLatency ?? this.mockLatency,
        simulateProviderLifecycle:
            simulateProviderLifecycle ?? this.simulateProviderLifecycle,
        defaultPageSize: defaultPageSize ?? this.defaultPageSize,
        approvalWindow: approvalWindow ?? this.approvalWindow,
        approvalReminderLead:
            approvalReminderLead ?? this.approvalReminderLead,
        platformCommission: platformCommission ?? this.platformCommission,
        earningsWindow: earningsWindow ?? this.earningsWindow,
      );
}
