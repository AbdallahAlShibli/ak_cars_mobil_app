import '../models/security_alert.dart';
import '../models/security_alert_detail.dart';
import '../models/security_overview.dart';

/// The founder's view of the API's security monitor.
abstract interface class SecurityService {
  /// The dashboard's front page over the last [hours].
  Future<SecurityOverview> overview({int hours = 24});

  /// Alerts, newest activity first. [status] may be `active` (open or
  /// investigating) or one of [SecurityAlertStatus]'s names.
  Future<SecurityAlertPage> alerts({
    String? status,
    SecuritySeverity? severity,
    String? type,
    String? ip,
    int page = 1,
    int pageSize = 30,
  });

  Future<SecurityAlertDetail> alert(String alertId);

  Future<SecurityAlertSummary> setStatus(
    String alertId,
    SecurityAlertStatus status, {
    String? note,
  });
}
