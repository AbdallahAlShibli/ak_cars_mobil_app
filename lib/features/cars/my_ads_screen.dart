import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/sand_widgets.dart';
import '../../core/widgets/widgets.dart';
import '../../state/app_state.dart';
import '../../data/models/models.dart';
import 'listing_card.dart';

/// The user's own published car ads (`myAdsProvider`) — the profile hub used
/// to point "My car ads" at the whole market, which showed everyone's ads.
class MyAdsScreen extends ConsumerWidget {
  const MyAdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final ads = ref.watch(myAdsProvider);

    return Scaffold(
      backgroundColor: ak.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SandHeader(
                s.t('إعلاناتي', 'My car ads'),
                trailing: ads.isEmpty ? null : StatusBadge('${ads.length}'),
              ),
            ),
            Expanded(
              child: ads.isEmpty
                  ? _EmptyState(ak: ak, s: s)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 90),
                      itemCount: ads.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final ad = ads[i];
                        return Entrance(
                          delayMs: 40 * i,
                          child: Stack(
                            children: [
                              ListingCard(listing: ad),
                              PositionedDirectional(
                                top: 2,
                                end: 2,
                                child: IconButton(
                                  tooltip: s.t('حذف الإعلان', 'Delete ad'),
                                  icon: Icon(LucideIcons.trash2,
                                      size: 19, color: ak.danger),
                                  onPressed: () =>
                                      _confirmDelete(context, ref, ad.id,
                                          ad.displayTitle),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!ensureRegistered(context, ref)) return;
          context.push('/post-ad');
        },
        backgroundColor: ak.primary,
        icon: Icon(LucideIcons.plus, color: ak.onPrimary),
        label: Text(
          s.t('أضف إعلاناً', 'Post an ad'),
          style: TextStyle(color: ak.onPrimary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
    String title,
  ) async {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.t('حذف الإعلان؟', 'Delete ad?')),
        content: Text(s.t('سيتم حذف "$title" من المعرض.',
            '"$title" will be removed from the gallery.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ak.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      HapticFeedback.mediumImpact();
      ref.read(myAdsProvider.notifier).remove(id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.ak, required this.s});

  final AkColors ak;
  final S s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(LucideIcons.megaphone,
                size: 64,
                radius: 22,
                background: ak.surfaceDim,
                foreground: ak.inkFaint),
            const SizedBox(height: 12),
            Text(
              s.t('لم تنشر أي إعلان بعد', 'You have not posted any ads yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              s.t('انشر سيارتك ليراها آلاف المشترين في عُمان.',
                  'List your car so thousands of buyers in Oman can see it.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: ak.inkSub, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
