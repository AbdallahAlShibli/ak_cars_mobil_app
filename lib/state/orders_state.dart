import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../data/models/order.dart';
import '../di/providers.dart';
import 'notifications_state.dart';

/// Parts-shop orders, newest first.
class OrdersNotifier extends Notifier<List<Order>> {
  final List<Timer> _timers = [];

  /// Whether this notifier has been torn down — see [RequestsNotifier]'s field
  /// of the same name; [load] has the identical hazard.
  bool _disposed = false;

  @override
  List<Order> build() {
    ref.onDispose(() {
      _disposed = true;
      for (final t in _timers) {
        t.cancel();
      }
    });
    return const [];
  }

  /// Loads the signed-in buyer's own orders from the server.
  ///
  /// Called by [SessionRefresh] at sign-in and at boot for a stored session.
  /// Before this existed `OrderRepository.fetchOrders` had no caller at all, so
  /// "طلباتي" showed only what had been bought since the app was last opened —
  /// an order placed yesterday was simply gone.
  ///
  /// Not started from [build], and guarded on a session, for the same two
  /// reasons as [RequestsNotifier.load].
  Future<void> load() async {
    if (_disposed) return;
    if (!await ref.read(tokenStoreProvider).mayHaveSession()) return;
    if (_disposed) return;
    try {
      final mine = await ref.read(orderRepositoryProvider).fetchOrders();
      if (_disposed) return;
      state = mine;
    } on UnauthorizedException {
      // Still reachable above the guard on an expired token.
    }
  }

  /// Drops this account's orders on sign-out — see
  /// `RequestsNotifier.clear`'s doc comment for why this is a direct `state =`
  /// write rather than `ref.invalidate(ordersProvider)`.
  void clear() => state = const [];

  Future<Order> place(List<OrderItem> items) async {
    final order = await ref.read(orderRepositoryProvider).placeOrder(items);
    state = [order, ...state];

    ref.read(notificationsProvider.notifier).adopt(
          await ref
              .read(notificationRepositoryProvider)
              .notifyOrderPlaced(order),
        );

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
}

final ordersProvider =
    NotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);
