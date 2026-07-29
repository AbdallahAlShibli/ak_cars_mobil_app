import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/app/ak_cars_app.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/features/shell/shell_tabs.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets('App boots to the Sand & Ink splash screen (Arabic default)',
      (tester) async {
    final container = await createTestContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AkCarsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('AK Cars'), findsOneWidget);
    // Arabic is the first-launch default.
    expect(find.text('ابدأ الرحلة'), findsOneWidget);
    expect(find.text('كل ما تحتاجه سيارتك… في مكان واحد'), findsOneWidget);
  });

  // Boots the real router with the real branches, which is the only place the
  // tab list and the shell's branch indices are proved to line up.
  testWidgets('A returning user lands in the shell and can reach every tab',
      (tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = await createTestContainer();
    // Marked before the first read of routerProvider: the router resolves the
    // cold-start location once, when it is built.
    container.read(authProvider.notifier).markOnboardingSeen();
    container.read(authProvider.notifier).markStartChoiceMade();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AkCarsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final tabs = buildShellTabs();
    for (final tab in tabs) {
      expect(find.text(tab.label(const S(true))), findsWidgets,
          reason: 'missing tab ${tab.location}');
    }

    // Every branch has to build without throwing — an unregistered route or a
    // branch/index mismatch shows up here and nowhere else.
    for (final tab in tabs.skip(1)) {
      await tester.tap(find.text(tab.label(const S(true))).last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: tab.location);
    }
  });
}
