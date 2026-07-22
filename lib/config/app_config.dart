import 'app_environment.dart';

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
  });

  final AppEnvironment environment;

  /// Root of the AK Cars REST API, without a trailing slash.
  final String apiBaseUrl;

  /// When true the DI layer binds the `Mock*` services instead of REST ones.
  final bool useMockData;

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

  static const _envKey = String.fromEnvironment('AK_ENV', defaultValue: 'development');

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
      );
}
