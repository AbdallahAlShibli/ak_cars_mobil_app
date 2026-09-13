import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/media_attachment.dart';
import '../theme/app_colors.dart';
import 'attachment_view.dart';
import 'sand_widgets.dart';

/// An announcement card, exactly as it is painted on the Home page's rail —
/// and nothing else.
///
/// It resolves nothing and navigates nowhere: the caller passes finished text,
/// a finished trailing widget, and a day count that has already been computed
/// and localised. That is what makes it usable twice. On Home,
/// `HomeAnnouncementsRail` wraps it in the tap target and feeds it a
/// `Promotion`; in the founder's content editor the same widget is fed the
/// half-typed contents of the form, so the founder is looking at the actual
/// card while writing it rather than at a description of one.
///
/// The two call sites sharing this is the point. A preview drawn separately
/// from the thing it previews drifts within a release, and the founder finds
/// out that it drifted from a customer — so the preview is not *like* the
/// card, it **is** the card.
///
/// Give it a bounded height ([railHeight] is what the rail uses). The body
/// takes up the slack, so a title or body that is too long ellipsises here in
/// exactly the place it would ellipsise on a phone — which is the single thing
/// a founder most needs a preview to tell them.
///
/// It has two finished looks and picks between them from the data rather than
/// from a flag: with an [image] it is a photo card — the picture edge to edge
/// under a scrim, the text on top of it; without one it keeps the sand
/// gradient. Neither is the degraded version of the other, so a founder with
/// no picture to hand never ships a visibly worse card.
class PromotionCardFace extends StatelessWidget {
  const PromotionCardFace({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.image,
    this.badge,
    this.trailing,
    this.deadline,
    this.fade = 1,
  });

  final IconData icon;
  final String title;
  final String body;

  /// The founder's background photograph, or null for the gradient card.
  ///
  /// Drawn with `BoxFit.cover` and always under a scrim, so a bright or busy
  /// photo cannot take the title down with it — the alternative, trusting
  /// whatever was uploaded to be dark enough behind white text, is how one bad
  /// picture makes the home page unreadable.
  final MediaAttachment? image;

  /// The small pill in the top corner. Null — or blank — on an announcement
  /// that has none.
  final String? badge;

  /// The bottom-left slot: a price, or "quote after inspection". Null leaves
  /// that row to the deadline and the arrow.
  final Widget? trailing;

  /// The already-localised deadline sentence ("3 days left", "last day"), or
  /// null for an open-ended announcement, which shows no clock at all.
  ///
  /// Localised by the caller rather than here: pluralising a day count is the
  /// `S` layer's job, and a presentation widget that reaches for it cannot be
  /// rendered from a preview that is showing a hypothetical.
  final String? deadline;

  /// Carousel neighbour fade. Applied straight to the background colours on
  /// the gradient card — cheaper every frame of the drag than wrapping the
  /// composited card in an [Opacity]. The photo card has an image to fade, so
  /// that one does pay for a layer.
  final double fade;

  /// The height the Home rail gives one of these. Exported so a preview can
  /// ask for the same box instead of guessing at it.
  static const railHeight = 178.0;

  /// True when [body] would only repeat [title] back to the reader.
  ///
  /// Founders do this — the card that prompted this rewrite carried the same
  /// five words as badge, title *and* body, which paints something that looks
  /// broken and empty rather than something that says one thing three times.
  /// Dropping the duplicate line gives the title the room instead.
  bool get _bodyRepeatsTitle {
    final a = title.trim().toLowerCase();
    final b = body.trim().toLowerCase();
    return b.isEmpty || a == b;
  }

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final candidate = image;
    final photo = candidate != null &&
            candidate.kind == MediaKind.image &&
            candidate.hasBytes
        ? candidate
        : null;
    final onPhoto = photo != null;

    // One palette per look, resolved once: nothing below branches on `onPhoto`
    // again.
    final titleColor = onPhoto ? Colors.white : ak.promoTitle;
    final subColor =
        onPhoto ? Colors.white.withValues(alpha: 0.86) : ak.promoSub;
    final chipColor = onPhoto
        ? Colors.white.withValues(alpha: 0.22)
        : ak.surface.withValues(alpha: 0.55);

    final pill = badge?.trim();
    final showBadge = pill != null && pill.isNotEmpty && pill != title.trim();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: onPhoto
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ak.promoBgA.withValues(alpha: fade),
                  ak.promoBgB.withValues(alpha: fade),
                ],
              ),
        color: onPhoto ? ak.promoBgB.withValues(alpha: fade) : null,
        border: Border.all(
          color: onPhoto
              ? Colors.black.withValues(alpha: 0.10 * fade)
              : ak.promoBorder.withValues(alpha: fade),
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null) ...[
            Opacity(opacity: fade, child: AttachmentView(attachment: photo)),
            // The scrim: heavier at the bottom, where the price and the
            // deadline sit on top of whatever the photo happens to show there.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.30 * fade),
                    Colors.black.withValues(alpha: 0.68 * fade),
                  ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: chipColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 17, color: titleColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        // Two lines when the body is carrying its own weight,
                        // three when it was a duplicate we dropped — the space
                        // goes to the one line that is saying something.
                        maxLines: _bodyRepeatsTitle ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ),
                    if (showBadge) ...[
                      const SizedBox(width: 8),
                      SandStatusPill(
                        pill,
                        background: onPhoto
                            ? Colors.white.withValues(alpha: 0.92)
                            : ak.surface.withValues(alpha: 0.7),
                        foreground: onPhoto ? ak.ink : ak.promoSub,
                      ),
                    ],
                  ],
                ),
                // A body that only repeated the title leaves a gap rather than
                // a second copy of it.
                if (_bodyRepeatsTitle)
                  const Spacer()
                else ...[
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: subColor,
                      ),
                    ),
                  ),
                ],
                Row(
                  children: [
                    ?trailing,
                    const Spacer(),
                    // A deadline is only shown when the campaign really has one.
                    if (deadline != null) ...[
                      Icon(LucideIcons.clock, size: 11, color: subColor),
                      const SizedBox(width: 4),
                      Text(
                        deadline!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                      const SizedBox(width: 9),
                    ],
                    // Forward, not right: in Arabic the card opens leftwards,
                    // and an arrow pointing the other way reads as "back".
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? LucideIcons.arrowLeft
                          : LucideIcons.arrowRight,
                      size: 14,
                      color: titleColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
