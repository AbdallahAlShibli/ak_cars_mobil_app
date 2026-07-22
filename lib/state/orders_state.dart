import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/order.dart';
import '../di/providers.dart';
import 'notifications_state.dart';

/// Parts-shop orders, newest first.
class OrdersNotifier extends Notifier<List<Order>> {
  final List<Timer> _timers = [];

  @override
  List<Order> build() {
    ref.onDispose(() {
      for (final t in _timers) {
        t.cancel();
      }
    });
    return const [];
  }

  Future<Order> place(List<OrderItem> items) async {
    final order = await ref.read(orderRepositoryProvider).placeOrder(items);
    state = [order, ...state];

    ref.read(notificationsProvider.notifier).adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyOrderPlaced(order),
        );

    if (ref.read(appConfigProvider).simulateProviderLifecycle) {
      _simulateStoreLifecycle(order.id);
    }
    return order;
  }

  /// Store-side progression (placed → processing → delivered).
  Future<void> advance(String id) async {
    final current = state.firstWhereOrNull((o) => o.id == id);
    if (current == null || current.status.next == null) return;

    final updated = await ref.read(orderRepositoryProvider).advance(current);
    _replace(updated);

    ref.read(notificationsProvider.notifier).adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyOrderStatus(updated, updated.status),
        );
  }

  /// Buyer confirms receipt → escrow released to the store.
  Future<void> confirmReceived(String id) async {
    final current = state.firstWhereOrNull((o) => o.id == id);
    if (current == null || current.status != OrderStatus.delivered) return;

    final updated =
        await ref.read(orderRepositoryProvider).confirmReceipt(id);
    _replace(updated);

    ref.read(notificationsProvider.notifier).adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyEscrowReleased(updated),
        );
  }

  void _replace(Order updated) => state = [
        for (final o in state)
          if (o.id == updated.id) updated else o,
      ];

  /// Staging stand-in for the vendor portal: prepare, then deliver. Delete
  /// once the backend pushes real order events.
  void _simulateStoreLifecycle(String orderId) {
    for (final seconds in const [7, 20]) {
      _timers.add(Timer(Duration(seconds: seconds), () => advance(orderId)));
    }
  }
}

final ordersProvider =
    NotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);
