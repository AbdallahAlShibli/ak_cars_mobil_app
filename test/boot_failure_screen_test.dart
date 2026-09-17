import 'dart:async';

import 'package:ak_cars_mobil_app/app/boot_failure_kind.dart';
import 'package:ak_cars_mobil_app/app/boot_failure_screen.dart';
import 'package:ak_cars_mobil_app/core/error/app_exception.dart';
import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The failure screen tells the person *where* start-up broke. The screenshot
/// that prompted the redesign was a tunnel answering 502 in front of a stopped
/// API, which the old screen described as "check your connection" — the one
/// thing that was not wrong.
void main() {
  group('which failure it is', () {
    test('an unreachable host is being offline', () {
      expect(
        BootFailureKind.of(const NetworkException('no route')),
        BootFailureKind.offline,
      );
    });

    test('a 5xx is the server being down, whatever the code', () {
      for (final code in [500, 502, 503, 504]) {
        expect(
          BootFailureKind.of(ApiException('x', statusCode: code)),
          BootFailureKind.serverDown,
        );
      }
    });

    test('a slow request and an overall start-up timeout are both slow', () {
      expect(
        BootFailureKind.of(const RequestTimeoutException('slow')),
        BootFailureKind.slow,
      );
      expect(
        BootFailureKind.of(TimeoutException('boot')),
        BootFailureKind.slow,
      );
    });

    test('anything else is unexpected, never blamed on the connection', () {
      expect(
        BootFailureKind.of(const ApiException('x', statusCode: 404)),
        BootFailureKind.unexpected,
      );
      expect(BootFailureKind.of(StateError('boom')), BootFailureKind.unexpected);
    });

    test('the diagram badge names the failure the way support would ask', () {
      expect(
        BootFailureKind.badgeFor(const ApiException('x', statusCode: 502)),
        'HTTP 502',
      );
      expect(
        BootFailureKind.badgeFor(const NetworkException('x')),
        'OFFLINE',
      );
      expect(BootFailureKind.badgeFor(TimeoutException('x')), 'TIMEOUT');
      expect(BootFailureKind.badgeFor(StateError('x')), 'APP ERROR');
    });

    test('every kind has its copy and three tips in both languages', () {
      for (final kind in BootFailureKind.values) {
        for (final s in const [S(true), S(false)]) {
          expect(kind.headline(s), isNotEmpty);
          expect(kind.explanation(s), isNotEmpty);
          expect(kind.tips(s), hasLength(3));
        }
      }
    });
  });

  group('the screen', () {
    Future<void> pumpScreen(WidgetTester tester, Object error) async {
      await tester.pumpWidget(BootFailureApp(error: error, onRetry: () async {}));
      // Past the whole entrance, into the looping animations.
      await tester.pump(const Duration(milliseconds: 1600));
    }

    testWidgets('a 502 says the server is down and marks it on the diagram',
        (tester) async {
      await pumpScreen(
        tester,
        const ApiException('Request failed', statusCode: 502),
      );

      expect(find.text('The app could not start'), findsOneWidget);
      expect(find.text('Our server isn’t responding'), findsOneWidget);
      expect(find.text('Where the connection stopped'), findsOneWidget);
      expect(find.text('HTTP 502'), findsOneWidget);
      expect(find.text('Your phone'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('AK Cars server'), findsOneWidget);
      // Phone and internet reached; the server is the break.
      expect(find.text('Working'), findsNWidgets(2));
      expect(find.text('No response'), findsOneWidget);
      expect(find.text('Your account and bookings are safe'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('offline breaks the first link and never reaches the server',
        (tester) async {
      await pumpScreen(tester, const NetworkException('no route'));

      expect(find.text('You’re offline'), findsOneWidget);
      expect(find.text('Working'), findsOneWidget);
      expect(find.text('No response'), findsOneWidget);
      expect(find.text('Not reached'), findsOneWidget);
      expect(find.text('Turn on Wi-Fi or mobile data'), findsOneWidget);
    });

    testWidgets('the error details can be copied for support', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpScreen(
        tester,
        const ApiException('Request failed', statusCode: 502),
      );

      await tester.tap(find.text('Error details'));
      // The first pump starts the sheet's slide-in; the second finishes it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('ApiException(502): Request failed'),
        findsOneWidget,
      );

      await tester.tap(find.text('Copy details'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(copied, 'ApiException(502): Request failed');
      expect(find.text('Error details copied'), findsOneWidget);
    });

    testWidgets('reduce motion shows the finished screen and stops the loops',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        BootFailureApp(
          error: const ApiException('x', statusCode: 502),
          onRetry: () async {},
        ),
      );
      await tester.pump();

      expect(find.text('Our server isn’t responding'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('every kind fits a small phone in both languages',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      for (final locale in const [Locale('en'), Locale('ar')]) {
        tester.platformDispatcher.localeTestValue = locale;
        for (final error in <Object>[
          const NetworkException('no route'),
          const ApiException('Request failed', statusCode: 502),
          const RequestTimeoutException('slow'),
          StateError('warm-up exploded'),
        ]) {
          await tester.pumpWidget(
            BootFailureApp(key: UniqueKey(), error: error, onRetry: () async {}),
          );
          await tester.pump(const Duration(milliseconds: 1600));
          expect(tester.takeException(), isNull, reason: '$locale · $error');
        }
      }
    });

    testWidgets('in Arabic it reads right to left without overflowing',
        (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('ar');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await pumpScreen(tester, const NetworkException('no route'));

      expect(find.text('تعذّر تشغيل التطبيق'), findsOneWidget);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
      expect(find.text('You’re offline'), findsNothing);
    });
  });
}
