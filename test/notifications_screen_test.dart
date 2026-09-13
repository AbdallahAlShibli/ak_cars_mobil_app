import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/app_notification.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/home/notifications_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/mock_notification_service.dart';
import 'helpers/test_harness.dart';

/// The notifications *screen*, as opposed to the notifier underneath it
/// (`notifications_inbox_test.dart`).
///
/// These exist because the first cut of this screen shipped two bugs that only
/// a widget test could catch, both from the same root cause — the list wrote
/// optimistically and matched its rows by index:
///
///  * a dismissal the server refused put the same key back into a tree that
///    had already recorded it as dismissed, which trips `Dismissible`'s own
///    assertion;
///  * and the rollback did not restore the card, so a failed swipe silently
///    lost a notification until the next fetch.
///
/// The fix was to hold the swipe open across the round trip (`confirmDismiss`)
/// and to key each row by notification id. Both halves are pinned below.
class FlakyNotificationService extends MockNotificationService {
  bool failDismiss = false;

  @override
  Future<List<AppNotification>> dismiss(String id) {
    if (failDismiss) throw const NetworkException('offline');
    return super.dismiss(id);
  }
}

void main() {
  // Scoped to the list: Flutter's own SnackBar is a Dismissible too, so a
  // bare byType count silently includes the error toast.
  Finder cards() => find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Dismissible),
  );

  Future<FlakyNotificationService> pump(
    WidgetTester tester, {
    int count = 3,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final service = FlakyNotificationService();
    final container = await createTestContainer(
      overrides: [notificationServiceProvider.overrideWithValue(service)],
    );
    for (var i = 0; i < count; i++) {
      await service.push(title: L('ع', 'Title'), body: L('ن', 'Body'));
    }
    await container.read(notificationsProvider.notifier).load();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    return service;
  }

  testWidgets('swipe dismisses a card', (tester) async {
    final service = await pump(tester);
    await tester.drag(find.byType(Dismissible).first, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(cards(), findsNWidgets(2));
    expect(service.allIncludingDismissed, hasLength(3));
  });

  testWidgets('a swipe the server refuses puts the card back', (tester) async {
    final service = await pump(tester);
    service.failDismiss = true;
    await tester.drag(find.byType(Dismissible).first, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(cards(), findsNWidgets(3));
  });

  testWidgets('tapping a card marks it read', (tester) async {
    await pump(tester, count: 2);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NotificationsScreen)),
    );
    expect(container.read(unreadCountProvider), 2);

    await tester.tap(cards().first);
    await tester.pumpAndSettle();

    expect(container.read(unreadCountProvider), 1);
  });

  testWidgets('deleting the last card shows the empty state', (tester) async {
    await pump(tester, count: 1);
    await tester.drag(cards().first, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('a push arriving while the list is open lands on top', (
    tester,
  ) async {
    final service = await pump(tester, count: 2);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NotificationsScreen)),
    );

    final fresh = await service.push(title: L('ج', 'Fresh'), body: L('ن', 'B'));
    container.read(notificationsProvider.notifier).adopt(fresh);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    expect(cards(), findsNWidgets(3));
    expect(container.read(notificationsProvider).first.id, fresh.id);
  });

  testWidgets('deleting after a push removes the right card', (tester) async {
    final service = await pump(tester, count: 2);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NotificationsScreen)),
    );
    final fresh = await service.push(title: L('ج', 'Fresh'), body: L('ن', 'B'));
    container.read(notificationsProvider.notifier).adopt(fresh);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    // Swipe the top one — the pushed card. Index-matched elements would take
    // the wrong row's state here.
    await tester.drag(cards().first, const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(cards(), findsNWidgets(2));
    expect(
      container.read(notificationsProvider).map((n) => n.id),
      isNot(contains(fresh.id)),
    );
    await tester.pump(const Duration(milliseconds: 600));
  });
}
