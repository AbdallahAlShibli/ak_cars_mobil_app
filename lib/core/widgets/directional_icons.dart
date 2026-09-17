import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Icons whose meaning is a direction along the line of text.
///
/// "Go on / open this" points toward the *end* of the line: right in English,
/// left in Arabic. A fixed `chevronRight` reads as "back" in Arabic, which is
/// how several rows ended up pointing against the rest of the screen.
abstract final class DirectionalIcons {
  static bool _isRtl(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  /// A row or card that opens something.
  static IconData forwardChevron(BuildContext context) =>
      _isRtl(context) ? LucideIcons.chevronLeft : LucideIcons.chevronRight;

  /// A call to action that moves on ("Book this offer →", search go).
  static IconData forwardArrow(BuildContext context) =>
      _isRtl(context) ? LucideIcons.arrowLeft : LucideIcons.arrowRight;
}

/// An icon drawn for left-to-right that has no mirrored twin in Lucide — log
/// in, send, a branch connector — shown mirrored when the text runs
/// right-to-left.
///
/// Flipped as a widget rather than through `IconData.matchTextDirection`:
/// that needs a non-const `IconData`, which stops release builds from
/// tree-shaking the icon font.
class MirroredIcon extends StatelessWidget {
  const MirroredIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Transform.flip(
    flipX: Directionality.of(context) == TextDirection.rtl,
    child: Icon(icon, size: size, color: color, semanticLabel: semanticLabel),
  );
}
