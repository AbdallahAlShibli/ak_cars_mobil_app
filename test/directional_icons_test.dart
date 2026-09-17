import 'dart:io';
import 'dart:math' as math;

import 'package:ak_cars_mobil_app/core/widgets/directional_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Icons that point along the line of text must point the reading
/// direction's way — the Arabic profile tab once had a guest card chevron
/// pointing back while every row under it pointed forward.
void main() {
  Future<BuildContext> contextIn(WidgetTester tester, TextDirection direction) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }),
      ),
    );
    return captured;
  }

  group('DirectionalIcons', () {
    testWidgets('forward points left in Arabic', (tester) async {
      final context = await contextIn(tester, TextDirection.rtl);
      expect(DirectionalIcons.forwardChevron(context), LucideIcons.chevronLeft);
      expect(DirectionalIcons.forwardArrow(context), LucideIcons.arrowLeft);
    });

    testWidgets('forward points right in English', (tester) async {
      final context = await contextIn(tester, TextDirection.ltr);
      expect(DirectionalIcons.forwardChevron(context), LucideIcons.chevronRight);
      expect(DirectionalIcons.forwardArrow(context), LucideIcons.arrowRight);
    });
  });

  group('MirroredIcon', () {
    Future<double> horizontalScale(WidgetTester tester, TextDirection direction) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: const MirroredIcon(LucideIcons.sendHorizontal, size: 18),
        ),
      );
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(MirroredIcon),
          matching: find.byType(Transform),
        ),
      );
      return transform.transform.storage[0];
    }

    testWidgets('is mirrored in Arabic and drawn as-is in English', (tester) async {
      expect(await horizontalScale(tester, TextDirection.rtl), -1);
      expect(await horizontalScale(tester, TextDirection.ltr), 1);
      expect(find.byIcon(LucideIcons.sendHorizontal), findsOneWidget);
    });
  });

  // A source scan, so the next fixed chevron fails here rather than on a
  // phone in Arabic. A left/right chevron or arrow is accepted only where the
  // text direction is consulted on the same line or just above it (the
  // established `... == TextDirection.rtl ? left : right` shape, or a local
  // `rtl` flag), or inside DirectionalIcons itself.
  test('no chevron or arrow in lib is fixed to one side', () {
    final glyph = RegExp(r'LucideIcons\.(chevron|arrow)(Left|Right)\b');
    final exempt = [
      'lib/core/widgets/directional_icons.dart',
      // Server-sent icon names: no layout, so no direction to follow.
      'lib/core/json/icon_codec.dart',
    ];
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      if (exempt.any(path.endsWith)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!glyph.hasMatch(lines[i])) continue;
        final window =
            lines.sublist(math.max(0, i - 3), i + 1).join(' ').toLowerCase();
        if (window.contains('rtl')) continue;
        offenders.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
