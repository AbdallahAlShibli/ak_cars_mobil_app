import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';

/// An optional extra a provider can attach to a booking. [isPart] separates
/// physical parts (which affect the escrow/parts split) from labour.
class AddOn {
  const AddOn({
    required this.id,
    required this.name,
    required this.price,
    required this.isPart,
  });

  final String id;
  final L name;
  final double price;
  final bool isPart;

  factory AddOn.fromJson(JsonMap json) => AddOn(
        id: json.requireString('id'),
        name: L.fromJson(json['name']),
        price: json.doubleOr('price', 0),
        isPart: json.boolOr('isPart', false),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name.toJson(),
        'price': price,
        'isPart': isPart,
      };

  AddOn copyWith({String? id, L? name, double? price, bool? isPart}) => AddOn(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        isPart: isPart ?? this.isPart,
      );

  @override
  bool operator ==(Object other) =>
      other is AddOn &&
      other.id == id &&
      other.name == name &&
      other.price == price &&
      other.isPart == isPart;

  @override
  int get hashCode => Object.hash(id, name, price, isPart);
}
