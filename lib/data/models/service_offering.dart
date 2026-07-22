import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'service_provider.dart';

/// A concrete service a specific provider sells within a category.
class ServiceOffering {
  const ServiceOffering({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.provider,
    required this.description,
    this.price,
    this.durationMin,
  });

  final String id;
  final String categoryId;
  final L name;

  /// Expanded relation: the API returns the provider inline on this endpoint
  /// so a listing screen never has to fan out N requests.
  final ServiceProvider provider;

  final L description;

  /// Null means "quote after inspection".
  final double? price;
  final int? durationMin;

  factory ServiceOffering.fromJson(JsonMap json) => ServiceOffering(
        id: json.requireString('id'),
        categoryId: json.stringOr('categoryId', ''),
        name: L.fromJson(json['name']),
        provider: ServiceProvider.fromJson(json.requireObject('provider')),
        description: L.fromJson(json['description']),
        price: json.doubleOrNull('price'),
        durationMin: json.intOrNull('durationMin'),
      );

  JsonMap toJson() => {
        'id': id,
        'categoryId': categoryId,
        'name': name.toJson(),
        'provider': provider.toJson(),
        'description': description.toJson(),
        'price': price,
        'durationMin': durationMin,
      };

  ServiceOffering copyWith({
    String? id,
    String? categoryId,
    L? name,
    ServiceProvider? provider,
    L? description,
    double? price,
    int? durationMin,
  }) =>
      ServiceOffering(
        id: id ?? this.id,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        provider: provider ?? this.provider,
        description: description ?? this.description,
        price: price ?? this.price,
        durationMin: durationMin ?? this.durationMin,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceOffering &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.name == name &&
      other.provider == provider &&
      other.description == description &&
      other.price == price &&
      other.durationMin == durationMin;

  @override
  int get hashCode => Object.hash(
        id,
        categoryId,
        name,
        provider,
        description,
        price,
        durationMin,
      );
}
