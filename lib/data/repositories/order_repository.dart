import '../models/order.dart';
import '../services/order_service.dart';

/// Parts-shop orders.
///
/// Escrow rule: the store can move an order to *delivered*, but only the
/// buyer's [confirmReceipt] releases the payment — the two are separate
/// operations here so that rule cannot be bypassed by a generic status write.
abstract interface class OrderRepository {
  Future<List<Order>> fetchOrders();

  Future<Order> placeOrder(List<OrderItem> items);

  /// Store-side progression (placed → processing → delivered).
  Future<Order> advance(Order order);

  Future<Order> confirmReceipt(String orderId);
}

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._service);

  final OrderService _service;

  @override
  Future<List<Order>> fetchOrders() => _service.fetchOrders();

  @override
  Future<Order> placeOrder(List<OrderItem> items) =>
      _service.placeOrder(items);

  @override
  Future<Order> advance(Order order) async {
    final next = order.status.next;
    if (next == null) return order;
    return _service.updateStatus(order.id, next);
  }

  @override
  Future<Order> confirmReceipt(String orderId) =>
      _service.confirmReceipt(orderId);
}
