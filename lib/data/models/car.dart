import '../../core/json/json_utils.dart';
import 'powertrain.dart';

/// A car saved in the user's garage, or selected ad-hoc for a request.
///
/// Everything past [year] is optional: registering a car must stay a
/// 30-second job, so the garage screen lets the user fill the rest in later
/// instead of demanding it up front.
class Car {
  const Car({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    this.nickname,
    this.trim,
    this.color,
    this.plate,
    this.odometerKm,
    this.governorate,
    this.wilayat,
    this.serviceDueKm,
    this.powertrain,
  });

  final String id;
  final String make;
  final String model;
  final int year;

  /// User's own name for the car ("Dad's Patrol"), shown instead of the
  /// make/model line when set.
  final String? nickname;

  final String? trim;
  final String? color;
  final String? plate;

  /// Last odometer reading the user entered for this car.
  final int? odometerKm;

  /// Where the car is registered/kept. Stored as the canonical English keys
  /// used by `LocationCatalog`, translated at render time.
  final String? governorate;
  final String? wilayat;

  final int? serviceDueKm;

  /// Petrol / diesel / hybrid / plug-in hybrid / electric.
  ///
  /// Optional like every other detail past [year] — null means "the owner has
  /// not told us", and the app falls back to combustion behaviour rather than
  /// guessing from the model name. Everything powertrain-specific (which
  /// maintenance items are due, which services and parts are relevant) reads
  /// this one field.
  final Powertrain? powertrain;

  String get label => '$make $model $year';

  /// What to show as the card title: the nickname when the user set one,
  /// otherwise the make/model/year.
  String get displayName =>
      (nickname?.trim().isNotEmpty ?? false) ? nickname!.trim() : label;

  /// True once the details beyond the required make/model/year are filled in.
  /// Drives the "complete your car details" nudge in the garage.
  ///
  /// Powertrain is deliberately not part of this: it is a one-tap field that
  /// changes what the app shows, not a detail a workshop needs before it can
  /// take the car in.
  bool get hasFullDetails =>
      plate != null && odometerKm != null && governorate != null;

  /// Driven by electricity alone — the flag the EV experience keys off.
  bool get isElectric => powertrain?.isFullyElectric ?? false;

  /// Plugs in to charge (electric or plug-in hybrid), so charging cables,
  /// ports and home chargers are part of owning it.
  bool get plugsIn => powertrain?.plugsIn ?? false;

  factory Car.fromJson(JsonMap json) => Car(
        id: json.requireString('id'),
        make: json.stringOr('make', ''),
        model: json.stringOr('model', ''),
        year: json.intOr('year', 0),
        nickname: json.stringOrNull('nickname'),
        trim: json.stringOrNull('trim'),
        color: json.stringOrNull('color'),
        plate: json.stringOrNull('plate'),
        odometerKm: json.intOrNull('odometerKm'),
        governorate: json.stringOrNull('governorate'),
        wilayat: json.stringOrNull('wilayat'),
        serviceDueKm: json.intOrNull('serviceDueKm'),
        // Accepts the wire key or a marketplace fuel value ("Plug-in Hybrid"),
        // and degrades to null rather than a guess.
        powertrain: PowertrainX.fromKey(json.stringOrNull('powertrain')),
      );

  JsonMap toJson() => {
        'id': id,
        'make': make,
        'model': model,
        'year': year,
        'nickname': nickname,
        'trim': trim,
        'color': color,
        'plate': plate,
        'odometerKm': odometerKm,
        'governorate': governorate,
        'wilayat': wilayat,
        'serviceDueKm': serviceDueKm,
        'powertrain': powertrain?.key,
      };

  /// Overwrites only the named fields. It cannot clear an optional field back
  /// to null — the edit screen rebuilds the whole [Car] instead, which is
  /// also what lets the user remove a nickname or plate they no longer want.
  Car copyWith({
    String? id,
    String? make,
    String? model,
    int? year,
    String? nickname,
    String? trim,
    String? color,
    String? plate,
    int? odometerKm,
    String? governorate,
    String? wilayat,
    int? serviceDueKm,
    Powertrain? powertrain,
  }) =>
      Car(
        id: id ?? this.id,
        make: make ?? this.make,
        model: model ?? this.model,
        year: year ?? this.year,
        nickname: nickname ?? this.nickname,
        trim: trim ?? this.trim,
        color: color ?? this.color,
        plate: plate ?? this.plate,
        odometerKm: odometerKm ?? this.odometerKm,
        governorate: governorate ?? this.governorate,
        wilayat: wilayat ?? this.wilayat,
        serviceDueKm: serviceDueKm ?? this.serviceDueKm,
        powertrain: powertrain ?? this.powertrain,
      );

  /// Full value equality, not id-only: Riverpod compares provider results with
  /// `==` to decide whether to notify listeners, so an id-only comparison
  /// would swallow edits such as [copyWith] on the same car.
  @override
  bool operator ==(Object other) =>
      other is Car &&
      other.id == id &&
      other.make == make &&
      other.model == model &&
      other.year == year &&
      other.nickname == nickname &&
      other.trim == trim &&
      other.color == color &&
      other.plate == plate &&
      other.odometerKm == odometerKm &&
      other.governorate == governorate &&
      other.wilayat == wilayat &&
      other.serviceDueKm == serviceDueKm &&
      other.powertrain == powertrain;

  @override
  int get hashCode => Object.hash(id, make, model, year, nickname, trim, color,
      plate, odometerKm, governorate, wilayat, serviceDueKm, powertrain);
}
