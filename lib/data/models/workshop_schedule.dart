import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'service_request.dart';

/// A workshop's own working-hours configuration: display text plus the
/// structured template a day's slots are generated from.
class WorkshopSchedule {
  const WorkshopSchedule({
    this.hours,
    this.slotTemplate = const [],
    this.capacityPerSlot = 1,
    this.closedDays = const [],
  });

  final L? hours;

  /// Empty means "use the platform's fixed default generator" — the same
  /// simplification `GetAvailabilityQuery` already uses server-side.
  final List<String> slotTemplate;
  final int capacityPerSlot;

  /// English `DateTime.weekday` names ("Friday", …) the workshop does not
  /// take bookings on.
  final List<String> closedDays;

  factory WorkshopSchedule.fromJson(JsonMap json) => WorkshopSchedule(
    hours: json['hours'] == null ? null : L.fromJson(json['hours']),
    slotTemplate: json.stringList('slotTemplate'),
    capacityPerSlot: json.intOr('capacityPerSlot', 1),
    closedDays: json.stringList('closedDays'),
  );

  JsonMap toJson() => {
    'hours': hours?.toJson(),
    'slotTemplate': slotTemplate,
    'capacityPerSlot': capacityPerSlot,
    'closedDays': closedDays,
  };

  WorkshopSchedule copyWith({
    L? hours,
    List<String>? slotTemplate,
    int? capacityPerSlot,
    List<String>? closedDays,
  }) => WorkshopSchedule(
    hours: hours ?? this.hours,
    slotTemplate: slotTemplate ?? this.slotTemplate,
    capacityPerSlot: capacityPerSlot ?? this.capacityPerSlot,
    closedDays: closedDays ?? this.closedDays,
  );
}

/// One day's worth of slots, bookings and assigned jobs — what the dashboard
/// home's "today's schedule" widget and the schedule screen render.
class WorkshopDaySchedule {
  const WorkshopDaySchedule({
    required this.date,
    this.slots = const [],
    this.bookedSlots = const [],
    this.assignedJobs = const [],
  });

  final DateTime date;
  final List<String> slots;
  final List<String> bookedSlots;
  final List<ServiceRequest> assignedJobs;

  bool isAvailable(String slot) => !bookedSlots.contains(slot);

  factory WorkshopDaySchedule.fromJson(JsonMap json) => WorkshopDaySchedule(
    date: json.dateTimeOr('date', DateTime.now()),
    slots: json.stringList('slots'),
    bookedSlots: json.stringList('bookedSlots'),
    assignedJobs: json
        .objectList('assignedJobs')
        .map(ServiceRequest.fromJson)
        .toList(),
  );

  JsonMap toJson() => {
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'slots': slots,
    'bookedSlots': bookedSlots,
    'assignedJobs': [for (final j in assignedJobs) j.toJson()],
  };
}
