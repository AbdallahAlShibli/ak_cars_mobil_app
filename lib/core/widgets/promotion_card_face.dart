import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
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
class PromotionCardFace extends StatelessWidget {
  const PromotionCardFace({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.badge,
    this.trailing,
    this.deadline,
    this.fade = 1,
  });

  final IconData icon;
  final String title;
  final String body;

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

  /// Carousel neighbour fade, applied straight to the background colours
  /// rather than by wrapping this (composited) card in an [Opacity] — cheaper
  /// every frame of the drag, since there is no image to fade here.
  final double fade;

  /// The height the Home rail gives one of these. Exported so a preview can
  /// ask for the same box instead of guessing at it.
  static const railHeight = 178.0;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final pill = badge?.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ak.promoBgA.withValues(alpha: fade),
            ak.promoBgB.withValues(alpha: fade),
          ],
        ),
        border: Border.all(color: ak.promoBorder.withValues(alpha: fade)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ak.surface.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: ak.promoTitle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: ak.promoTitle,
                  ),
                ),
              ),
              if (pill != null && pill.isNotEmpty) ...[
                const SizedBox(width: 8),
                SandStatusPill(
                  pill,
                  background: ak.surface.withValues(alpha: 0.7),
                  foreground: ak.promoSub,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: ak.promoSub),
            ),
          ),
          Row(
            children: [
              ?trailing,
              const Spacer(),
              // A deadline is only shown when the campaign really has one.
              if (deadline != null) ...[
                Icon(LucideIcons.clock, size: 11, color: ak.promoSub),
                const SizedBox(width: 4),
                Text(
                  deadline!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ak.promoSub,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Icon(LucideIcons.arrowRight, size: 14, color: ak.promoTitle),
            ],
          ),
        ],
      ),
    );
  }
}
