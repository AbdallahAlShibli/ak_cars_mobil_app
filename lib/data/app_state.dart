import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gallery_data.dart';
import 'mock_data.dart';
import 'models.dart';

/// ---------------------------------------------------------------------------
/// Auth / registration (rule: transactions require a completed registration)
/// ---------------------------------------------------------------------------

class AuthState {
  const AuthState({
    this.profile,
    this.onboardingSeen = false,
    this.startChoiceMade = false,
  });

  final UserProfile? profile;
  final bool onboardingSeen;
  final bool startChoiceMade;

  bool get isRegistered => profile != null;

  AuthState copyWith({
    UserProfile? profile,
    bool? onboardingSeen,
    bool? startChoiceMade,
  }) =>
      AuthState(
        profile: profile ?? this.profile,
        onboardingSeen: onboardingSeen ?? this.onboardingSeen,
        startChoiceMade: startChoiceMade ?? this.startChoiceMade,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void markOnboardingSeen() => state = state.copyWith(onboardingSeen: true);

  void markStartChoiceMade() => state = state.copyWith(startChoiceMade: true);

  void register(UserProfile profile) => state = state.copyWith(
        profile: profile,
        onboardingSeen: true,
        startChoiceMade: true,
      );
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// ---------------------------------------------------------------------------
/// Garage — the user's saved cars (rule: car registration is optional)
/// ---------------------------------------------------------------------------

class GarageNotifier extends Notifier<List<Car>> {
  @override
  List<Car> build() => const [];

  void add(Car car) => state = [...state, car];

  void remove(String carId) =>
      state = state.where((c) => c.id != carId).toList();

  void setPrimary(String carId) {
    final car = state.firstWhereOrNull((c) => c.id == carId);
    if (car == null) return;
    state = [car, ...state.where((c) => c.id != carId)];
  }

  void setPlate(String carId, String plate) => state = [
        for (final c in state)
          if (c.id == carId) c.copyWith(plate: plate) else c,
      ];
}

final garageProvider =
    NotifierProvider<GarageNotifier, List<Car>>(GarageNotifier.new);

/// Primary car = first in the garage, or null when browsing without one.
final primaryCarProvider =
    Provider<Car?>((ref) => ref.watch(garageProvider).firstOrNull);

/// Selected region for service discovery.
final regionProvider = StateProvider<String>((ref) => MockData.regions.first);

/// ---------------------------------------------------------------------------
/// Service requests
/// ---------------------------------------------------------------------------

class RequestsNotifier extends Notifier<List<ServiceRequest>> {
  final List<Timer> _timers = [];

  @override
  List<ServiceRequest> build() {
    ref.onDispose(() {
      for (final t in _timers) {
        t.cancel();
      }
    });
    return const [];
  }

  void add(ServiceRequest request) {
    state = [request, ...state];
    _simulateProviderLifecycle(request);
  }

  void setStatus(String id, RequestStatus status) => state = [
        for (final r in state)
          if (r.id == id) r.copyWith(status: status) else r,
      ];

  /// Moves a request one step forward (used by the demo button and the
  /// simulated provider). Never overrides completed/disputed.
  void advance(String id) {
    final r = state.firstWhereOrNull((r) => r.id == id);
    if (r == null) return;
    final next = switch (r.status) {
      RequestStatus.requested => RequestStatus.accepted,
      RequestStatus.accepted => RequestStatus.inProgress,
      RequestStatus.inProgress => RequestStatus.proofSubmitted,
      _ => null,
    };
    if (next == null) return;
    setStatus(id, next);
    final notifications = ref.read(notificationsProvider.notifier);
    switch (next) {
      case RequestStatus.accepted:
        notifications.push(
          title: 'Request #$id accepted',
          body:
              '${r.offering.provider.name} accepted your booking for ${r.slot}.',
          icon: Icons.thumb_up_alt_outlined,
          route: '/track/$id',
        );
      case RequestStatus.inProgress:
        notifications.push(
          title: 'Work started on #$id',
          body: '${r.offering.provider.name} is working on your ${r.car.label}.',
          icon: Icons.build_rounded,
          route: '/track/$id',
        );
      case RequestStatus.proofSubmitted:
        notifications.push(
          title: 'Work completed — review needed',
          body:
              '${r.offering.provider.name} uploaded proof photos for #$id. Approve to release OMR ${r.total.toStringAsFixed(2)}.',
          icon: Icons.fact_check_outlined,
          route: '/approve/$id',
        );
      default:
        break;
    }
  }

  /// Demo stand-in for the provider portal: accepts after a few seconds,
  /// starts work, then submits completion proof.
  void _simulateProviderLifecycle(ServiceRequest request) {
    void at(int seconds) {
      _timers.add(Timer(Duration(seconds: seconds), () => advance(request.id)));
    }

    at(6);
    at(18);
    at(35);
  }
}

final requestsProvider =
    NotifierProvider<RequestsNotifier, List<ServiceRequest>>(
        RequestsNotifier.new);

final activeRequestProvider = Provider<ServiceRequest?>((ref) {
  final all = ref.watch(requestsProvider);
  for (final r in all) {
    if (r.status != RequestStatus.completed) return r;
  }
  return null;
});

/// ---------------------------------------------------------------------------
/// Shop — cart, favorites, filters (rule: shop is NOT locked to saved car)
/// ---------------------------------------------------------------------------

class CartNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void toggle(Product p) {
    final next = Map<String, int>.from(state);
    if (next.containsKey(p.id)) {
      next.remove(p.id);
    } else {
      next[p.id] = 1;
    }
    state = next;
  }

  void setQty(String productId, int qty) {
    final next = Map<String, int>.from(state);
    if (qty <= 0) {
      next.remove(productId);
    } else {
      next[productId] = qty;
    }
    state = next;
  }

  void clear() => state = const {};
}

/// Cart resolved to products + quantities.
final cartItemsProvider = Provider<List<OrderItem>>((ref) {
  final cart = ref.watch(cartProvider);
  return [
    for (final e in cart.entries)
      if (MockData.products.firstWhereOrNull((p) => p.id == e.key)
          case final p?)
        OrderItem(product: p, qty: e.value),
  ];
});

final cartTotalProvider = Provider<double>((ref) => ref
    .watch(cartItemsProvider)
    .fold<double>(0, (sum, i) => sum + i.total));

/// ---------------------------------------------------------------------------
/// Orders (parts shop)
/// ---------------------------------------------------------------------------

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

  Order place(List<OrderItem> items, double total) {
    final order = Order(
      id: 'A${1200 + state.length}',
      items: items,
      total: total,
      status: OrderStatus.placed,
      placedAt: DateTime.now(),
    );
    state = [order, ...state];
    // Simulated store lifecycle: prepare, then deliver.
    _timers.add(Timer(const Duration(seconds: 7), () => advance(order.id)));
    _timers.add(Timer(const Duration(seconds: 20), () => advance(order.id)));
    return order;
  }

  void _setStatus(String id, OrderStatus status) => state = [
        for (final o in state)
          if (o.id == id) o.copyWith(status: status) else o,
      ];

  /// Store-side progression (staging stand-in for the vendor portal).
  void advance(String id) {
    final o = state.firstWhereOrNull((o) => o.id == id);
    if (o == null) return;
    final next = switch (o.status) {
      OrderStatus.placed => OrderStatus.processing,
      OrderStatus.processing => OrderStatus.delivered,
      _ => null,
    };
    if (next == null) return;
    _setStatus(id, next);
    final notifications = ref.read(notificationsProvider.notifier);
    if (next == OrderStatus.processing) {
      notifications.push(
        title: 'Order $id is being prepared',
        body: 'The store is packing your ${o.items.length} part(s).',
        icon: Icons.inventory_2_outlined,
        route: '/orders',
      );
    } else {
      notifications.push(
        title: 'Order $id delivered',
        body:
            'Confirm receipt to release OMR ${o.total.toStringAsFixed(2)} to the store.',
        icon: Icons.local_shipping_outlined,
        route: '/orders',
      );
    }
  }

  /// Buyer confirms receipt → escrow released to the store.
  void confirmReceived(String id) {
    final o = state.firstWhereOrNull((o) => o.id == id);
    if (o == null || o.status != OrderStatus.delivered) return;
    _setStatus(id, OrderStatus.completed);
    ref.read(notificationsProvider.notifier).push(
          title: 'Payment released for order $id',
          body:
              'OMR ${o.total.toStringAsFixed(2)} released to the store — thanks for confirming.',
          icon: Icons.lock_open_rounded,
          route: '/payments',
        );
  }
}

final ordersProvider =
    NotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);

/// ---------------------------------------------------------------------------
/// My car ads (gallery)
/// ---------------------------------------------------------------------------

class MyAdsNotifier extends Notifier<List<GalleryListing>> {
  @override
  List<GalleryListing> build() => const [];

  void add(GalleryListing ad) => state = [ad, ...state];

  void remove(String id) =>
      state = state.where((a) => a.id != id).toList();
}

final myAdsProvider =
    NotifierProvider<MyAdsNotifier, List<GalleryListing>>(MyAdsNotifier.new);

/// Full gallery feed = user's ads first, then platform listings.
final galleryFeedProvider = Provider<List<GalleryListing>>(
    (ref) => [...ref.watch(myAdsProvider), ...GalleryData.listings]);

/// ---------------------------------------------------------------------------
/// Notifications
/// ---------------------------------------------------------------------------

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => const [];

  void push({
    required String title,
    required String body,
    IconData icon = Icons.notifications_outlined,
    String? route,
  }) {
    state = [
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        icon: icon,
        time: DateTime.now(),
        route: route,
      ),
      ...state,
    ];
  }

  void markAllRead() =>
      state = [for (final n in state) n.copyWith(read: true)];
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
        NotificationsNotifier.new);

final unreadCountProvider = Provider<int>(
    (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length);

/// ---------------------------------------------------------------------------
/// Per-request chat
/// ---------------------------------------------------------------------------

class ChatNotifier extends Notifier<Map<String, List<ChatMessage>>> {
  @override
  Map<String, List<ChatMessage>> build() => const {};

  void add(String requestId, ChatMessage message) {
    state = {
      ...state,
      requestId: [...(state[requestId] ?? const []), message],
    };
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, Map<String, List<ChatMessage>>>(
        ChatNotifier.new);

final cartProvider =
    NotifierProvider<CartNotifier, Map<String, int>>(CartNotifier.new);

class ShopFilterNotifier extends Notifier<ShopFilter> {
  @override
  ShopFilter build() {
    // Default: suggest the user's saved car, but never lock to it.
    final car = ref.watch(primaryCarProvider);
    return ShopFilter(car: car);
  }

  void set(ShopFilter filter) => state = filter;

  void clearCar() => state = state.copyWith(car: () => null);
}

final shopFilterProvider =
    NotifierProvider<ShopFilterNotifier, ShopFilter>(ShopFilterNotifier.new);

/// Instant, local-first filtering — applies as the user taps.
final filteredProductsProvider = Provider<List<Product>>((ref) {
  final f = ref.watch(shopFilterProvider);
  return MockData.products.where((p) {
    if (!p.fitsCar(f.car)) return false;
    if (f.categoryId != null && p.categoryId != f.categoryId) return false;
    if (f.providerId != null && p.providerId != f.providerId) return false;
    if (f.region != null && p.region != f.region) return false;
    if (p.price < f.minPrice || p.price > f.maxPrice) return false;
    return true;
  }).toList();
});

final favoritesProvider = StateProvider<Set<String>>((ref) => {});
