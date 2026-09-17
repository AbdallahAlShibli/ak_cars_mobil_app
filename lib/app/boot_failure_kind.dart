import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/error/app_exception.dart';
import '../core/i18n/strings.dart';

/// One piece of advice on the failure screen.
typedef BootFailureTip = ({IconData icon, String text});

/// Why the app could not start, as the person holding the phone would put it —
/// which decides what the failure screen draws and what it advises.
///
/// Chosen from the exception *type*, never its message (the rule
/// [AppException] sets for all user-facing copy), so the same failure always
/// reads the same way.
///
/// The screen draws the start-up path as three hops — the phone, the internet,
/// the AK Cars server — and each kind names where along it things stopped.
enum BootFailureKind {
  /// The phone could not reach the internet or the API host at all.
  offline,

  /// The API host answered with a server error: for the tunnel in front of a
  /// stopped API, typically 502.
  serverDown,

  /// The API answered too slowly, or start-up as a whole ran out of time.
  slow,

  /// Anything else — a fault inside the app while preparing its data.
  unexpected;

  static BootFailureKind of(Object error) => switch (error) {
    NetworkException() => offline,
    RequestTimeoutException() || TimeoutException() => slow,
    ApiException(isServerError: true) => serverDown,
    _ => unexpected,
  };

  /// A short technical label for the diagram — the first thing a support
  /// person asks for.
  static String badgeFor(Object error) => switch (error) {
    ApiException(:final statusCode) => 'HTTP $statusCode',
    NetworkException() => 'OFFLINE',
    RequestTimeoutException() || TimeoutException() => 'TIMEOUT',
    _ => 'APP ERROR',
  };

  /// A hard outage (red), as opposed to something struggling or unexplained
  /// (amber).
  bool get isOutage => this == offline || this == serverDown;

  /// The hop the diagram marks as the problem: 0 phone, 1 internet, 2 server.
  int get faultyNode => switch (this) {
    offline => 1,
    serverDown || slow => 2,
    unexpected => 0,
  };

  /// The link that failed: 0 phone–internet, 1 internet–server, or null when
  /// the fault is on the phone itself.
  int? get brokenLink => switch (this) {
    offline => 0,
    serverDown || slow => 1,
    unexpected => null,
  };

  IconData get icon => switch (this) {
    offline => LucideIcons.wifiOff,
    serverDown => LucideIcons.serverCrash,
    slow => LucideIcons.hourglass,
    unexpected => LucideIcons.triangleAlert,
  };

  String headline(S s) => switch (this) {
    offline => s.t('لا يوجد اتصال بالإنترنت', 'You’re offline'),
    serverDown => s.t('خادمنا لا يستجيب الآن', 'Our server isn’t responding'),
    slow => s.t('الاتصال بطيء جداً', 'The connection is too slow'),
    unexpected => s.t('حدث خطأ غير متوقع', 'Something went wrong'),
  };

  String explanation(S s) => switch (this) {
    offline => s.t(
      'لم يتمكن هاتفك من الوصول إلى الإنترنت، لذلك تعذّر تحميل بيانات '
          'التطبيق.',
      'Your phone couldn’t reach the internet, so the app’s data couldn’t '
          'load.',
    ),
    serverDown => s.t(
      'اتصالك يعمل، لكن خادم AK Cars لم يرد. المشكلة عندنا وليست عندك، '
          'وعادةً تُحل خلال دقائق.',
      'Your connection works, but the AK Cars server didn’t answer. The '
          'problem is on our side, not yours, and it’s usually fixed within '
          'minutes.',
    ),
    slow => s.t(
      'وصلنا إلى الخادم، لكن الرد استغرق وقتاً أطول مما ينتظره التطبيق.',
      'We reached the server, but the answer took longer than the app waits.',
    ),
    unexpected => s.t(
      'تعذّر تحضير بيانات التطبيق. جرّب مرة أخرى، وإن تكرر الخطأ فأرسل '
          'التفاصيل إلى الدعم.',
      'The app couldn’t prepare its data. Try again — if it keeps happening, '
          'send the details to support.',
    ),
  };

  /// What the person can do about it, most useful first.
  List<BootFailureTip> tips(S s) => switch (this) {
    offline => [
      (
        icon: LucideIcons.wifi,
        text: s.t('شغّل الواي فاي أو بيانات الجوال', 'Turn on Wi-Fi or mobile data'),
      ),
      (
        icon: LucideIcons.plane,
        text: s.t('تأكد أن وضع الطيران مغلق', 'Make sure airplane mode is off'),
      ),
      (
        icon: LucideIcons.shieldOff,
        text: s.t('أوقف أي VPN مؤقتاً ثم أعد المحاولة',
            'Pause any VPN, then try once more'),
      ),
    ],
    serverDown => [
      (
        icon: LucideIcons.shieldCheck,
        text: s.t('حسابك وحجوزاتك في أمان', 'Your account and bookings are safe'),
      ),
      (
        icon: LucideIcons.clock,
        text: s.t('انتظر دقيقة، فالانقطاع عادةً قصير',
            'Wait a minute — outages are usually brief'),
      ),
      (
        icon: LucideIcons.rotateCw,
        text: s.t('ثم اضغط «حاول مرة أخرى»', 'Then tap “Try again” below'),
      ),
    ],
    slow => [
      (
        icon: LucideIcons.signal,
        text: s.t('انتقل إلى مكان تكون فيه الإشارة أقوى',
            'Move to a spot with a stronger signal'),
      ),
      (
        icon: LucideIcons.wifi,
        text: s.t('بدّل بين الواي فاي وبيانات الجوال',
            'Switch between Wi-Fi and mobile data'),
      ),
      (
        icon: LucideIcons.timer,
        text: s.t('امنحه لحظة ثم أعد المحاولة',
            'Give it a moment, then try once more'),
      ),
    ],
    unexpected => [
      (
        icon: LucideIcons.rotateCw,
        text: s.t('أعد المحاولة، فالأعطال العابرة تزول غالباً',
            'Try once more — one-off glitches usually clear'),
      ),
      (
        icon: LucideIcons.refreshCw,
        text: s.t('أغلق التطبيق وافتحه من جديد', 'Close the app and open it again'),
      ),
      (
        icon: LucideIcons.messageCircle,
        text: s.t('إن استمر، انسخ التفاصيل وأرسلها للدعم',
            'Still failing? Copy the details for support'),
      ),
    ],
  };
}
