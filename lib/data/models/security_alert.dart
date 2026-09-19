import '../../core/i18n/strings.dart';
import '../../core/json/json_utils.dart';

/// How bad a security alert is. Ordered: later values are worse.
enum SecuritySeverity {
  low,
  medium,
  high,
  critical;

  static SecuritySeverity fromKey(String? key) {
    for (final value in values) {
      if (value.name == key?.toLowerCase()) return value;
    }
    return SecuritySeverity.low;
  }

  String label(S s) => switch (this) {
    SecuritySeverity.low => s.t('منخفض', 'Low'),
    SecuritySeverity.medium => s.t('متوسط', 'Medium'),
    SecuritySeverity.high => s.t('مرتفع', 'High'),
    SecuritySeverity.critical => s.t('حرج', 'Critical'),
  };
}

/// Where the founder has got to with an alert.
enum SecurityAlertStatus {
  open,
  investigating,
  resolved,
  falsePositive;

  static SecurityAlertStatus fromKey(String? key) {
    for (final value in values) {
      if (value.name.toLowerCase() == key?.toLowerCase()) return value;
    }
    return SecurityAlertStatus.open;
  }

  /// Still needs the founder.
  bool get isActive =>
      this == SecurityAlertStatus.open ||
      this == SecurityAlertStatus.investigating;

  String label(S s) => switch (this) {
    SecurityAlertStatus.open => s.t('مفتوح', 'Open'),
    SecurityAlertStatus.investigating => s.t('قيد التحقيق', 'Investigating'),
    SecurityAlertStatus.resolved => s.t('تمت المعالجة', 'Resolved'),
    SecurityAlertStatus.falsePositive => s.t('إنذار كاذب', 'False positive'),
  };
}

/// The overall threat level the server derives from open alerts.
enum ThreatLevel {
  calm,
  guarded,
  elevated,
  severe,
  critical;

  static ThreatLevel fromKey(String? key) {
    for (final value in values) {
      if (value.name == key?.toLowerCase()) return value;
    }
    return ThreatLevel.calm;
  }

  String label(S s) => switch (this) {
    ThreatLevel.calm => s.t('هادئ', 'Calm'),
    ThreatLevel.guarded => s.t('حذر', 'Guarded'),
    ThreatLevel.elevated => s.t('مرتفع', 'Elevated'),
    ThreatLevel.severe => s.t('شديد', 'Severe'),
    ThreatLevel.critical => s.t('حرج', 'Critical'),
  };
}

/// One row of the alert list: enough to recognise an attack at a glance.
class SecurityAlertSummary {
  const SecurityAlertSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.severity,
    required this.status,
    required this.sourceIp,
    required this.countryCode,
    required this.country,
    required this.city,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.eventCount,
    required this.targetMethod,
    required this.targetPath,
    required this.deviceType,
    required this.client,
    required this.isAutomatedClient,
    required this.summary,
  });

  final String id;

  /// Wire key of the threat type, e.g. `sqlInjection` — also picks the icon.
  final String type;
  final L title;
  final SecuritySeverity severity;
  final SecurityAlertStatus status;
  final String sourceIp;
  final String? countryCode;
  final String? country;
  final String? city;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final int eventCount;
  final String targetMethod;
  final String targetPath;
  final String deviceType;
  final String? client;
  final bool isAutomatedClient;
  final String summary;

  String get place => [city, country ?? countryCode]
      .whereType<String>()
      .where((p) => p.isNotEmpty)
      .join(', ');

  factory SecurityAlertSummary.fromJson(JsonMap json) => SecurityAlertSummary(
    id: json.requireString('id'),
    type: json.stringOr('type', ''),
    title: L(json.stringOr('titleAr', ''), json.stringOr('titleEn', '')),
    severity: SecuritySeverity.fromKey(json.stringOrNull('severity')),
    status: SecurityAlertStatus.fromKey(json.stringOrNull('status')),
    sourceIp: json.stringOr('sourceIp', ''),
    countryCode: json.stringOrNull('countryCode'),
    country: json.stringOrNull('country'),
    city: json.stringOrNull('city'),
    firstSeenAt: json.dateTimeOr('firstSeenAt', DateTime.now()).toLocal(),
    lastSeenAt: json.dateTimeOr('lastSeenAt', DateTime.now()).toLocal(),
    eventCount: json.intOr('eventCount', 0),
    targetMethod: json.stringOr('targetMethod', ''),
    targetPath: json.stringOr('targetPath', ''),
    deviceType: json.stringOr('deviceType', 'unknown'),
    client: json.stringOrNull('client'),
    isAutomatedClient: json.boolOr('isAutomatedClient', false),
    summary: json.stringOr('summary', ''),
  );
}

class SecurityAlertPage {
  const SecurityAlertPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<SecurityAlertSummary> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  factory SecurityAlertPage.fromJson(JsonMap json) => SecurityAlertPage(
    items: json.objectList('items').map(SecurityAlertSummary.fromJson).toList(),
    total: json.intOr('total', 0),
    page: json.intOr('page', 1),
    pageSize: json.intOr('pageSize', 30),
  );
}
