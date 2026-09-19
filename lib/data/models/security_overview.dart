import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'security_alert.dart';

/// The security dashboard's front page, as `GET /security/overview` states it.
class SecurityOverview {
  const SecurityOverview({
    required this.hours,
    required this.generatedAt,
    required this.threatScore,
    required this.threatLevel,
    required this.openAlerts,
    required this.criticalOpen,
    required this.highOpen,
    required this.alertsInWindow,
    required this.eventsInWindow,
    required this.uniqueAttackers,
    required this.countries,
    required this.bySeverity,
    required this.byType,
    required this.timeline,
    required this.topAttackers,
    required this.topCountries,
    required this.topTargets,
    required this.recent,
  });

  final int hours;
  final DateTime generatedAt;

  /// 0–100.
  final int threatScore;
  final ThreatLevel threatLevel;
  final int openAlerts;
  final int criticalOpen;
  final int highOpen;
  final int alertsInWindow;
  final int eventsInWindow;
  final int uniqueAttackers;
  final int countries;
  final Map<SecuritySeverity, int> bySeverity;
  final List<ThreatTypeCount> byType;
  final List<TimelineBucket> timeline;
  final List<Attacker> topAttackers;
  final List<CountryCount> topCountries;
  final List<TargetCount> topTargets;
  final List<SecurityAlertSummary> recent;

  factory SecurityOverview.fromJson(JsonMap json) => SecurityOverview(
    hours: json.intOr('hours', 24),
    generatedAt: json.dateTimeOr('generatedAt', DateTime.now()).toLocal(),
    threatScore: json.intOr('threatScore', 0).clamp(0, 100),
    threatLevel: ThreatLevel.fromKey(json.stringOrNull('threatLevel')),
    openAlerts: json.intOr('openAlerts', 0),
    criticalOpen: json.intOr('criticalOpen', 0),
    highOpen: json.intOr('highOpen', 0),
    alertsInWindow: json.intOr('alertsInWindow', 0),
    eventsInWindow: json.intOr('eventsInWindow', 0),
    uniqueAttackers: json.intOr('uniqueAttackers', 0),
    countries: json.intOr('countries', 0),
    bySeverity: {
      for (final row in json.objectList('bySeverity'))
        SecuritySeverity.fromKey(row.stringOrNull('severity')): row.intOr('count', 0),
    },
    byType: json.objectList('byType').map(ThreatTypeCount.fromJson).toList(),
    timeline: json.objectList('timeline').map(TimelineBucket.fromJson).toList(),
    topAttackers: json.objectList('topAttackers').map(Attacker.fromJson).toList(),
    topCountries: json.objectList('topCountries').map(CountryCount.fromJson).toList(),
    topTargets: json.objectList('topTargets').map(TargetCount.fromJson).toList(),
    recent: json.objectList('recent').map(SecurityAlertSummary.fromJson).toList(),
  );
}

class ThreatTypeCount {
  const ThreatTypeCount({
    required this.type,
    required this.title,
    required this.alerts,
    required this.events,
  });

  final String type;
  final L title;
  final int alerts;
  final int events;

  factory ThreatTypeCount.fromJson(JsonMap json) => ThreatTypeCount(
    type: json.stringOr('type', ''),
    title: L(json.stringOr('titleAr', ''), json.stringOr('titleEn', '')),
    alerts: json.intOr('alerts', 0),
    events: json.intOr('events', 0),
  );
}

class TimelineBucket {
  const TimelineBucket({
    required this.start,
    required this.events,
    required this.critical,
    required this.high,
  });

  final DateTime start;
  final int events;
  final int critical;
  final int high;

  /// Events that were neither critical nor high.
  int get other => (events - critical - high).clamp(0, events);

  factory TimelineBucket.fromJson(JsonMap json) => TimelineBucket(
    start: json.dateTimeOr('start', DateTime.now()).toLocal(),
    events: json.intOr('events', 0),
    critical: json.intOr('critical', 0),
    high: json.intOr('high', 0),
  );
}

class Attacker {
  const Attacker({
    required this.ip,
    required this.countryCode,
    required this.country,
    required this.city,
    required this.isp,
    required this.alerts,
    required this.events,
    required this.worstSeverity,
    required this.lastSeenAt,
  });

  final String ip;
  final String? countryCode;
  final String? country;
  final String? city;
  final String? isp;
  final int alerts;
  final int events;
  final SecuritySeverity worstSeverity;
  final DateTime lastSeenAt;

  factory Attacker.fromJson(JsonMap json) => Attacker(
    ip: json.stringOr('ip', ''),
    countryCode: json.stringOrNull('countryCode'),
    country: json.stringOrNull('country'),
    city: json.stringOrNull('city'),
    isp: json.stringOrNull('isp'),
    alerts: json.intOr('alerts', 0),
    events: json.intOr('events', 0),
    worstSeverity: SecuritySeverity.fromKey(json.stringOrNull('worstSeverity')),
    lastSeenAt: json.dateTimeOr('lastSeenAt', DateTime.now()).toLocal(),
  );
}

class CountryCount {
  const CountryCount({
    required this.countryCode,
    required this.country,
    required this.alerts,
    required this.events,
  });

  final String? countryCode;
  final String? country;
  final int alerts;
  final int events;

  factory CountryCount.fromJson(JsonMap json) => CountryCount(
    countryCode: json.stringOrNull('countryCode'),
    country: json.stringOrNull('country'),
    alerts: json.intOr('alerts', 0),
    events: json.intOr('events', 0),
  );
}

class TargetCount {
  const TargetCount({
    required this.method,
    required this.path,
    required this.events,
  });

  final String method;
  final String path;
  final int events;

  factory TargetCount.fromJson(JsonMap json) => TargetCount(
    method: json.stringOr('method', ''),
    path: json.stringOr('path', ''),
    events: json.intOr('events', 0),
  );
}
