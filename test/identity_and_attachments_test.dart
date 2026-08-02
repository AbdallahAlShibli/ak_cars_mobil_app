import 'dart:convert';
import 'dart:typed_data';

import 'package:ak_cars_mobil_app/core/media/media_codec.dart';
import 'package:ak_cars_mobil_app/core/utils/guid.dart';
import 'package:ak_cars_mobil_app/core/widgets/attachment_view.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_ids.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_seed.dart';
import 'package:ak_cars_mobil_app/data/datasources/mock/mock_service_data.dart';
import 'package:ak_cars_mobil_app/data/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// The two rules this app now holds itself to:
///
/// 1. every record is identified by a GUID, and
/// 2. every user-supplied file travels as base64 on the record that owns it,
///    and is decoded back to bytes to be displayed.
///
/// Both are the sort of rule that decays quietly — one new model with a
/// `'my-${timestamp}'` id, one screen that renders a path — so they are
/// asserted over the whole dataset rather than on one example.
void main() {
  group('GUID identity', () {
    test('newGuid produces a well-formed, unique v4', () {
      final ids = {for (var i = 0; i < 2000; i++) newGuid()};
      expect(ids, hasLength(2000), reason: 'ids must not repeat');
      for (final id in ids.take(50)) {
        expect(isGuid(id), isTrue, reason: '$id is not a GUID');
        expect(id[14], '4', reason: 'version nibble');
        expect('89ab'.contains(id[19]), isTrue, reason: 'variant nibble');
      }
    });

    test('isGuid rejects the id schemes this replaced', () {
      for (final old in [
        'p3',
        'express',
        'rev-501',
        'm1754120000000-0',
        'booking-2101',
        '',
        'not-a-guid',
        // Uppercase is rejected deliberately: one spelling only, or two
        // copies of the same id stop comparing equal.
        '3F2A7C1E-8B4D-4E9A-A5F0-2C6D1B7E4A93',
      ]) {
        expect(isGuid(old), isFalse, reason: '"$old" must not pass as a GUID');
      }
      expect(isGuid(emptyGuid), isTrue);
    });

    test('derivedGuid is stable for the same inputs and differs across them',
        () {
      expect(derivedGuid('offering', 'a', 'b'), derivedGuid('offering', 'a', 'b'));
      expect(isGuid(derivedGuid('offering', 'a', 'b')), isTrue);
      expect(derivedGuid('offering', 'a', 'b'),
          isNot(derivedGuid('offering', 'b', 'a')));
      expect(derivedGuid('offering', 'a'), isNot(derivedGuid('proof', 'a')));
    });

    test('coerceGuid keeps a GUID and re-keys anything else', () {
      final good = newGuid();
      expect(coerceGuid(good), good);
      expect(isGuid(coerceGuid('rev-501')), isTrue);
      expect(isGuid(coerceGuid(null)), isTrue);
    });

    test('every seeded record carries a GUID', () {
      void check(String label, Iterable<String> ids) {
        expect(ids, isNotEmpty, reason: '$label seeded nothing to check');
        for (final id in ids) {
          expect(isGuid(id), isTrue, reason: '$label has non-GUID id "$id"');
        }
      }

      check('providers', MockSeed.providers.map((p) => p.id));
      check('requests', MockSeed.requests.map((r) => r.id));
      check('reviews', MockSeed.reviews.map((r) => r.id));
      check('payouts', MockSeed.payouts.map((p) => p.id));
      check('audit', MockSeed.audit.map((a) => a.id));
      check('cars', MockSeed.cars.map((c) => c.id));
      check('categories', MockServiceData.categories.map((c) => c.id));
      check('offerings', MockServiceData.offerings.map((o) => o.id));
      check(
        'add-ons',
        MockServiceData.addOnsByProvider.values.expand((l) => l).map((a) => a.id),
      );
      check('offers', MockServiceData.offers.map((o) => o.id));
      check('promotions', MockServiceData.promotions.map((p) => p.id));
    });

    test('a category keeps a readable slug beside its GUID', () {
      for (final category in MockServiceData.categories) {
        expect(category.slug, isNotEmpty,
            reason: '${category.id} has no slug to recognise it by');
        expect(isGuid(category.slug), isFalse,
            reason: 'the slug is the readable key, not a second id');
        expect(mockCategoryId(category.slug), category.id);
      }
    });

    test('offerings agree with their category on both id and slug', () {
      for (final offering in MockServiceData.offerings) {
        final category = MockServiceData.categories
            .firstWhere((c) => c.id == offering.categoryId);
        expect(offering.categorySlug, category.slug);
      }
    });

    test('cross-references resolve — no id points at nothing', () {
      final providerIds = {for (final p in MockSeed.providers) p.id};
      final offeringIds = {for (final o in MockServiceData.offerings) o.id};
      for (final offer in MockServiceData.offers) {
        expect(providerIds, contains(offer.workshopId));
        expect(offeringIds, contains(offer.serviceOfferingId));
      }
      for (final request in MockSeed.requests) {
        expect(providerIds, contains(request.offering.provider.id));
      }
    });
  });

  group('base64 attachments', () {
    final bytes = Uint8List.fromList(base64Decode(testPngBase64));

    test('encode → decode round-trips the exact bytes', () {
      final encoded = encodeAttachmentBytes(bytes);
      expect(tryDecodeAttachment(encoded), bytes);
    });

    test('a data: URI prefix is tolerated on the way in', () {
      final encoded = encodeAttachmentBytes(bytes);
      expect(tryDecodeAttachment('data:image/png;base64,$encoded'), bytes);
    });

    test('malformed or empty base64 decodes to null, never throws', () {
      for (final broken in ['', 'not base64 at all!!', 'data:image/png']) {
        expect(tryDecodeAttachment(broken), isNull);
      }
    });

    test('byteLength matches the real decoded size without decoding', () {
      for (final size in [1, 2, 3, 4, 5, 100, 999]) {
        final raw = Uint8List.fromList(List.filled(size, 7));
        final attachment = MediaAttachment(
          id: newGuid(),
          base64Data: encodeAttachmentBytes(raw),
          mimeType: 'application/octet-stream',
        );
        expect(attachment.byteLength, size);
      }
    });

    test('kind is derived from the MIME type, so the two cannot disagree', () {
      MediaAttachment of(String mime) =>
          MediaAttachment(id: newGuid(), base64Data: 'AA==', mimeType: mime);
      expect(of('image/png').kind, MediaKind.image);
      expect(of('image/jpeg').kind, MediaKind.image);
      expect(of('video/mp4').kind, MediaKind.video);
      expect(of('application/pdf').kind, MediaKind.document);
      expect(of('application/octet-stream').kind, MediaKind.document);
    });

    test('MIME resolution prefers what the picker declared', () {
      expect(resolveMimeType(declared: 'image/png', path: 'x.jpg'),
          'image/png');
      expect(resolveMimeType(path: '/tmp/photo.JPG'), 'image/jpeg');
      expect(resolveMimeType(path: 'cr.pdf'), 'application/pdf');
      // Unknown rather than guessed: rendering a PDF as an image is worse
      // than saying there is no preview.
      expect(resolveMimeType(path: 'mystery.xyz'), 'application/octet-stream');
      expect(resolveMimeType(path: 'noextension'), 'application/octet-stream');
    });

    test('fileNameFrom handles both path separators', () {
      expect(fileNameFrom('/data/user/0/cache/shot.jpg'), 'shot.jpg');
      expect(fileNameFrom(r'C:\Users\x\cr.png'), 'cr.png');
      expect(fileNameFrom('bare.png'), 'bare.png');
    });

    test('an attachment survives a JSON round trip with its bytes intact', () {
      final original = MediaAttachment(
        id: newGuid(),
        base64Data: encodeAttachmentBytes(bytes),
        mimeType: 'image/png',
        fileName: 'cr.png',
        caption: 'الفلتر القديم',
      );
      final restored = MediaAttachment.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored, original);
      expect(restored.base64Data, original.base64Data);
      expect(tryDecodeAttachment(restored.base64Data), bytes);
    });

    test('hasBytes separates a real attachment from a placeholder', () {
      expect(
        MediaAttachment(id: newGuid(), base64Data: '', mimeType: 'image/png')
            .hasBytes,
        isFalse,
      );
      expect(
        MediaAttachment(
          id: newGuid(),
          base64Data: testPngBase64,
          mimeType: 'image/png',
        ).hasBytes,
        isTrue,
      );
    });

    test('a proof of nothing but empty attachments does not count as evidence',
        () {
      final empty = ProofOfWork(
        id: newGuid(),
        requestId: newGuid(),
        notes: '',
        submittedAt: DateTime.now(),
        media: [
          MediaAttachment(id: newGuid(), base64Data: '', mimeType: 'image/png'),
        ],
      );
      expect(empty.hasMedia, isFalse);
    });

    test('every seeded workshop document and proof photo carries real bytes',
        () {
      final documented = MockSeed.providers
          .where((p) => p.crDocument != null)
          .toList();
      expect(documented, isNotEmpty);
      for (final provider in documented) {
        final doc = provider.crDocument!;
        expect(isGuid(doc.id), isTrue);
        expect(doc.hasBytes, isTrue);
        expect(tryDecodeAttachment(doc.base64Data), isNotNull,
            reason: '${doc.fileName} does not decode');
        expect(doc.kind, MediaKind.image);
      }

      final proofs =
          MockSeed.requests.map((r) => r.proof).nonNulls.toList();
      expect(proofs, isNotEmpty);
      for (final proof in proofs) {
        for (final photo in proof.media) {
          expect(isGuid(photo.id), isTrue);
          expect(tryDecodeAttachment(photo.base64Data), isNotNull);
        }
      }
    });
  });

  group('rendering a stored attachment', () {
    setUp(resetAttachmentCache);

    Future<void> pump(WidgetTester tester, MediaAttachment attachment) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: AttachmentView(attachment: attachment),
            ),
          ),
        ));

    testWidgets('an image attachment is decoded and drawn from memory',
        (tester) async {
      await pump(
        tester,
        MediaAttachment(
          id: newGuid(),
          base64Data: testPngBase64,
          mimeType: 'image/png',
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(AttachmentUnavailable), findsNothing);
      // Bytes, not a URL or a file path — that is the whole point.
      expect(tester.widget<Image>(find.byType(Image)).image,
          isA<MemoryImage>());
    });

    testWidgets('a corrupt attachment says so instead of drawing blank space',
        (tester) async {
      await pump(
        tester,
        MediaAttachment(
          id: newGuid(),
          base64Data: 'this is not base64',
          mimeType: 'image/png',
        ),
      );
      expect(find.byType(AttachmentUnavailable), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a PDF is named and sized rather than shown as a broken image',
        (tester) async {
      await pump(
        tester,
        MediaAttachment(
          id: newGuid(),
          base64Data: testPngBase64,
          mimeType: 'application/pdf',
          fileName: 'cr-1307654.pdf',
        ),
      );
      expect(find.text('cr-1307654.pdf'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('the same attachment decodes once and is reused', (tester) async {
      final attachment = MediaAttachment(
        id: newGuid(),
        base64Data: testPngBase64,
        mimeType: 'image/png',
      );
      await pump(tester, attachment);
      final first = tester.widget<Image>(find.byType(Image)).image;
      await tester.pumpWidget(const SizedBox());
      await pump(tester, attachment);
      final second = tester.widget<Image>(find.byType(Image)).image;
      // Same bytes instance, so neither the base64 decode nor Flutter's own
      // image cache does the work twice.
      expect((first as MemoryImage).bytes,
          same((second as MemoryImage).bytes));
    });
  });

  group('byte-size labelling', () {
    test('reads as a person would write it', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes(maxAttachmentBytes), '4.0 MB');
    });
  });
}
