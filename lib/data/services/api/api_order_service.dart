import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../models/order.dart';
import '../order_service.dart';

/// Parts-shop checkout and order tracking over REST (§12).
///
/// There is no `/payments` endpoint — the backend creates an order already
/// in `Placed` status with no gateway call (see `ApiEndpoints.payments`'s
/// doc comment and `OrdersEndpoints.cs`'s explicit "no payment gateway in
/// this phase" note). [OrderService] has no payment-shaped method to stand
/// in for, so nothing here calls it; if one is ever added, it must not
/// invent a request to a route that does not exist.
class ApiOrderService implements OrderService {
  const ApiOrderService(this._client);

  final ApiClient _client;

  @override
  Future<List<Order>> fetchOrders() async =>
      (await _client.getList(ApiEndpoints.orders)).map(Order.fromJson).toList();

  @override
  Future<Order> placeOrder(List<OrderItem> items) async => Order.fromJson(
        await _client.post(
          ApiEndpoints.orders,
          body: {
            'items': [
              for (final item in items)
                {'productId': item.product.id, 'qty': item.qty},
            ],
          },
        ),
      );

  /// Store-side progression (placed → processing → delivered).
  ///
  /// **Not backed by any endpoint.** The backend only exposes the buyer's
  /// `delivered → completed` transition ([confirmReceipt]); there is no
  /// generic order-status write, because nothing in this phase plays the
  /// store/vendor role that would drive it. The UI's "Skip ahead" affordance
  /// (`orders_screen.dart`) is demo-only sugar for `simulateProviderLifecycle`
  /// — see `AppConfig.simulateProviderLifecycle`'s doc comment, which is
  /// already off in production. Rather than fail the whole order screen on a
  /// call the backend was never going to answer, this re-reads the order and
  /// returns it **unchanged** — a client-side no-op, not a real transition —
  /// so tapping it in a build where the button is still visible does nothing
  /// instead of throwing.
  @override
  Future<Order> updateStatus(String orderId, OrderStatus status) async =>
      Order.fromJson(await _client.get(ApiEndpoints.order(orderId)));

  @override
  Future<Order> confirmReceipt(String orderId) async => Order.fromJson(
        await _client.post(ApiEndpoints.confirmOrderReceipt(orderId)),
      );
}
