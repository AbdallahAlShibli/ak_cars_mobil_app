import '../../core/json/json_utils.dart';
import 'account_kind.dart';
import 'workshop_application.dart';

/// The signed-in user. Transactions (booking, checkout, publishing an ad)
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
    this.kind = AccountKind.customer,
    this.workshop,
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

  /// What this account said it is when it registered (spec §8). Defaults to
  /// [AccountKind.customer] — including on the wire, so a profile from before
  /// this field existed reads back as the customer it has always been.
  final AccountKind kind;

  /// The workshop registration this account submitted. Null whenever [kind] is
  /// [AccountKind.customer], and serialised only when present.
  ///
  /// Holding it on the profile is what lets `profile_screen.dart` show the
  /// applicant their own submission next to its status without going through
  /// the marketplace — they are not an approved workshop yet, so nothing in
  /// the provider catalogue is theirs to read.
  final WorkshopApplication? workshop;

  /// True when this account applied to be a workshop, whatever became of the
  /// application. Access is decided by the workshop's
  /// [ProviderOnboardingStage], never by this.
  bool get isWorkshopAccount => kind == AccountKind.workshop;

  factory UserProfile.fromJson(JsonMap json) => UserProfile(
        id: json.stringOrNull('id'),
        name: json.stringOr('name', ''),
        phone: json.stringOr('phone', ''),
        email: json.stringOr('email', ''),
        region: json.stringOr('region', ''),
        wilayat: json.stringOr('wilayat', ''),
        address: json.stringOr('address', ''),
        kind: AccountKindX.fromKey(json.stringOrNull('kind')),
        workshop: json.objectOrNull('workshop') == null
            ? null
            : WorkshopApplication.fromJson(json.requireObject('workshop')),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'region': region,
        'wilayat': wilayat,
        'address': address,
        'kind': kind.key,
        // Only when there is one: a customer profile carrying `"workshop":
        // null` invites a reader to think the field means something for them.
        if (workshop != null) 'workshop': workshop!.toJson(),
      };

  UserProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? region,
    String? wilayat,
    String? address,
    AccountKind? kind,
    WorkshopApplication? workshop,
  }) =>
      UserProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        region: region ?? this.region,
        wilayat: wilayat ?? this.wilayat,
        address: address ?? this.address,
        kind: kind ?? this.kind,
        workshop: workshop ?? this.workshop,
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
      other.address == address &&
      other.kind == kind &&
      other.workshop == workshop;

  @override
  int get hashCode => Object.hash(
      id, name, phone, email, region, wilayat, address, kind, workshop);
}
