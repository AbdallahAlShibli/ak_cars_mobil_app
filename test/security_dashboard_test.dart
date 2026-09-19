import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/models/security_alert.dart';
import 'package:ak_cars_mobil_app/data/models/security_alert_detail.dart';
import 'package:ak_cars_mobil_app/data/models/security_overview.dart';
import 'package:ak_cars_mobil_app/data/services/security_service.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/operations/security/admin_security_tab.dart';
import 'package:ak_cars_mobil_app/features/operations/security/security_alert_detail_screen.dart';
import 'package:ak_cars_mobil_app/features/operations/security/security_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

// Shapes copied from what the API's SecurityDtos serialise to (camelCase).
Map<String, dynamic> _summaryJson({String status = 'open'}) => {
  'id': 'a1',
  'type': 'sqlInjection',
  'titleEn': 'SQL injection attempt',
  'titleAr': 'محاولة حقن SQL',
  'severity': 'high',
  'status': status,
  'sourceIp': '203.0.113.7',
  'countryCode': 'DE',
  'country': 'Germany',
  'city': 'Frankfurt am Main',
  'firstSeenAt': '2026-09-19T08:00:00Z',
  'lastSeenAt': '2026-09-19T09:30:00Z',
  'eventCount': 42,
  'targetMethod': 'GET',
  'targetPath': '/api/v1/cars',
  'deviceType': 'script',
  'client': 'sqlmap 1.7.2',
  'isAutomatedClient': true,
  'summary':
      'SQL injection attempt on GET /api/v1/cars from 203.0.113.7 (Frankfurt am Main, Germany)',
};

Map<String, dynamic> _overviewJson({bool quiet = false}) {
  int n(int value) => quiet ? 0 : value;
  return {
    'hours': 24,
    'generatedAt': '2026-09-19T10:00:00Z',
    'threatScore': n(57),
    'threatLevel': quiet ? 'calm' : 'severe',
    'openAlerts': n(3),
    'criticalOpen': n(1),
    'highOpen': n(1),
    'alertsInWindow': n(3),
    'eventsInWindow': n(58),
    'uniqueAttackers': n(2),
    'countries': n(2),
    'bySeverity': [
      {'severity': 'critical', 'count': n(1)},
      {'severity': 'high', 'count': n(1)},
      {'severity': 'medium', 'count': n(1)},
      {'severity': 'low', 'count': 0},
    ],
    'byType': quiet
        ? []
        : [
            {'type': 'sqlInjection', 'titleEn': 'SQL injection attempt', 'titleAr': 'محاولة حقن SQL', 'alerts': 1, 'events': 42},
            {'type': 'commandInjection', 'titleEn': 'Command injection attempt', 'titleAr': 'محاولة حقن أوامر النظام', 'alerts': 1, 'events': 6},
            {'type': 'vulnerabilityScan', 'titleEn': 'Vulnerability scan', 'titleAr': 'فحص ثغرات', 'alerts': 1, 'events': 10},
          ],
    'timeline': [
      for (var h = 0; h < 24; h++)
        {
          'start': DateTime.utc(2026, 9, 18, 10).add(Duration(hours: h)).toIso8601String(),
          'events': n(h % 5),
          'critical': n(h % 7 == 0 && h % 5 > 0 ? 1 : 0),
          'high': n(h % 5 > 1 ? 1 : 0),
        },
    ],
    'topAttackers': quiet
        ? []
        : [
            {'ip': '203.0.113.7', 'countryCode': 'DE', 'country': 'Germany', 'city': 'Frankfurt am Main', 'isp': 'Example Hosting GmbH', 'alerts': 2, 'events': 52, 'worstSeverity': 'critical', 'lastSeenAt': '2026-09-19T09:30:00Z'},
            {'ip': '198.51.100.9', 'countryCode': 'US', 'country': 'United States', 'city': null, 'isp': null, 'alerts': 1, 'events': 6, 'worstSeverity': 'medium', 'lastSeenAt': '2026-09-19T07:00:00Z'},
          ],
    'topCountries': quiet
        ? []
        : [
            {'countryCode': 'DE', 'country': 'Germany', 'alerts': 2, 'events': 52},
            {'countryCode': 'US', 'country': 'United States', 'alerts': 1, 'events': 6},
          ],
    'topTargets': quiet
        ? []
        : [
            {'method': 'GET', 'path': '/api/v1/cars', 'events': 42},
            {'method': 'GET', 'path': '/.env', 'events': 10},
          ],
    'recent': quiet ? [] : [_summaryJson()],
  };
}

Map<String, dynamic> _detailJson({String status = 'open'}) => {
  'alert': _summaryJson(status: status),
  'explanationEn': 'The request carried database commands hidden in a parameter.',
  'explanationAr': 'حمل الطلب أوامر قاعدة بيانات مخفية داخل أحد المدخلات.',
  'adviceEn': 'Block the address at Cloudflare if it continues.',
  'adviceAr': 'احظر العنوان في Cloudflare إن استمرت.',
  'location': {
    'ip': '203.0.113.7',
    'countryCode': 'DE',
    'country': 'Germany',
    'region': 'Hesse',
    'city': 'Frankfurt am Main',
    'latitude': 50.11,
    'longitude': 8.68,
    'isp': 'Example Hosting GmbH',
    'asn': 'AS64500',
    'timeZone': 'Europe/Berlin',
  },
  'device': {
    'deviceType': 'script',
    'operatingSystem': null,
    'client': 'sqlmap 1.7.2',
    'isAutomatedClient': true,
    'userAgent': 'sqlmap/1.7.2#stable (https://sqlmap.org)',
  },
  'account': null,
  'statusChangedAt': null,
  'note': null,
  'targets': [
    {'method': 'GET', 'path': '/api/v1/cars', 'events': 42},
  ],
  'rules': [
    {'rule': 'sql-tautology', 'count': 40},
    {'rule': 'sql-union-select', 'count': 2},
  ],
  'responses': [
    {'statusCode': 200, 'count': 42},
  ],
  'events': [
    {
      'id': 'e1',
      'at': '2026-09-19T09:30:00Z',
      'type': 'sqlInjection',
      'rule': 'sql-tautology',
      'evidence': "/api/v1/cars?q=' OR '1'='1",
      'method': 'GET',
      'path': '/api/v1/cars',
      'queryString': "?q=' OR '1'='1",
      'statusCode': 200,
      'durationMs': 14,
      'userAgent': 'sqlmap/1.7.2',
      'referer': null,
      'headers': {'Host': 'api.akcars.om', 'CF-Ray': '8abc'},
      'traceId': 'trace-1',
    },
  ],
  'eventsStored': 42,
  'relatedAlerts': [
    {'id': 'a2', 'type': 'scannerTool', 'titleEn': 'Attack tool detected', 'titleAr': 'رُصدت أداة هجوم', 'severity': 'high', 'status': 'open', 'eventCount': 42, 'lastSeenAt': '2026-09-19T09:30:00Z'},
  ],
};

class _FakeSecurityService implements SecurityService {
  _FakeSecurityService({this.quiet = false});

  final bool quiet;
  final statusCalls = <(String, SecurityAlertStatus, String?)>[];

  @override
  Future<SecurityOverview> overview({int hours = 24}) async =>
      SecurityOverview.fromJson(_overviewJson(quiet: quiet));

  @override
  Future<SecurityAlertPage> alerts({
    String? status,
    SecuritySeverity? severity,
    String? type,
    String? ip,
    int page = 1,
    int pageSize = 30,
  }) async => SecurityAlertPage.fromJson({
    'items': [_summaryJson()],
    'total': 1,
    'page': 1,
    'pageSize': pageSize,
  });

  @override
  Future<SecurityAlertDetail> alert(String alertId) async =>
      SecurityAlertDetail.fromJson(
        _detailJson(status: statusCalls.isEmpty ? 'open' : statusCalls.last.$2.name),
      );

  @override
  Future<SecurityAlertSummary> setStatus(
    String alertId,
    SecurityAlertStatus status, {
    String? note,
  }) async {
    statusCalls.add((alertId, status, note));
    return SecurityAlertSummary.fromJson(_summaryJson(status: status.name));
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeSecurityService service,
  Widget home, {
  String locale = 'en',
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(402 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = await createTestContainer(
    overrides: [securityServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: Locale(locale),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
  // The gauge animates for 900 ms; the map and live dot loop forever, so
  // pumpAndSettle would never return.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

/// The screen's own vertical list — the filter chips scroll too, sideways.
final _page = find.byType(Scrollable).first;

void main() {
  group('security models', () {
    test('an overview parses every section the dashboard draws', () {
      final o = SecurityOverview.fromJson(_overviewJson());

      expect(o.threatScore, 57);
      expect(o.threatLevel, ThreatLevel.severe);
      expect(o.bySeverity[SecuritySeverity.critical], 1);
      expect(o.timeline, hasLength(24));
      expect(o.timeline.first.start.isUtc, isFalse);
      expect(o.topAttackers.first.worstSeverity, SecuritySeverity.critical);
      expect(o.topTargets.first.path, '/api/v1/cars');
      expect(o.recent.single.title.en, 'SQL injection attempt');
    });

    test('an alert detail carries location, device and evidence', () {
      final d = SecurityAlertDetail.fromJson(_detailJson());

      expect(d.location.hasCoordinates, isTrue);
      expect(d.location.asn, 'AS64500');
      expect(d.device.isAutomatedClient, isTrue);
      expect(d.rules['sql-tautology'], 40);
      expect(d.responses[200], 42);
      expect(d.events.single.headers['CF-Ray'], '8abc');
      expect(d.related.single.type, 'scannerTool');
    });

    test('unknown enum keys fall back instead of throwing', () {
      expect(SecuritySeverity.fromKey('apocalyptic'), SecuritySeverity.low);
      expect(
        SecurityAlertStatus.fromKey('falsePositive'),
        SecurityAlertStatus.falsePositive,
      );
      expect(ThreatLevel.fromKey(null), ThreatLevel.calm);
    });

    test('flags come from the country code, a globe when there is none', () {
      expect(flagEmoji('OM'), '🇴🇲');
      expect(flagEmoji('de'), '🇩🇪');
      expect(flagEmoji(null), '🌐');
      expect(flagEmoji('T1x'), '🌐');
    });
  });

  group('security tab', () {
    for (final locale in ['en', 'ar']) {
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        testWidgets('renders the whole dashboard ($locale, $theme)', (
          tester,
        ) async {
          await _pump(
            tester,
            _FakeSecurityService(),
            const Scaffold(body: AdminSecurityTab()),
            locale: locale,
            dark: dark,
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(ThreatGauge), findsOneWidget);
          expect(find.text('57'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('Example Hosting GmbH'),
            300,
            scrollable: _page,
          );
          expect(find.text('203.0.113.7'), findsWidgets);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('an empty window says so instead of drawing empty charts', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeSecurityService(quiet: true),
        const Scaffold(body: AdminSecurityTab()),
      );

      expect(find.text('All quiet'), findsOneWidget);
      expect(find.text('Top attackers'), findsNothing);
    });
  });

  group('alert detail', () {
    for (final locale in ['en', 'ar']) {
      testWidgets('shows who, where, with what and at what ($locale)', (
        tester,
      ) async {
        await _pump(
          tester,
          _FakeSecurityService(),
          const SecurityAlertDetailScreen(alertId: 'a1'),
          locale: locale,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(AttackPathMap), findsOneWidget);
        expect(find.text('203.0.113.7'), findsWidgets);
        expect(find.textContaining('Frankfurt am Main'), findsWidgets);
        expect(find.text('Example Hosting GmbH'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('sqlmap 1.7.2'),
          300,
          scrollable: _page,
        );
        expect(find.text('sqlmap 1.7.2'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('sql-tautology × 40'),
          300,
          scrollable: _page,
        );
        final evidence = find.text("/api/v1/cars?q=' OR '1'='1");
        await tester.scrollUntilVisible(evidence, 300, scrollable: _page);
        expect(evidence, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('resolving asks for a note and sends it', (tester) async {
      final service = _FakeSecurityService();
      await _pump(
        tester,
        service,
        const SecurityAlertDetailScreen(alertId: 'a1'),
      );

      await tester.tap(find.text('Resolve'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), 'Blocked at Cloudflare');
      await tester.tap(find.text('Confirm'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      expect(service.statusCalls, [
        ('a1', SecurityAlertStatus.resolved, 'Blocked at Cloudflare'),
      ]);
      // Re-read after the change: a resolved alert offers to reopen instead.
      expect(find.text('Reopen'), findsOneWidget);
    });

    testWidgets('backing out of the note dialog changes nothing', (
      tester,
    ) async {
      final service = _FakeSecurityService();
      await _pump(
        tester,
        service,
        const SecurityAlertDetailScreen(alertId: 'a1'),
      );

      await tester.tap(find.text('False alarm'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(service.statusCalls, isEmpty);
    });
  });
}
