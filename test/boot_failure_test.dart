import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ak_cars_mobil_app/app/app_launcher.dart';
import 'package:ak_cars_mobil_app/app/bootstrap.dart';

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

  testWidgets('a bootstrap failure paints the failure screen, not nothing',
      (tester) async {
    await AppLauncher.launch(
      createContainer: () async => throw StateError('warm-up exploded'),
    );
    await tester.pump();
    expectReported(tester, isStateError);

    expect(find.text('The app could not start'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the error text is available to whoever has to report it',
      (tester) async {
    await AppLauncher.launch(
      createContainer: () async => throw StateError('warm-up exploded'),
    );
    await tester.pump();
    expectReported(tester, isStateError);

    await tester.tap(find.text('Error details'));
    await tester.pump();
    expect(find.textContaining('warm-up exploded'), findsOneWidget);
  });

  testWidgets('retrying a failure that has cleared boots the real app',
      (tester) async {
    var attempt = 0;
    Future<ProviderContainer> create() async {
      if (attempt++ == 0) throw StateError('warm-up exploded');
      return AppBootstrap.createContainer();
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

  testWidgets('a bootstrap that never completes is cut off, not waited on',
      (tester) async {
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
}
