import '../../core/json/json_utils.dart';

/// One selectable spec value plus its bilingual label.
///
/// [value] is what gets persisted on a listing and sent to the API; the
/// labels are display-only. Keep `value` strings stable across releases.
class SpecOption<T> {
  const SpecOption(this.value, this.ar, this.en);

  final T value;
  final String ar;
  final String en;

  String label(bool isAr) => isAr ? ar : en;

  /// [readValue] adapts the raw JSON value to [T] (String, int, …).
  factory SpecOption.fromJson(JsonMap json, T Function(Object? raw) readValue) =>
      SpecOption(
        readValue(json['value']),
        json.stringOr('ar', ''),
        json.stringOr('en', ''),
      );

  JsonMap toJson() => {'value': value, 'ar': ar, 'en': en};

  SpecOption<T> copyWith({T? value, String? ar, String? en}) =>
      SpecOption(value ?? this.value, ar ?? this.ar, en ?? this.en);

  @override
  bool operator ==(Object other) =>
      other is SpecOption<T> &&
      other.value == value &&
      other.ar == ar &&
      other.en == en;

  @override
  int get hashCode => Object.hash(value, ar, en);
}

/// Engine-displacement bucket in litres; both bounds inclusive.
class EngineBucket {
  const EngineBucket(this.value, this.ar, this.en, this.min, this.max);

  final String value;
  final String ar;
  final String en;
  final double min;
  final double max;

  bool contains(double litres) => litres >= min && litres <= max;

  String label(bool isAr) => isAr ? ar : en;

  factory EngineBucket.fromJson(JsonMap json) => EngineBucket(
        json.requireString('value'),
        json.stringOr('ar', ''),
        json.stringOr('en', ''),
        json.doubleOr('min', 0),
        json.doubleOr('max', 0),
      );

  JsonMap toJson() => {
        'value': value,
        'ar': ar,
        'en': en,
        'min': min,
        'max': max,
      };

  EngineBucket copyWith({
    String? value,
    String? ar,
    String? en,
    double? min,
    double? max,
  }) =>
      EngineBucket(
        value ?? this.value,
        ar ?? this.ar,
        en ?? this.en,
        min ?? this.min,
        max ?? this.max,
      );

  @override
  bool operator ==(Object other) =>
      other is EngineBucket &&
      other.value == value &&
      other.ar == ar &&
      other.en == en &&
      other.min == min &&
      other.max == max;

  @override
  int get hashCode => Object.hash(value, ar, en, min, max);
}
