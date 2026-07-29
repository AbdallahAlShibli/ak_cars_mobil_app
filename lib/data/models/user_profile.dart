import '../../core/json/json_utils.dart';

/// The signed-in customer. Transactions (booking, checkout, publishing an ad)
/// require a completed registration; browsing does not.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.region,
    required this.address,
    this.wilayat = '',
    this.id,
  });

  /// Server-assigned identifier. Null until registration round-trips through
  /// the API — the mock service leaves it unset.
  final String? id;
  final String name;
  final String phone;
  final String email;

  /// Canonical English governorate key.
  final String region;

  /// Canonical English wilayat key within [region]. Empty when not given —
  /// it narrows the address, it does not gate registration.
  final String wilayat;

  /// Street/area line, below the wilayat.
  final String address;

  factory UserProfile.fromJson(JsonMap json) => UserProfile(
        id: json.stringOrNull('id'),
        name: json.stringOr('name', ''),
        phone: json.stringOr('phone', ''),
        email: json.stringOr('email', ''),
        region: json.stringOr('region', ''),
        wilayat: json.stringOr('wilayat', ''),
        address: json.stringOr('address', ''),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'region': region,
        'wilayat': wilayat,
        'address': address,
      };

  UserProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? region,
    String? wilayat,
    String? address,
  }) =>
      UserProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        region: region ?? this.region,
        wilayat: wilayat ?? this.wilayat,
        address: address ?? this.address,
      );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.email == email &&
      other.region == region &&
      other.wilayat == wilayat &&
      other.address == address;

  @override
  int get hashCode =>
      Object.hash(id, name, phone, email, region, wilayat, address);
}
