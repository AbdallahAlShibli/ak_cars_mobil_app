import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../models/security_alert.dart';
import '../../models/security_alert_detail.dart';
import '../../models/security_overview.dart';
import '../security_service.dart';

/// [SecurityService] over REST — same conventions as the other API services.
class ApiSecurityService implements SecurityService {
  const ApiSecurityService(this._client);

  final ApiClient _client;

  @override
  Future<SecurityOverview> overview({int hours = 24}) async =>
      SecurityOverview.fromJson(
        await _client.get(
          ApiEndpoints.securityOverview,
          queryParameters: {'hours': hours},
        ),
      );

  @override
  Future<SecurityAlertPage> alerts({
    String? status,
    SecuritySeverity? severity,
    String? type,
    String? ip,
    int page = 1,
    int pageSize = 30,
  }) async => SecurityAlertPage.fromJson(
    await _client.get(
      ApiEndpoints.securityAlerts,
      queryParameters: {
        'status': ?status,
        'severity': ?severity?.name,
        'type': ?type,
        'ip': ?ip,
        'page': page,
        'pageSize': pageSize,
      },
    ),
  );

  @override
  Future<SecurityAlertDetail> alert(String alertId) async =>
      SecurityAlertDetail.fromJson(
        await _client.get(ApiEndpoints.securityAlert(alertId)),
      );

  @override
  Future<SecurityAlertSummary> setStatus(
    String alertId,
    SecurityAlertStatus status, {
    String? note,
  }) async => SecurityAlertSummary.fromJson(
    await _client.put(
      ApiEndpoints.securityAlertStatus(alertId),
      body: {'status': status.name, 'note': ?note},
    ),
  );
}
