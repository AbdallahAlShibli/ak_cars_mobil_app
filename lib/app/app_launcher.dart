import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ak_cars_app.dart';
import 'bootstrap.dart';
import 'boot_failure_screen.dart';
import 'launch_screen.dart';

/// How the app gets from `main()` to a first frame — **always**.
///
/// The bug this exists for: `main()` used to `await` the whole bootstrap and
/// then call `runApp`. Any failure in between — a repository that threw, a
/// future that never completed — meant `runApp` was never reached, so Flutter
/// never painted anything and the OS launch screen (the app icon on a plain
/// background) stayed up forever. From the outside that is indistinguishable
/// from the app freezing on its splash: no error, no spinner, no way out but
/// force-stopping it, and force-stopping does not help because the next launch
/// fails in exactly the same place.
///
/// So the rule here is: **a frame is painted no matter what**. Either the real
/// app, or a screen that says what went wrong and offers to try again.
abstract final class AppLauncher {
  /// Boots the app and runs it. Calls itself again when the user retries, so
  /// a transient failure (an unreachable API on a flaky connection) does not
  /// need the app killed and reopened.
  ///
  /// [createContainer] is injectable so a test can prove the failure path
  /// without having to make a real repository throw.
  static Future<void> launch({
    Future<ProviderContainer> Function() createContainer =
        AppBootstrap.createContainer,
    Duration timeout = AppBootstrap.bootTimeout,
    int attempt = 1,
  }) async {
    // Called before the first `await` so a failure that happens *during* the
    // bootstrap still has a binding to run the failure screen on.
    WidgetsFlutterBinding.ensureInitialized();
    // A frame before anything is awaited, so Android's own launch screen goes
    // at once and whatever start-up waits on below happens on a screen the
    // app controls — see [LaunchScreenApp]. A retry already has the failure
    // screen's "Trying…" up, which says more than a logo.
    if (attempt == 1) runApp(const LaunchScreenApp());
    try {
      // The outermost guarantee: however the bootstrap is put together, and
      // whatever it decides to wait on, it gets this long to produce a
      // container before the user is shown something they can act on.
      final container = await createContainer().timeout(timeout);
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const AkCarsApp(),
        ),
      );
      var failed = false;
      void failWith(Object error, StackTrace stack) {
        if (failed) return;
        failed = true;
        _showFailure(
          error,
          stack,
          createContainer: createContainer,
          timeout: timeout,
          attempt: attempt,
        );
        // Once the frame that still reads the container is gone.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => container.dispose(),
        );
      }

      // What start-up deliberately left for later — the live refresh after a
      // start-up painted from disk, and every workshop's slots — waits for
      // the first frame, so it can never hold the launch screen up. A start-up
      // painted from disk whose server turns out to be unreachable fails
      // here: showing last run's data as if all were well would hide that
      // nothing on screen can be refreshed, booked or paid for.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(
          AppBootstrap.completeWarmUp(container).catchError(failWith),
        ),
      );
      // The first load carries on after the app is up (see
      // `AppBootstrap.firstFrameBudget`). If it fails with nothing stored to
      // show, the app is an empty shell — exactly the "wrong app" start-up has
      // always refused to present — so the failure screen takes over.
      unawaited(AppBootstrap.startupSettled(container).catchError(failWith));
    } catch (error, stack) {
      _showFailure(
        error,
        stack,
        createContainer: createContainer,
        timeout: timeout,
        attempt: attempt,
      );
    }
  }

  static void _showFailure(
    Object error,
    StackTrace stack, {
    required Future<ProviderContainer> Function() createContainer,
    required Duration timeout,
    required int attempt,
  }) {
    // Reported as well as rendered: the screen shows the user what happened,
    // this puts the stack where a developer (or a crash reporter, when one
    // is wired up) can see it.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'ak_cars',
        context: ErrorDescription('during app start-up'),
      ),
    );
    runApp(
      BootFailureApp(
        // Keyed by attempt so a *failed* retry rebuilds the screen from
        // scratch. Without it `runApp` matches the widget type already on
        // screen and keeps its state — leaving the button on "Trying…",
        // disabled, with no way to try a third time.
        key: ValueKey(attempt),
        error: error,
        onRetry: () => launch(
          createContainer: createContainer,
          timeout: timeout,
          attempt: attempt + 1,
        ),
      ),
    );
  }
}
