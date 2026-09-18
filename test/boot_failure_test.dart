import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ak_cars_mobil_app/app/ak_cars_app.dart';
import 'package:ak_cars_mobil_app/app/app_launcher.dart';
import 'package:ak_cars_mobil_app/app/bootstrap.dart';
import 'package:ak_cars_mobil_app/app/launch_screen.dart';
import 'package:ak_cars_mobil_app/core/constants/api_endpoints.dart';
import 'package:ak_cars_mobil_app/core/constants/app_constants.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/json/json_utils.dart';
import 'package:ak_cars_mobil_app/core/network/api_client.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';

import 'fakes/fakes.dart';

/// The bug: `main()` awaited the whole bootstrap before `runApp`, so anything
/// that threw — or simply never completed — meant no frame was ever painted
/// and the OS launch screen stayed up forever. Closing and reopening the app
/// hit the same failure again, which is what made it look like a permanent
/// hang on the splash screen.
///
/// The contract these tests hold: **something is always painted**, and the
/// user can always try again.
///
/// The screen follows the platform locale rather than the stored preference
/// (it renders without a provider container), and the test binding's locale is
/// English — hence the English expectations here.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The launcher reports the start-up failure through [FlutterError] on its
  /// way to the failure screen, which the test binding treats as a test
  /// failure unless it is claimed. Claiming it *is* the assertion that it was
  /// reported.
  void expectReported(WidgetTester tester, Object matcher) =>
      expect(tester.takeException(), matcher);

  testWidgets('a bootstrap failure paints the failure screen, not nothing', (
    tester,
  ) async {
    await AppLauncher.launch(
      createContainer: () async => throw StateError('warm-up exploded'),
    );
    await tester.pump();
    expectReported(tester, isStateError);

    expect(find.text('The app could not start'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the error text is available to whoever has to report it', (
    tester,
  ) async {
    await AppLauncher.launch(
      createContainer: () async => throw StateError('warm-up exploded'),
    );
    await tester.pump();
    expectReported(tester, isStateError);

    await tester.tap(find.text('Error details'));
    await tester.pump();
    expect(find.textContaining('warm-up exploded'), findsOneWidget);
  });

  testWidgets('retrying a failure that has cleared boots the real app', (
    tester,
  ) async {
    var attempt = 0;
    Future<ProviderContainer> create() async {
      if (attempt++ == 0) throw StateError('warm-up exploded');
      // With the doubles: the app has no offline data source any more, so a
      // bare container would try to reach the API and the "successful" retry
      // this test is about would fail for an unrelated reason.
      return AppBootstrap.createContainer(
        overrides: fakeServiceOverrides(await SharedPreferences.getInstance()),
      );
    }

    await AppLauncher.launch(createContainer: create);
    await tester.pump();
    expectReported(tester, isStateError);
    expect(find.text('The app could not start'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    // Pumped rather than settled: the screen the retry lands on animates its
    // entrance and its background continuously, so it never goes quiet.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // The second attempt succeeded, so the failure screen is gone and the
    // first-launch screen is up.
    expect(find.text('The app could not start'), findsNothing);
    expect(find.text('AK Cars'), findsOneWidget);
  });

  testWidgets('a retry that fails again can still be retried', (tester) async {
    await AppLauncher.launch(
      createContainer: () async => throw StateError('warm-up exploded'),
    );
    await tester.pump();
    expectReported(tester, isStateError);

    await tester.tap(find.text('Try again'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expectReported(tester, isStateError);

    // The bug this holds: the second failure re-ran `runApp` with the same
    // widget type, so the screen kept the state of the first one and sat on a
    // disabled "Trying…" button forever — a dead end one step short of the
    // hang it replaced.
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Trying…'), findsNothing);
  });

  testWidgets('a bootstrap that never completes is cut off, not waited on', (
    tester,
  ) async {
    // Stands in for anything that can suspend forever: an API host that
    // accepts the connection and never answers, a platform channel that never
    // replies. This is the case that produced the permanent splash — there is
    // no exception to catch, so only a timeout can end it.
    await tester.runAsync(
      () => AppLauncher.launch(
        createContainer: () => Completer<ProviderContainer>().future,
        timeout: const Duration(milliseconds: 100),
      ),
    );
    await tester.pump();
    expectReported(tester, isA<TimeoutException>());

    expect(find.text('The app could not start'), findsOneWidget);
  });

  // The reported bug: with the API stopped, reopening the app sat on the
  // Android launch screen. Whatever start-up waits on now waits on a frame the
  // app painted itself.
  testWidgets('a frame is painted before the bootstrap produces anything', (
    tester,
  ) async {
    final pending = Completer<ProviderContainer>();
    unawaited(AppLauncher.launch(createContainer: () => pending.future));
    await tester.pump();

    expect(find.byType(LaunchScreenApp), findsOneWidget);

    pending.completeError(StateError('warm-up exploded'));
    await tester.pump();
    await tester.pump();
    expectReported(tester, isStateError);
    expect(find.byType(LaunchScreenApp), findsNothing);
    expect(find.text('The app could not start'), findsOneWidget);
  });

  group('a start-up painted from the disk cache', () {
    /// A container whose first load "came from disk", with [apiClient]
    /// standing in for the server.
    Future<ProviderContainer> Function() paintedFromDisk(ApiClient apiClient) =>
        () async {
          final container = await AppBootstrap.createContainer(
            overrides: [
              ...fakeServiceOverrides(await SharedPreferences.getInstance()),
              apiClientProvider.overrideWithValue(apiClient),
            ],
          );
          await AppBootstrap.startupSettled(container);
          container.read(bootServedFromCacheProvider.notifier).state = true;
          return container;
        };

    // `AppLauncher` calls `runApp` itself rather than through `pumpWidget`, so
    // the animated first-launch screen can start its tickers against the
    // previous test's frame clock (a negative elapsed time). One pump first
    // puts this test's clock under them.
    Future<void> launchPaintedFromDisk(
      WidgetTester tester,
      ApiClient api,
    ) async {
      // Past the first-launch intro, whose endless ambient animation is not what
      // these tests are about.
      SharedPreferences.setMockInitialValues({
        AppConstants.prefsOnboardingSeen: true,
        AppConstants.prefsStartChoiceMade: true,
      });
      await tester.pump();
      await AppLauncher.launch(createContainer: paintedFromDisk(api));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('shows the failure screen when the server cannot be reached', (
      tester,
    ) async {
      await launchPaintedFromDisk(tester, const OfflineApiClient());
      expectReported(tester, isA<NetworkException>());

      expect(find.text('The app could not start'), findsOneWidget);
    });

    testWidgets('shows the failure screen when the server answers 502', (
      tester,
    ) async {
      await launchPaintedFromDisk(
        tester,
        const _HealthAnswering(ApiException('Bad gateway', statusCode: 502)),
      );
      expectReported(tester, isA<ApiException>());

      expect(find.text('Our server isn’t responding'), findsOneWidget);
    });

    testWidgets('keeps the app when the server answers', (tester) async {
      await launchPaintedFromDisk(tester, const _HealthAnswering(null));

      expect(find.text('The app could not start'), findsNothing);
      expect(find.byType(AkCarsApp), findsOneWidget);
    });

    // An API deployed before `/health` existed answers 404 — still a server.
    testWidgets('treats any non-5xx answer as a live server', (tester) async {
      await launchPaintedFromDisk(
        tester,
        const _HealthAnswering(NotFoundException('no such route')),
      );

      expect(find.text('The app could not start'), findsNothing);
    });
  });
}

/// Answers `GET /health` with [failure] (or `200` when null) and refuses the
/// rest like [OfflineApiClient]. The rest is never reached: the refresh after
/// the health check is best-effort and swallows the refusals.
class _HealthAnswering extends OfflineApiClient {
  const _HealthAnswering(this.failure);

  final AppException? failure;

  @override
  Future<JsonMap> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    if (path != ApiEndpoints.health) {
      return super.get(
        path,
        queryParameters: queryParameters,
        headers: headers,
      );
    }
    final error = failure;
    if (error != null) throw error;
    return {'status': 'live'};
  }
}
