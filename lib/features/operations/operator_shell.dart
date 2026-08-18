import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// One tab of an operator panel.
class OperatorTab {
  const OperatorTab({required this.label, required this.builder});

  final String label;
  final WidgetBuilder builder;
}

/// The shell both operator panels wear.
///
/// Shared so the workshop's three tabs and the founder's five sit at the same
/// height, in the same type, with the same underline — §5 asks for one tab
/// mechanism across the two screens, and two hand-rolled `TabBar`s drift apart
/// the first time either is touched.
///
/// Deliberately plain. These are internal tools ("وظيفتها التشغيل لا الإبهار"),
/// and a tab bar that draws attention to itself is competing with the queue
/// underneath it, which is the only thing anyone opens these screens for.
class OperatorShell extends StatelessWidget {
  const OperatorShell({
    super.key,
    required this.title,
    required this.tabs,
    this.banner,
    this.actions,
  });

  final String title;
  final List<OperatorTab> tabs;

  /// Shown under the tab bar, above every tab. Used for the standing "this is
  /// not your workshop" and "money moves outside the app" notices, which have
  /// to be true on whichever tab you happen to be looking at.
  final Widget? banner;

  /// `AppBar.actions` — e.g. the workshop panel's link into the newer
  /// `/workshop/dashboard` for accounts that actually own the workshop.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: actions,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Column(
              children: [
                TabBar(
                  isScrollable: tabs.length > 3,
                  tabAlignment: tabs.length > 3
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  labelStyle: context.text.labelStrong,
                  unselectedLabelStyle: context.text.bodySecondary,
                  labelColor: ak.ink,
                  unselectedLabelColor: ak.inkSub,
                  indicatorColor: ak.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: [for (final tab in tabs) Tab(text: tab.label)],
                ),
                Divider(height: 1, color: ak.divider),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (banner != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    AppSpacing.md,
                    AppSpacing.screenMargin,
                    0,
                  ),
                  child: banner,
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final tab in tabs) Builder(builder: tab.builder),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The standing notice every money surface in the pilot carries.
///
/// Phase 1 moves no money: the founder makes bank transfers by hand and the
/// app records that they happened. A figure on either panel that did not say so
/// would read as a balance the platform is holding and settling, which is a
/// claim neither screen can support.
class OffAppTransferNotice extends StatelessWidget {
  const OffAppTransferNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: ak.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ak.border),
      ),
      child: Text(
        message,
        style: context.text.bodySecondary.copyWith(fontSize: 11, height: 1.6),
      ),
    );
  }
}

/// A labelled figure on an operator panel.
///
/// Kept beside [OperatorShell] rather than in `core/widgets` because it is
/// specific to these two screens: the number leads at [AppTypographyX.price]
/// weight and the label follows underneath, which is the ranking §2 asks for
/// wherever an amount is the content of a card.
class OperatorFigure extends StatelessWidget {
  const OperatorFigure({
    super.key,
    required this.value,
    required this.label,
    this.hint,
    this.tone,
  });

  final Widget value;
  final String label;

  /// A third line, for the thing the number does not say on its own — what a
  /// rate is out of, or what window a total covers.
  final String? hint;

  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: ak.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ak.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DefaultTextStyle.merge(
            style: context.text.price.copyWith(color: tone),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: value,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: context.text.bodySecondary),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              hint!,
              style: context.text.bodySecondary.copyWith(
                fontSize: 11,
                color: ak.inkSub,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
