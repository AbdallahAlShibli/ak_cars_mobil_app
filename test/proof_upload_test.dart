import 'package:ak_cars_mobil_app/core/i18n/strings.dart';
import 'package:ak_cars_mobil_app/core/theme/app_theme.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:ak_cars_mobil_app/features/services/proof_upload_sheet.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// The completion-proof composer (spec §3).
///
/// The sheet enforces the same two rules as
/// `ServiceRequest.proofSatisfiesRules`, and it has to: a form that lets a
/// workshop fill everything in and then fails silently at the state machine
/// is worse than one that says what is missing.

const _car = Car(id: 'c1', make: 'Toyota', model: 'Camry', year: 2019);

/// Stands in for the camera. Returns a fixed path rather than touching a
/// platform channel, so the test exercises the sheet's rules instead of the
/// plugin's.
class _StubPickerPlatform extends ImagePickerPlatform {
  int calls = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls++;
    return XFile('https://example.test/shot-$calls.jpg');
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    calls++;
    return [XFile('https://example.test/shot-$calls.jpg')];
  }
}

ServiceRequest _request(BookingType type) => ServiceRequest(
      id: 'r1',
      offering: MockServiceData.offerings.first,
      car: _car,
      plate: '1 A',
      fulfillment: Fulfillment.workshop,
      slot: '10:00',
      addOns: const [],
      total: 12,
      type: type,
      escrow: EscrowState.inProgress,
      createdAt: DateTime.now(),
    );

Future<void> _open(WidgetTester tester, BookingType type) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: ProofUploadSheet(s: S.of(context), request: _request(type)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Fresh per test so the shot counter (and so each attachment's path) does
  // not carry over between them.
  setUp(() => ImagePickerPlatform.instance = _StubPickerPlatform());

  testWidgets('submit is refused until a photo is attached', (tester) async {
    await _open(tester, BookingType.catalogService);

    final submit = find.widgetWithText(FilledButton, 'Submit proof');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    // And says which rule is unmet rather than leaving a dead button.
    expect(find.textContaining('at least one photo'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Camera'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    expect(find.textContaining('at least one photo'), findsNothing);
  });

  testWidgets('a part job additionally needs the box declared', (tester) async {
    await _open(tester, BookingType.customQuote);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Camera'));
    await tester.pumpAndSettle();

    // Photo attached, but the part-box declaration is still missing.
    final submit = find.widgetWithText(FilledButton, 'Submit proof');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(find.textContaining('part’s box'), findsWidgets);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('a catalogue job is never asked about a part box', (
    tester,
  ) async {
    await _open(tester, BookingType.catalogService);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('an attached photo can be taken back off', (tester) async {
    await _open(tester, BookingType.catalogService);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Camera'));
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'Submit proof');
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();

    // Back to nothing attached — and back to being unable to submit.
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });
}
