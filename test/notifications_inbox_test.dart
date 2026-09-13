import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/mock_notification_service.dart';
import 'helpers/test_harness.dart';

/// What the owner of an inbox can do to it.
///
/// The load-bearing group is the first: **"delete" means hidden, not
/// destroyed.** A notification is the record that the platform told somebody
/// their money moved, and support has to answer that months after the customer
/// tidied their list. If a future change turns dismissal into a real delete,
/// the row-count assertions here are what should stop it.
void main() {
  Future<(ProviderContainer, MockNotificationService)> inboxWith(
    int count,
  ) async {
    final service = MockNotificationService();
    final container = await createTestContainer(
      overrides: [notificationServiceProvider.overrideWithValue(service)],
    );
    for (var i = 0; i < count; i++) {
      await service.push(
        title: L('عنوان $i', 'Title $i'),
        body: L('نص $i', 'Body $i'),
      );
    }
    await container.read(notificationsProvider.notifier).load();
    return (container, service);
  }

  group('dismissal hides, it does not delete', () {
    test('dismissing one takes it off the list and keeps the row', () async {
      final (container, service) = await inboxWith(3);
      final target = container.read(notificationsProvider)[1];

      await container.read(notificationsProvider.notifier).dismiss(target.id);

      final visible = container.read(notificationsProvider);
      expect(visible, hasLength(2));
      expect(visible.map((n) => n.id), isNot(contains(target.id)));
      // The half that matters: the store still holds it.
      expect(service.allIncludingDismissed, hasLength(3));
      expect(
        service.allIncludingDismissed.map((n) => n.id),
        contains(target.id),
      );
    });

    test('dismissing all empties the list and keeps every row', () async {
      final (container, service) = await inboxWith(4);

      await container.read(notificationsProvider.notifier).dismissAll();

      expect(container.read(notificationsProvider), isEmpty);
      expect(service.allIncludingDismissed, hasLength(4));
    });

    test('a dismissed notification does not come back on a refetch', () async {
      final (container, _) = await inboxWith(2);
      final target = container.read(notificationsProvider).first;

      await container.read(notificationsProvider.notifier).dismiss(target.id);
      await container.read(notificationsProvider.notifier).load();

      expect(
        container.read(notificationsProvider).map((n) => n.id),
        isNot(contains(target.id)),
      );
    });
  });

  group('read state', () {
    test('opening the inbox does not mark anything read', () async {
      final (container, _) = await inboxWith(2);

      // The screen used to mark everything read from initState, which made the
      // unread count unobservable and "mark as read" a no-op.
      expect(container.read(unreadCountProvider), 2);
    });

    test('marking one read leaves the others alone', () async {
      final (container, _) = await inboxWith(3);
      final target = container.read(notificationsProvider)[2];

      await container.read(notificationsProvider.notifier).markRead(target.id);

      final byId = {
        for (final n in container.read(notificationsProvider)) n.id: n.read,
      };
      expect(byId[target.id], isTrue);
      expect(container.read(unreadCountProvider), 2);
    });

    test('marking all read clears the badge without hiding anything', () async {
      final (container, _) = await inboxWith(3);

      await container.read(notificationsProvider.notifier).markAllRead();

      expect(container.read(unreadCountProvider), 0);
      expect(container.read(notificationsProvider), hasLength(3));
    });

    test('marking read does not resurrect a dismissed notification', () async {
      final (container, _) = await inboxWith(3);
      final gone = container.read(notificationsProvider).first;
      await container.read(notificationsProvider.notifier).dismiss(gone.id);

      await container.read(notificationsProvider.notifier).markAllRead();

      expect(container.read(notificationsProvider), hasLength(2));
      expect(
        container.read(notificationsProvider).map((n) => n.id),
        isNot(contains(gone.id)),
      );
    });
  });

  test('a failed dismissal puts the card back', () async {
    final (container, service) = await inboxWith(2);
    final before = container.read(notificationsProvider);

    // An id the store has never heard of: the optimistic write removes
    // nothing, the call throws, and the rollback has to restore the list
    // rather than leave the reader looking at a lie.
    await expectLater(
      container.read(notificationsProvider.notifier).dismiss('not-a-real-id'),
      throwsA(anything),
    );

    expect(container.read(notificationsProvider), before);
    expect(service.allIncludingDismissed, hasLength(2));
  });
}
