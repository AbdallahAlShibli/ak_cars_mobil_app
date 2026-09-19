import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';
import 'security_alert.dart';
import 'security_overview.dart';

/// Everything the API knows about one alert (`GET /security/alerts/{id}`).
class SecurityAlertDetail {
  const SecurityAlertDetail({
    required this.alert,
    required this.explanation,
    required this.advice,
    required this.location,
    required this.device,
    required this.account,
    required this.statusChangedAt,
    required this.note,
    required this.targets,
    required this.rules,
    required this.responses,
    required this.events,
    required this.eventsStored,
    required this.related,
  });

  final SecurityAlertSummary alert;
  final L explanation;
  final L advice;
  final SecurityLocation location;
  final SecurityDevice device;
  final SecurityAccount? account;
  final DateTime? statusChangedAt;
  final String? note;
  final List<TargetCount> targets;

  /// Which detection rule fired, and how often (`sql-union-select` × 4).
  final Map<String, int> rules;

  /// HTTP status the attacker got back, and how often.
  final Map<int, int> responses;
  final List<SecurityEvent> events;

  /// Evidence rows kept on the server — at most its cap, while
  /// [SecurityAlertSummary.eventCount] keeps counting past it.
  final int eventsStored;
  final List<RelatedAlert> related;

  factory SecurityAlertDetail.fromJson(JsonMap json) {
    final account = json.objectOrNull('account');
    return SecurityAlertDetail(
      alert: SecurityAlertSummary.fromJson(json.requireObject('alert')),
      explanation: L(json.stringOr('explanationAr', ''), json.stringOr('explanationEn', '')),
      advice: L(json.stringOr('adviceAr', ''), json.stringOr('adviceEn', '')),
      location: SecurityLocation.fromJson(json.objectOrNull('location') ?? const {}),
      device: SecurityDevice.fromJson(json.objectOrNull('device') ?? const {}),
      account: account == null ? null : SecurityAccount.fromJson(account),
      statusChangedAt: json.dateTimeOrNull('statusChangedAt')?.toLocal(),
      note: json.stringOrNull('note'),
      targets: json.objectList('targets').map(TargetCount.fromJson).toList(),
      rules: {
        for (final row in json.objectList('rules'))
          row.stringOr('rule', ''): row.intOr('count', 0),
      },
      responses: {
        for (final row in json.objectList('responses'))
          row.intOr('statusCode', 0): row.intOr('count', 0),
      },
      events: json.objectList('events').map(SecurityEvent.fromJson).toList(),
      eventsStored: json.intOr('eventsStored', 0),
      related: json.objectList('relatedAlerts').map(RelatedAlert.fromJson).toList(),
    );
  }
}

class SecurityLocation {
  const SecurityLocation({
    required this.ip,
    this.countryCode,
    this.country,
    this.region,
    this.city,
    this.latitude,
    this.longitude,
    this.isp,
    this.asn,
    this.timeZone,
  });

  final String ip;
  final String? countryCode;
  final String? country;
  final String? region;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? isp;
  final String? asn;
  final String? timeZone;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory SecurityLocation.fromJson(JsonMap json) => SecurityLocation(
    ip: json.stringOr('ip', ''),
    countryCode: json.stringOrNull('countryCode'),
    country: json.stringOrNull('country'),
    region: json.stringOrNull('region'),
    city: json.stringOrNull('city'),
    latitude: json.doubleOrNull('latitude'),
    longitude: json.doubleOrNull('longitude'),
    isp: json.stringOrNull('isp'),
    asn: json.stringOrNull('asn'),
    timeZone: json.stringOrNull('timeZone'),
  );
}

class SecurityDevice {
  const SecurityDevice({
    required this.deviceType,
    this.operatingSystem,
    this.client,
    required this.isAutomatedClient,
    this.userAgent,
  });

  final String deviceType;
  final String? operatingSystem;
  final String? client;
  final bool isAutomatedClient;
  final String? userAgent;

  factory SecurityDevice.fromJson(JsonMap json) => SecurityDevice(
    deviceType: json.stringOr('deviceType', 'unknown'),
    operatingSystem: json.stringOrNull('operatingSystem'),
    client: json.stringOrNull('client'),
    isAutomatedClient: json.boolOr('isAutomatedClient', false),
    userAgent: json.stringOrNull('userAgent'),
  );
}

/// The account whose session the attacker's calls carried, if any.
class SecurityAccount {
  const SecurityAccount({
    required this.userId,
    this.name,
    this.phone,
    this.kind,
    required this.isDeleted,
  });

  final String userId;
  final String? name;
  final String? phone;
  final String? kind;
  final bool isDeleted;

  factory SecurityAccount.fromJson(JsonMap json) => SecurityAccount(
    userId: json.stringOr('userId', ''),
    name: json.stringOrNull('name'),
    phone: json.stringOrNull('phone'),
    kind: json.stringOrNull('kind'),
    isDeleted: json.boolOr('isDeleted', false),
  );
}

/// One suspicious call, kept as evidence.
class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.at,
    required this.type,
    required this.rule,
    this.evidence,
    required this.method,
    required this.path,
    this.queryString,
    required this.statusCode,
    required this.durationMs,
    this.userAgent,
    this.referer,
    required this.headers,
    this.traceId,
  });

  final String id;
  final DateTime at;
  final String type;
  final String rule;
  final String? evidence;
  final String method;
  final String path;
  final String? queryString;
  final int statusCode;
  final int durationMs;
  final String? userAgent;
  final String? referer;
  final Map<String, String> headers;
  final String? traceId;

  factory SecurityEvent.fromJson(JsonMap json) {
    final headers = json.objectOrNull('headers') ?? const {};
    return SecurityEvent(
      id: json.stringOr('id', ''),
      at: json.dateTimeOr('at', DateTime.now()).toLocal(),
      type: json.stringOr('type', ''),
      rule: json.stringOr('rule', ''),
      evidence: json.stringOrNull('evidence'),
      method: json.stringOr('method', ''),
      path: json.stringOr('path', ''),
      queryString: json.stringOrNull('queryString'),
      statusCode: json.intOr('statusCode', 0),
      durationMs: json.intOr('durationMs', 0),
      userAgent: json.stringOrNull('userAgent'),
      referer: json.stringOrNull('referer'),
      headers: {
        for (final entry in headers.entries)
          if (entry.value is String) entry.key: entry.value as String,
      },
      traceId: json.stringOrNull('traceId'),
    );
  }
}

class RelatedAlert {
  const RelatedAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.severity,
    required this.status,
    required this.eventCount,
    required this.lastSeenAt,
  });

  final String id;
  final String type;
  final L title;
  final SecuritySeverity severity;
  final SecurityAlertStatus status;
  final int eventCount;
  final DateTime lastSeenAt;

  factory RelatedAlert.fromJson(JsonMap json) => RelatedAlert(
    id: json.stringOr('id', ''),
    type: json.stringOr('type', ''),
    title: L(json.stringOr('titleAr', ''), json.stringOr('titleEn', '')),
    severity: SecuritySeverity.fromKey(json.stringOrNull('severity')),
    status: SecurityAlertStatus.fromKey(json.stringOrNull('status')),
    eventCount: json.intOr('eventCount', 0),
    lastSeenAt: json.dateTimeOr('lastSeenAt', DateTime.now()).toLocal(),
  );
}
