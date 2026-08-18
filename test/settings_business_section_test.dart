import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ak_cars_mobil_app/core/utils/guid.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/di/providers.dart';
import 'package:ak_cars_mobil_app/features/settings/settings_screen.dart';
import 'package:ak_cars_mobil_app/state/app_state.dart';

import 'fakes/fakes.dart';
import 'fakes/memory_token_store.dart';
import 'helpers/test_harness.dart';

/// The bottom "My business" section used to be a device-local role switcher
/// anyone could flip — these assert its real replacement: the rows are a
/// direct read of the account's own facts, present only when there is a real
/// one to show.
void main() {
  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    final container = await createTestContainer(overrides: overrides);
    tester.view.physicalSize = const Size(402 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('ar'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  MediaAttachment crAttachment() => MediaAttachment(
        id: derivedGuid('test-cr', 'settings-test'),
        base64Data:
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
            'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        mimeType: 'image/png',
        fileName: 'cr.png',
      );

  UserProfile workshopProfile(String id) => UserProfile(
        id: id,
        name: 'Owner',
        phone: '+968 9200 0001',
        email: 'owner@example.om',
        region: 'Muscat',
        wilayat: 'Seeb',
        address: 'Street 1',
        kind: AccountKind.workshop,
        workshop: WorkshopApplication(
          businessNameAr: 'ورشة',
          businessNameEn: 'Test Workshop',
          crNumber: '1234567',
          crDocument: crAttachment(),
          area: 'Seeb',
          fulfillments: const {Fulfillment.workshop},
          submittedAt: DateTime.now(),
        ),
      );

  testWidgets('a plain customer sees no business section at all', (
    tester,
  ) async {
    await pumpSettings(tester);
    expect(find.text('Workshop dashboard'), findsNothing);
    expect(find.text('Founder panel'), findsNothing);
    expect(find.text('My business'), findsNothing);
  });

  testWidgets(
    'a workshop applicant sees the row with a pending status, not a link',
    (tester) async {
      final container = await pumpSettings(tester);
      await container.read(authProvider.notifier).register(
            workshopProfile('u-pending'),
          );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('My business'), findsOneWidget);
      expect(find.text('Workshop dashboard'), findsOneWidget);
      // Not approved yet — the row shows the real onboarding stage, not a
      // dashboard link a 403 would immediately bounce back from.
      expect(find.text('Documents submitted'), findsOneWidget);
      expect(find.text('Founder panel'), findsNothing);
    },
  );

  testWidgets('an approved workshop owner sees a real, tappable link', (
    tester,
  ) async {
    final container = await pumpSettings(tester);
    await container.read(authProvider.notifier).register(
          workshopProfile('u-approved'),
        );
    final workshop = container
        .read(serviceMarketplaceRepositoryProvider)
        .providerOwnedBy('u-approved')!;
    await container
        .read(adminActionsProvider)
        .setStage(workshop.id, ProviderOnboardingStage.approved);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Workshop dashboard'), findsOneWidget);
    expect(find.text('Documents submitted'), findsNothing);
    expect(find.text('Founder panel'), findsNothing);
  });

  testWidgets('a real founder JWT shows the founder row, with no workshop '
      'row beside it', (tester) async {
    String segment(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final founderToken = '${segment({
          'alg': 'none',
        })}.${segment({
          'http://schemas.microsoft.com/ws/2008/06/identity/claims/role':
              'founder',
        })}.sig';

    final container = await pumpSettings(
      tester,
      overrides: [
        tokenStoreProvider.overrideWithValue(
          MemoryTokenStore(access: founderToken, refresh: 'r'),
        ),
      ],
    );
    await container.read(authProvider.notifier).register(
          const UserProfile(
            name: 'Founder',
            phone: '+968 9555 6666',
            email: 'founder@example.om',
            region: 'Muscat',
            address: '',
          ),
        );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Founder panel'), findsOneWidget);
    expect(find.text('Workshop dashboard'), findsNothing);
  });
}
