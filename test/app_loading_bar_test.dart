import 'package:ak_cars_mobil_app/app/app_loading_bar.dart';
import 'package:ak_cars_mobil_app/core/network/network_activity.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/startup_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app-wide loading bar (2026-09-15): up while data loads, never a flicker.
void main() {
  late NetworkActivity activity;
  late ProviderContainer container;

  setUp(() {
    activity = NetworkActivity();
    container = ProviderContainer(
      overrides: [networkActivityProvider.overrideWithValue(activity)],
    );
    addTearDown(container.dispose);
  });

  Future<void> pumpBar(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AppLoadingBar()),
      ),
    ),
  );

  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(AppLoadingBar),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('a request quicker than the show delay never shows the bar',
      (tester) async {
    await pumpBar(tester);

    activity.begin();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    activity.end();
    await tester.pump();
    await tester.pump(AppLoadingBar.showDelay);

    expect(opacity(tester), 0);
  });

  testWidgets('a slow request shows the bar, and it goes once idle',
      (tester) async {
    await pumpBar(tester);

    activity.begin();
    await tester.pump();
    await tester.pump(AppLoadingBar.showDelay + const Duration(milliseconds: 10));
    expect(opacity(tester), 1);

    activity.end();
    await tester.pump();
    await tester.pump(AppLoadingBar.minVisible);
    await tester.pump(AppLoadingBar.fade);
    expect(opacity(tester), 0);
  });

  testWidgets('the bar stays up for as long as the first load runs',
      (tester) async {
    container.read(startupLoadingProvider.notifier).start();
    await pumpBar(tester);

    await tester.pump(AppLoadingBar.showDelay + const Duration(milliseconds: 10));
    await tester.pump(const Duration(seconds: 2));
    expect(opacity(tester), 1);

    container.read(startupLoadingProvider.notifier).finish();
    await tester.pump();
    await tester.pump(AppLoadingBar.minVisible);
    await tester.pump(AppLoadingBar.fade);
    expect(opacity(tester), 0);
  });
}
