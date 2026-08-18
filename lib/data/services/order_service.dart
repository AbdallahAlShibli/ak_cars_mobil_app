import '../models/order.dart';

/// Parts-shop checkout and order tracking.
///
/// Escrow rule: payment is held until the buyer confirms receipt, so
/// [confirmReceipt] is a distinct call rather than another status update —
/// it is the one transition the *buyer* is allowed to make.
///
/// Phase 2: implement `RestOrderService` against `/orders`.
abstract interface class OrderService {
  Future<List<Order>> fetchOrders();

  /// Places an order for the given cart lines and returns the created order.
  Future<Order> placeOrder(List<OrderItem> items);

  /// Store-side progression (placed → processing → delivered).
  Future<Order> updateStatus(String orderId, OrderStatus status);

  /// Buyer confirms receipt → escrow released to the store.
  Future<Order> confirmReceipt(String orderId);
}
