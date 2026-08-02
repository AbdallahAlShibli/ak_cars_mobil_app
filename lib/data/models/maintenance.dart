import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'powertrain.dart';

/// Built-in maintenance items the app tracks a countdown for.
///
/// Everything here is computed from data the *user* enters (odometer
/// readings, manual records) plus service records created inside the app. The
/// app never reads anything from the car itself, and items with no record
/// never show a percentage. That applies to [evBattery] too: an EV's real
/// state of health is only ever what an inspection recorded, never a live
/// reading the app invented.
///
/// Which items a given car actually has is [MaintenanceTypeX.appliesTo] — an
/// electric car has no engine oil, and its 12V battery and battery-pack health
/// are the items that take oil's place. On top of these a car can carry any
/// number of [CustomMaintenanceItem]s its owner added.
enum MaintenanceType {
  oil,
  tyres,
  coolant,
  cabinFilter,
  brakeFluid,
  battery12v,
  evBattery;

  /// Stable wire value, and the key this item's records and intervals are
  /// filed under inside a [MaintenanceBook].
  String get key => name;
}

extension MaintenanceTypeX on MaintenanceType {
  L get title => switch (this) {
        MaintenanceType.oil =>
          const L('زيت المحرك + الفلتر', 'Engine oil + filter'),
        MaintenanceType.tyres =>
          const L('فحص وترصيص الإطارات', 'Tyre check & alignment'),
        MaintenanceType.coolant => const L('سائل التبريد', 'Coolant'),
        MaintenanceType.cabinFilter =>
          const L('فلتر مقصورة المكيف', 'Cabin air filter'),
        MaintenanceType.brakeFluid => const L('سائل الفرامل', 'Brake fluid'),
        MaintenanceType.battery12v =>
          const L('بطارية ١٢ فولت المساعدة', '12V auxiliary battery'),
        MaintenanceType.evBattery => const L(
            'فحص صحة بطارية السيارة الكهربائية',
            'EV battery health inspection',
          ),
      };

  L get shortTitle => switch (this) {
        MaintenanceType.oil => const L('زيت المحرك', 'Engine oil'),
        MaintenanceType.tyres => const L('فحص الإطارات', 'Tyre check'),
        MaintenanceType.coolant => const L('سائل التبريد', 'Coolant'),
        MaintenanceType.cabinFilter =>
          const L('فلتر المقصورة', 'Cabin filter'),
        MaintenanceType.brakeFluid => const L('سائل الفرامل', 'Brake fluid'),
        MaintenanceType.battery12v => const L('بطارية ١٢ فولت', '12V battery'),
        MaintenanceType.evBattery =>
          const L('صحة البطارية', 'Battery health'),
      };

  /// Whether this item has a distance interval at all — see [defaultKm].
  bool get kmBased => defaultKm != null;

  /// Default interval in kilometres, or null for an item that is only ever
  /// measured in time.
  ///
  /// A 12V battery and a battery-health inspection age on the calendar, not
  /// on the odometer; everything else comes due on whichever of distance or
  /// time arrives first, which is how a workshop quotes them.
  int? get defaultKm => switch (this) {
        MaintenanceType.oil => MaintenanceBook.defaultKmInterval,
        MaintenanceType.tyres => 10000,
        MaintenanceType.cabinFilter => 15000,
        MaintenanceType.brakeFluid => 40000,
        MaintenanceType.coolant => 60000,
        MaintenanceType.battery12v || MaintenanceType.evBattery => null,
      };

  /// Default interval in months, used when the user has not set one of their
  /// own. Per item rather than one global number: a cabin filter and a
  /// coolant change are nowhere near the same schedule.
  int get defaultMonths => switch (this) {
        MaintenanceType.tyres => 6,
        MaintenanceType.coolant => 24,
        MaintenanceType.cabinFilter => 12,
        MaintenanceType.brakeFluid => 24,
        MaintenanceType.battery12v => 12,
        MaintenanceType.evBattery => 12,
        MaintenanceType.oil => MaintenanceBook.defaultMonthInterval,
      };

  /// Whether a car with this [powertrain] has this item at all.
  ///
  /// A null powertrain means the owner has not said, so the combustion set is
  /// used — the app's behaviour before this field existed, unchanged.
  ///
  /// The EV-only items are the ones that replace the oil-centric routine on a
  /// fully electric car. They exist on a petrol car too, but there they are
  /// checked inside the oil service rather than tracked separately, so listing
  /// them for a petrol owner would add reminders for work they already pay for
  /// in one line.
  bool appliesTo(Powertrain? powertrain) {
    final electric = powertrain?.isFullyElectric ?? false;
    return switch (this) {
      MaintenanceType.oil => powertrain?.hasEngine ?? true,
      MaintenanceType.tyres || MaintenanceType.coolant => true,
      MaintenanceType.cabinFilter ||
      MaintenanceType.brakeFluid ||
      MaintenanceType.battery12v =>
        electric,
      // Hybrids and plug-in hybrids carry a traction pack worth inspecting
      // too, so this one is not electric-only.
      MaintenanceType.evBattery => powertrain?.hasHighVoltageBattery ?? false,
    };
  }

  /// [title], reworded where the same item means something different on an
  /// electric car: an EV's coolant loop cools the battery and inverter, not an
  /// engine, and calling it plain "coolant" sends the owner looking for a
  /// radiator cap.
  L titleFor(Powertrain? powertrain) =>
      this == MaintenanceType.coolant && (powertrain?.isFullyElectric ?? false)
          ? const L('تبريد البطارية والمنظومة الحرارية',
              'Battery & thermal coolant')
          : title;

  L shortTitleFor(Powertrain? powertrain) =>
      this == MaintenanceType.coolant && (powertrain?.isFullyElectric ?? false)
          ? const L('تبريد البطارية', 'Battery coolant')
          : shortTitle;

  /// The built-in items a car with this [powertrain] should see, in display
  /// order. A new car's maintenance book starts with exactly these and no
  /// records against any of them.
  static List<MaintenanceType> forPowertrain(Powertrain? powertrain) => [
        for (final type in MaintenanceType.values)
          if (type.appliesTo(powertrain)) type,
      ];

  /// The built-in item a booked service category resets, or null when the
  /// category maps to no schedule line the app tracks.
  ///
  /// Takes the category's **slug**, not its id. Ids are GUIDs and say only
  /// which row; the slug is what says the booking was an oil change. See
  /// `ServiceCategory.slug`.
  ///
  /// Deliberately conservative: a category is mapped only where the work it
  /// names *is* the maintenance item. A body-repair or detailing booking
  /// resets nothing, and pretending otherwise would silently push a real oil
  /// change further away.
  static MaintenanceType? forCategory(String categorySlug) =>
      switch (categorySlug) {
        'express' || 'full' || 'major' => MaintenanceType.oil,
        'tyres' => MaintenanceType.tyres,
        'battery' => MaintenanceType.battery12v,
        'ac' => MaintenanceType.cabinFilter,
        'ev-battery' || 'ev-check' => MaintenanceType.evBattery,
        _ => null,
      };
}

/// An extra maintenance line the owner added for this car — wipers, spark
/// plugs, gearbox oil, brake pads, a home-charger inspection.
///
/// [title] is the owner's own words and is shown verbatim in both languages.
/// The app does not translate user-entered text, and inventing an Arabic
/// rendering of "gearbox oil — Salim's workshop" would be a fabrication, not a
/// translation.
class CustomMaintenanceItem {
  const CustomMaintenanceItem({
    required this.id,
    required this.title,
    this.intervalKm,
    this.intervalMonths,
  });

  final String id;
  final String title;

  /// The item's own schedule. Both are optional and both may be set, matching
  /// the built-in rule: due at whichever runs out first.
  final int? intervalKm;
  final int? intervalMonths;

  /// A custom item with neither interval has nothing to count down to, so the
  /// screen shows its history instead of a false progress bar.
  bool get hasSchedule => intervalKm != null || intervalMonths != null;

  factory CustomMaintenanceItem.fromJson(JsonMap json) => CustomMaintenanceItem(
        id: json.requireString('id'),
        title: json.stringOr('title', ''),
        intervalKm: json.intOrNull('intervalKm'),
        intervalMonths: json.intOrNull('intervalMonths'),
      );

  JsonMap toJson() => {
        'id': id,
        'title': title,
        'intervalKm': intervalKm,
        'intervalMonths': intervalMonths,
      };

  /// Rebuilds the whole item rather than patching it: an interval the user
  /// cleared has to be expressible, and `copyWith`'s null means "unchanged".
  CustomMaintenanceItem copyWith({String? id, String? title}) =>
      CustomMaintenanceItem(
        id: id ?? this.id,
        title: title ?? this.title,
        intervalKm: intervalKm,
        intervalMonths: intervalMonths,
      );

  @override
  bool operator ==(Object other) =>
      other is CustomMaintenanceItem &&
      other.id == id &&
      other.title == title &&
      other.intervalKm == intervalKm &&
      other.intervalMonths == intervalMonths;

  @override
  int get hashCode => Object.hash(id, title, intervalKm, intervalMonths);
}

/// One line of a car's maintenance schedule, whichever kind it is.
///
/// The screens render this rather than branching on "built-in or custom"
/// everywhere: a custom item has a title, a key, and a default schedule just
/// like an engine-oil line does.
class MaintenanceItem {
  const MaintenanceItem({
    required this.key,
    required this.title,
    required this.shortTitle,
    this.type,
    this.custom,
    this.defaultKm,
    this.defaultMonths,
  });

  /// The key this item's records and interval overrides are filed under.
  final String key;

  final L title;
  final L shortTitle;

  /// Set for a built-in item, null for a custom one.
  final MaintenanceType? type;

  /// Set for a custom item, null for a built-in one.
  final CustomMaintenanceItem? custom;

  final int? defaultKm;
  final int? defaultMonths;

  bool get isCustom => custom != null;

  factory MaintenanceItem.builtIn(
    MaintenanceType type, [
    Powertrain? powertrain,
  ]) =>
      MaintenanceItem(
        key: type.key,
        title: type.titleFor(powertrain),
        shortTitle: type.shortTitleFor(powertrain),
        type: type,
        defaultKm: type.defaultKm,
        defaultMonths: type.defaultMonths,
      );

  factory MaintenanceItem.ofCustom(CustomMaintenanceItem item) =>
      MaintenanceItem(
        key: item.id,
        // Same text on both sides: the owner wrote it, and the app does not
        // pretend to have translated it.
        title: L(item.title, item.title),
        shortTitle: L(item.title, item.title),
        custom: item,
        defaultKm: item.intervalKm,
        defaultMonths: item.intervalMonths,
      );

  @override
  bool operator ==(Object other) =>
      other is MaintenanceItem &&
      other.key == key &&
      other.title == title &&
      other.shortTitle == shortTitle &&
      other.type == type &&
      other.custom == custom &&
      other.defaultKm == defaultKm &&
      other.defaultMonths == defaultMonths;

  @override
  int get hashCode =>
      Object.hash(key, title, shortTitle, type, custom, defaultKm, defaultMonths);
}

/// How often one maintenance item comes due (spec §5, `MaintenanceRule`).
///
/// Both intervals are optional and both can be set: an item with a distance
/// *and* a time interval is due at whichever arrives first, which is how a
/// workshop actually quotes a schedule.
class MaintenanceRule {
  const MaintenanceRule({
    required this.itemKey,
    this.intervalKm,
    this.intervalMonths,
  });

  final String itemKey;
  final int? intervalKm;
  final int? intervalMonths;

  bool get hasSchedule => intervalKm != null || intervalMonths != null;

  /// The rule in force for [item] on this car: the owner's own intervals where
  /// they set one, the item's defaults otherwise.
  factory MaintenanceRule.resolve(MaintenanceItem item, MaintenanceBook book) =>
      MaintenanceRule(
        itemKey: item.key,
        intervalKm: book.kmIntervals[item.key] ?? item.defaultKm,
        intervalMonths: book.monthIntervals[item.key] ?? item.defaultMonths,
      );
}

/// A completed service on one car, either logged by the user or written when
/// a booking they placed was completed and released.
class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.title,
    required this.workshop,
    required this.odometerKm,
    required this.date,
    this.itemKey,
    this.notes,
    this.bookingId,
  });

  final String id;
  final L title;
  final String workshop;
  final int odometerKm;
  final DateTime date;

  /// The schedule line this record resets — a [MaintenanceType.key] or a
  /// [CustomMaintenanceItem.id]. Null for a one-off job that resets nothing.
  final String? itemKey;

  /// Whatever the owner wanted to remember about the job. Their words, shown
  /// verbatim and never translated.
  final String? notes;

  /// The booking this record came from, when it came from one. It is what
  /// makes the write idempotent: a lifecycle event that fires twice must not
  /// produce two identical services in the history.
  final String? bookingId;

  /// The built-in item this record resets, or null when it resets a custom
  /// item (or nothing).
  MaintenanceType? get type {
    for (final value in MaintenanceType.values) {
      if (value.key == itemKey) return value;
    }
    return null;
  }

  /// True when the user typed this in themselves rather than it arriving from
  /// a completed booking.
  bool get isManual => bookingId == null;

  factory ServiceRecord.fromJson(JsonMap json) => ServiceRecord(
        id: json.requireString('id'),
        title: L.fromJson(json['title']),
        workshop: json.stringOr('workshop', ''),
        odometerKm: json.intOr('odometerKm', 0),
        date: json.dateTimeOr('date', DateTime.now()),
        // `type` is the pre-per-car wire name for the same field; accepted so
        // a book stored by an older build still decodes.
        itemKey: json.stringOrNull('itemKey') ?? json.stringOrNull('type'),
        notes: json.stringOrNull('notes'),
        bookingId: json.stringOrNull('bookingId'),
      );

  JsonMap toJson() => {
        'id': id,
        'title': title.toJson(),
        'workshop': workshop,
        'odometerKm': odometerKm,
        'date': date.toIso8601String(),
        'itemKey': itemKey,
        'notes': notes,
        'bookingId': bookingId,
      };

  ServiceRecord copyWith({
    String? id,
    L? title,
    String? workshop,
    int? odometerKm,
    DateTime? date,
    String? itemKey,
    String? notes,
    String? bookingId,
  }) =>
      ServiceRecord(
        id: id ?? this.id,
        title: title ?? this.title,
        workshop: workshop ?? this.workshop,
        odometerKm: odometerKm ?? this.odometerKm,
        date: date ?? this.date,
        itemKey: itemKey ?? this.itemKey,
        notes: notes ?? this.notes,
        bookingId: bookingId ?? this.bookingId,
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceRecord &&
      other.id == id &&
      other.title == title &&
      other.workshop == workshop &&
      other.odometerKm == odometerKm &&
      other.date == date &&
      other.itemKey == itemKey &&
      other.notes == notes &&
      other.bookingId == bookingId;

  @override
  int get hashCode => Object.hash(
      id, title, workshop, odometerKm, date, itemKey, notes, bookingId);
}

enum DueStatus { due, near, good, noRecord }

/// A computed upcoming-maintenance line. [progress] is how much of the
/// interval is consumed (0..1) — null when there is no record, or no schedule
/// to measure one against.
class DueItem {
  const DueItem({
    required this.item,
    required this.status,
    this.progress,
    this.remainingKm,
    this.remainingMonths,
    this.lastRecord,
    this.powertrain,
    this.estimated = false,
  });

  final MaintenanceItem item;
  final DueStatus status;
  final double? progress;
  final int? remainingKm;
  final int? remainingMonths;
  final ServiceRecord? lastRecord;

  /// True when [remainingKm] was computed from a *projected* odometer rather
  /// than a reading the user entered today. The screen must say so — the
  /// projection assumes a constant usage rate, which is a guess.
  final bool estimated;

  /// The powertrain this line was computed for. Carried so the widget can
  /// print the right wording without having to re-read the garage.
  final Powertrain? powertrain;

  String get key => item.key;

  /// The built-in item this line tracks, or null when it is a custom one.
  MaintenanceType? get type => item.type;

  bool get isCustom => item.isCustom;

  L get title => item.title;
  L get shortTitle => item.shortTitle;

  /// True when the owner has never logged this item — the honest first-run
  /// state the screen renders as "no record yet / add last service".
  bool get needsSetup => lastRecord == null;

  DueItem copyWith({
    MaintenanceItem? item,
    DueStatus? status,
    double? progress,
    int? remainingKm,
    int? remainingMonths,
    ServiceRecord? lastRecord,
    Powertrain? powertrain,
    bool? estimated,
  }) =>
      DueItem(
        item: item ?? this.item,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        remainingKm: remainingKm ?? this.remainingKm,
        remainingMonths: remainingMonths ?? this.remainingMonths,
        lastRecord: lastRecord ?? this.lastRecord,
        powertrain: powertrain ?? this.powertrain,
        estimated: estimated ?? this.estimated,
      );

  @override
  bool operator ==(Object other) =>
      other is DueItem &&
      other.item == item &&
      other.status == status &&
      other.progress == progress &&
      other.remainingKm == remainingKm &&
      other.remainingMonths == remainingMonths &&
      other.lastRecord == lastRecord &&
      other.powertrain == powertrain &&
      other.estimated == estimated;

  @override
  int get hashCode => Object.hash(
        item,
        status,
        progress,
        remainingKm,
        remainingMonths,
        lastRecord,
        powertrain,
        estimated,
      );
}

extension DueItemListX on List<DueItem> {
  /// Most-urgent-first. An item with no record cannot be ranked, so it always
  /// loses to one that can — which is also why the home card shows the two
  /// items *this* car is closest to needing rather than two fixed types (it
  /// used to reach for engine oil by name, which an electric car does not
  /// have).
  List<DueItem> get byUrgency {
    final ranked = [...this];
    ranked.sort((a, b) {
      final ap = a.progress;
      final bp = b.progress;
      if (ap == null && bp == null) return 0;
      if (ap == null) return 1;
      if (bp == null) return -1;
      return bp.compareTo(ap);
    });
    return ranked;
  }

  DueItem? get mostUrgent => isEmpty ? null : byUrgency.first;

  DueItem? byKey(String key) {
    for (final d in this) {
      if (d.key == key) return d;
    }
    return null;
  }
}

/// One car's maintenance book: its odometer, its logged services, the extra
/// items its owner tracks, and the intervals each item is measured against.
///
/// One book per registered car, keyed by [carId]. Nothing here is shared
/// between cars — a service logged on the Patrol must never move the Camry's
/// oil countdown.
class MaintenanceBook {
  const MaintenanceBook({
    required this.carId,
    this.currentOdometerKm,
    this.odometerUpdatedAt,
    this.previousOdometerKm,
    this.previousOdometerAt,
    this.records = const [],
    this.customItems = const [],
    this.kmIntervals = const {},
    this.monthIntervals = const {},
  });

  /// The car this book belongs to.
  final String carId;

  /// User-entered odometer. Null until the user enters it the first time.
  final int? currentOdometerKm;
  final DateTime? odometerUpdatedAt;

  /// The reading before [currentOdometerKm], kept so the app can work out how
  /// fast this car is being driven (spec §4). Two readings are the minimum
  /// for a rate; with only one, there is no rate and nothing is projected.
  final int? previousOdometerKm;
  final DateTime? previousOdometerAt;

  final List<ServiceRecord> records;

  /// Extra lines this owner added for this car. They belong to this book
  /// alone — another car in the same garage does not inherit them.
  final List<CustomMaintenanceItem> customItems;

  /// Interval overrides, keyed by [MaintenanceItem.key].
  final Map<String, int> kmIntervals;
  final Map<String, int> monthIntervals;

  /// Fallbacks used when an item has no explicit interval configured.
  static const defaultKmInterval = 5000;
  static const defaultMonthInterval = 6;

  /// A brand-new book: the right schedule for the car, and nothing claimed
  /// about its past.
  static MaintenanceBook empty(String carId) => MaintenanceBook(carId: carId);

  /// True while the owner has told the app nothing about this car's history —
  /// the state the screen must show setup copy for rather than a countdown.
  bool get isFresh => records.isEmpty;

  /// The full schedule for a car with this [powertrain]: the built-in items it
  /// has, then the owner's own.
  List<MaintenanceItem> itemsFor(Powertrain? powertrain) => [
        for (final type in MaintenanceTypeX.forPowertrain(powertrain))
          MaintenanceItem.builtIn(type, powertrain),
        for (final custom in customItems) MaintenanceItem.ofCustom(custom),
      ];

  CustomMaintenanceItem? customItemById(String id) {
    for (final item in customItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Average kilometres per day between the last two readings, or null when
  /// there is only one reading (or the two share a day).
  ///
  /// Deliberately null rather than a guessed national average: the whole
  /// point of the maintenance feature is that it never invents a number about
  /// the car. No rate means no projection, which the UI then says out loud.
  double? get avgKmPerDay {
    final current = currentOdometerKm;
    final currentAt = odometerUpdatedAt;
    final previous = previousOdometerKm;
    final previousAt = previousOdometerAt;
    if (current == null ||
        currentAt == null ||
        previous == null ||
        previousAt == null) {
      return null;
    }
    final days = currentAt.difference(previousAt).inDays;
    if (days <= 0) return null;
    final driven = current - previous;
    if (driven <= 0) return null;
    return driven / days;
  }

  /// The odometer as it probably reads *today*, projected linearly from
  /// [avgKmPerDay]. Falls back to the last entered reading when no rate can be
  /// computed, so a caller never has to special-case "no projection".
  int? projectedOdometerKm({DateTime? now}) {
    final current = currentOdometerKm;
    final at = odometerUpdatedAt;
    final rate = avgKmPerDay;
    if (current == null) return null;
    if (rate == null || at == null) return current;
    final days = (now ?? DateTime.now()).difference(at).inDays;
    if (days <= 0) return current;
    return current + (rate * days).round();
  }

  /// Whether [projectedOdometerKm] is an estimate rather than a reading the
  /// user actually entered. The UI must label these — an assumed constant
  /// usage rate is a guess, however reasonable.
  bool isProjected({DateTime? now}) {
    final at = odometerUpdatedAt;
    if (avgKmPerDay == null || at == null) return false;
    return (now ?? DateTime.now()).difference(at).inDays > 0;
  }

  ServiceRecord? lastRecordOf(String itemKey) {
    ServiceRecord? last;
    for (final r in records) {
      if (r.itemKey != itemKey) continue;
      if (last == null || r.date.isAfter(last.date)) last = r;
    }
    return last;
  }

  List<ServiceRecord> recordsOf(String itemKey) => [
        for (final r in records)
          if (r.itemKey == itemKey) r,
      ];

  /// Whether this booking already wrote its record. The guard that keeps a
  /// lifecycle event firing twice from doubling the history.
  bool hasRecordForBooking(String bookingId) {
    for (final r in records) {
      if (r.bookingId == bookingId) return true;
    }
    return false;
  }

  /// Newest first — the order the history list renders in.
  List<ServiceRecord> get recordsNewestFirst {
    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  factory MaintenanceBook.fromJson(JsonMap json) => MaintenanceBook(
        carId: json.requireString('carId'),
        currentOdometerKm: json.intOrNull('currentOdometerKm'),
        odometerUpdatedAt: json.dateTimeOrNull('odometerUpdatedAt'),
        previousOdometerKm: json.intOrNull('previousOdometerKm'),
        previousOdometerAt: json.dateTimeOrNull('previousOdometerAt'),
        records: json.objectList('records').map(ServiceRecord.fromJson).toList(),
        customItems: json
            .objectList('customItems')
            .map(CustomMaintenanceItem.fromJson)
            .toList(),
        kmIntervals: _intervals(json.objectOrNull('kmIntervals')),
        monthIntervals: _intervals(json.objectOrNull('monthIntervals')),
      );

  static Map<String, int> _intervals(JsonMap? json) {
    if (json == null) return const {};
    final result = <String, int>{};
    for (final entry in json.entries) {
      final value = entry.value;
      final parsed =
          value is int ? value : int.tryParse(value.toString());
      if (parsed != null) result[entry.key] = parsed;
    }
    return result;
  }

  JsonMap toJson() => {
        'carId': carId,
        'currentOdometerKm': currentOdometerKm,
        'odometerUpdatedAt': odometerUpdatedAt?.toIso8601String(),
        'previousOdometerKm': previousOdometerKm,
        'previousOdometerAt': previousOdometerAt?.toIso8601String(),
        'records': [for (final r in records) r.toJson()],
        'customItems': [for (final c in customItems) c.toJson()],
        'kmIntervals': {...kmIntervals},
        'monthIntervals': {...monthIntervals},
      };

  MaintenanceBook copyWith({
    String? carId,
    int? currentOdometerKm,
    DateTime? odometerUpdatedAt,
    int? previousOdometerKm,
    DateTime? previousOdometerAt,
    List<ServiceRecord>? records,
    List<CustomMaintenanceItem>? customItems,
    Map<String, int>? kmIntervals,
    Map<String, int>? monthIntervals,
  }) =>
      MaintenanceBook(
        carId: carId ?? this.carId,
        currentOdometerKm: currentOdometerKm ?? this.currentOdometerKm,
        odometerUpdatedAt: odometerUpdatedAt ?? this.odometerUpdatedAt,
        previousOdometerKm: previousOdometerKm ?? this.previousOdometerKm,
        previousOdometerAt: previousOdometerAt ?? this.previousOdometerAt,
        records: records ?? this.records,
        customItems: customItems ?? this.customItems,
        kmIntervals: kmIntervals ?? this.kmIntervals,
        monthIntervals: monthIntervals ?? this.monthIntervals,
      );

  @override
  bool operator ==(Object other) =>
      other is MaintenanceBook &&
      other.carId == carId &&
      other.currentOdometerKm == currentOdometerKm &&
      other.odometerUpdatedAt == odometerUpdatedAt &&
      other.previousOdometerKm == previousOdometerKm &&
      other.previousOdometerAt == previousOdometerAt &&
      _sameList(other.records, records) &&
      _sameList(other.customItems, customItems) &&
      _sameMap(other.kmIntervals, kmIntervals) &&
      _sameMap(other.monthIntervals, monthIntervals);

  @override
  int get hashCode => Object.hash(
        carId,
        currentOdometerKm,
        odometerUpdatedAt,
        previousOdometerKm,
        previousOdometerAt,
        Object.hashAll(records),
        Object.hashAll(customItems),
        Object.hashAllUnordered(kmIntervals.entries.map((e) => e.key)),
        Object.hashAllUnordered(monthIntervals.entries.map((e) => e.key)),
      );

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameMap(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
