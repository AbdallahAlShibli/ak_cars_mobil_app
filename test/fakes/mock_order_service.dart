import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/data/models/order.dart';
import 'package:ak_cars_mobil_app/data/services/order_service.dart';

import 'fake_service_base.dart';

/// Keeps orders in memory for the length of the test, so the state layer reads
/// and writes through the same seam it uses against the API.
class MockOrderService with MockServiceBase implements OrderService {
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
