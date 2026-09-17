import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ak_cars_app.dart';
import 'bootstrap.dart';
import 'boot_failure_screen.dart';

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
      // What start-up deliberately left for later — the live refresh after a
      // start-up painted from disk, and every workshop's slots — waits for
      // the first frame, so it can never hold the launch screen up.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(AppBootstrap.completeWarmUp(container)),
      );
      // The first load carries on after the app is up (see
      // `AppBootstrap.firstFrameBudget`). If it fails with nothing stored to
      // show, the app is an empty shell — exactly the "wrong app" start-up has
      // always refused to present — so the failure screen takes over, and the
      // container goes once the frame that still reads it is gone.
      unawaited(
        AppBootstrap.startupSettled(container).catchError((
          Object error,
          StackTrace stack,
        ) {
          _showFailure(
            error,
            stack,
            createContainer: createContainer,
            timeout: timeout,
            attempt: attempt,
          );
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => container.dispose(),
          );
        }),
      );
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
