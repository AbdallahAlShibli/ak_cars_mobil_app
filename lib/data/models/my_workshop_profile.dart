import '../../core/json/json_utils.dart';
import 'service_provider.dart';
import 'workshop_schedule.dart';

/// The whole `GET /my-workshop` payload — the caller's own [ServiceProvider]
/// **wrapped** in a completeness report and its booking-schedule config.
///
/// This type exists because that envelope was previously ignored: the client
/// parsed the response as a bare `ServiceProvider`, which has no top-level
/// `id`, so `requireString('id')` threw on every load and the workshop
/// profile screen only ever showed "Couldn't load the profile". Modelling the
/// envelope is what makes the two fields it carries reachable instead of
/// merely tolerated:
///
///  * [missingFields] is the server's own answer to "what is this profile
///    still missing", computed by the same handler the founder's review reads
///    — so the completeness meter no longer has to re-derive it from the
///    fields the screen happens to have on hand and hope the two agree.
///  * [schedule] is the only way to *read back* the slot template, capacity
///    and closed days. They are written through `PUT /my-workshop/schedule`,
///    which has no matching GET, so before this the schedule config sheet
///    reopened blank after every save.
class MyWorkshopProfile {
  const MyWorkshopProfile({
    required this.provider,
    this.isComplete = false,
    this.missingFields = const [],
    this.schedule = const WorkshopSchedule(),
  });

  final ServiceProvider provider;

  /// True once [missingFields] is empty.
  final bool isComplete;

  /// Stable field keys (`phone`, `whatsapp`, `hours`, `vatNumber`,
  /// `fulfillments`, `crDocument`) the workshop has not filled in yet.
  final List<String> missingFields;

  final WorkshopSchedule schedule;

  /// The same envelope, rebuilt locally around a provider the server just
  /// answered a `PUT` with.
  ///
  /// `PUT /my-workshop` returns the bare updated provider, not this envelope,
  /// so the completeness report has to be re-derived to stay in step with the
  /// edit that was just saved. The six checks below are a deliberate mirror
  /// of `GetMyWorkshopQueryHandler` — the same fields, in the same order, so
  /// the next real `GET` agrees with what was shown in between. [schedule] is
  /// carried over unchanged: it is written through a different route
  /// entirely and a profile edit cannot have moved it.
  factory MyWorkshopProfile.of(
    ServiceProvider provider, {
    WorkshopSchedule schedule = const WorkshopSchedule(),
  }) {
    final missing = <String>[
      if ((provider.phone ?? '').trim().isEmpty) 'phone',
      if ((provider.whatsapp ?? '').trim().isEmpty) 'whatsapp',
      if (provider.hours == null) 'hours',
      if ((provider.vatNumber ?? '').trim().isEmpty) 'vatNumber',
      if (provider.fulfillments.isEmpty) 'fulfillments',
      if (provider.crDocument == null) 'crDocument',
    ];
    return MyWorkshopProfile(
      provider: provider,
      isComplete: missing.isEmpty,
      missingFields: missing,
      schedule: schedule,
    );
  }

  /// Tolerant of both shapes: the enveloped payload the API sends, and a bare
  /// provider object. The fallback is not speculative back-compat — a `PUT`
  /// to the same path answers with the bare provider, so one parser reading
  /// both keeps the read and the write path on a single code path.
  factory MyWorkshopProfile.fromJson(JsonMap json) {
    final provider = json.objectOrNull('provider');
    if (provider == null) {
      return MyWorkshopProfile(provider: ServiceProvider.fromJson(json));
    }
    return MyWorkshopProfile(
      provider: ServiceProvider.fromJson(provider),
      isComplete: json.boolOr('isComplete', false),
      missingFields: json.stringList('missingFields'),
      schedule: switch (json.objectOrNull('schedule')) {
        final JsonMap s => WorkshopSchedule.fromJson(s),
        _ => const WorkshopSchedule(),
      },
    );
  }

  JsonMap toJson() => {
    'provider': provider.toJson(),
    'isComplete': isComplete,
    'missingFields': missingFields,
    'schedule': schedule.toJson(),
  };
}
