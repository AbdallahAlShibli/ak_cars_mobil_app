import '../../config/app_config.dart';
import '../../core/error/app_exception.dart';
import '../models/order.dart';
import 'mock_service_base.dart';

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

/// Keeps orders in memory for the length of the session, so the state layer
/// reads and writes through the same seam it will use against the API.
class MockOrderService with MockServiceBase implements OrderService {
  MockOrderService({required this.config});

  @override
  final AppConfig config;

  final List<Order> _orders = [];

  /// Mirrors a server-side identity sequence.
  int _nextOrderNumber = 1200;

  @override
  Future<List<Order>> fetchOrders() =>
      respond(List<Order>.unmodifiable(_orders));

  @override
  Future<Order> placeOrder(List<OrderItem> items) {
    final order = Order(
      id: 'A${_nextOrderNumber++}',
      items: items,
      total: items.fold<double>(0, (sum, i) => sum + i.total),
      status: OrderStatus.placed,
      placedAt: DateTime.now(),
    );
    _orders.insert(0, order);
    return respond(order);
  }

  @override
  Future<Order> updateStatus(String orderId, OrderStatus status) =>
      respond(_replace(orderId, (order) => order.copyWith(status: status)));

  @override
  Future<Order> confirmReceipt(String orderId) => respond(
        _replace(orderId, (order) {
          if (order.status != OrderStatus.delivered) {
            throw BusinessRuleException(
              'Order $orderId cannot be confirmed before it is delivered',
              code: 'ORDER_NOT_DELIVERED',
            );
          }
          return order.copyWith(status: OrderStatus.completed);
        }),
      );

  Order _replace(String orderId, Order Function(Order order) update) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) throw NotFoundException('Order $orderId not found');
    final updated = update(_orders[index]);
    _orders[index] = updated;
    return updated;
  }
}
