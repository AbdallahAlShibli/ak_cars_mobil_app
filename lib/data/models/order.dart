import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'product.dart';

enum OrderStatus { placed, processing, delivered, completed }

extension OrderStatusX on OrderStatus {
  String label(S s) => switch (this) {
        OrderStatus.placed => s.t('تم الطلب', 'Placed'),
        OrderStatus.processing => s.t('قيد التجهيز', 'Being prepared'),
        OrderStatus.delivered =>
          s.t('تم التوصيل — أكد الاستلام', 'Delivered — confirm receipt'),
        OrderStatus.completed => s.t('مكتمل', 'Completed'),
      };

  /// Escrow is held until the buyer confirms they received the parts.
  bool get held => this != OrderStatus.completed;

  String get key => name;

  /// Store-side progression. Null once the store's part is done — only the
  /// buyer's confirmation moves [delivered] to [completed].
  OrderStatus? get next => switch (this) {
        OrderStatus.placed => OrderStatus.processing,
        OrderStatus.processing => OrderStatus.delivered,
        _ => null,
      };
}

/// One line of an order: an expanded product plus quantity.
class OrderItem {
  const OrderItem({required this.product, required this.qty});

  final Product product;
  final int qty;

  double get total => product.price * qty;

  factory OrderItem.fromJson(JsonMap json) => OrderItem(
        product: Product.fromJson(json.requireObject('product')),
        qty: json.intOr('qty', 1),
      );

  JsonMap toJson() => {'product': product.toJson(), 'qty': qty};

  OrderItem copyWith({Product? product, int? qty}) => OrderItem(
        product: product ?? this.product,
        qty: qty ?? this.qty,
      );

  @override
  bool operator ==(Object other) =>
      other is OrderItem && other.product == product && other.qty == qty;

  @override
  int get hashCode => Object.hash(product, qty);
}

class Order {
  const Order({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.placedAt,
  });

  final String id;
  final List<OrderItem> items;
  final double total;
  final OrderStatus status;
  final DateTime placedAt;

  factory Order.fromJson(JsonMap json) => Order(
        id: json.requireString('id'),
        items: json.objectList('items').map(OrderItem.fromJson).toList(),
        total: json.doubleOr('total', 0),
        status: json.enumOr('status', OrderStatus.values, OrderStatus.placed),
        placedAt: json.dateTimeOr('placedAt', DateTime.now()),
      );

  JsonMap toJson() => {
        'id': id,
        'items': [for (final i in items) i.toJson()],
        'total': total,
        'status': status.key,
        'placedAt': placedAt.toIso8601String(),
      };

  Order copyWith({
    String? id,
    List<OrderItem>? items,
    double? total,
    OrderStatus? status,
    DateTime? placedAt,
  }) =>
      Order(
        id: id ?? this.id,
        items: items ?? this.items,
        total: total ?? this.total,
        status: status ?? this.status,
        placedAt: placedAt ?? this.placedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Order &&
      other.id == id &&
      other.total == total &&
      other.status == status &&
      other.placedAt == placedAt &&
      other.items.length == items.length &&
      Object.hashAll(other.items) == Object.hashAll(items);

  @override
  int get hashCode =>
      Object.hash(id, total, status, placedAt, Object.hashAll(items));
}

/// Body sent to `POST /orders` — the server prices and ids the order.
class CreateOrderPayload {
  const CreateOrderPayload({required this.lines});

  /// Product id → quantity.
  final Map<String, int> lines;

  JsonMap toJson() => {
        'items': [
          for (final entry in lines.entries)
            {'productId': entry.key, 'qty': entry.value},
        ],
      };
}
