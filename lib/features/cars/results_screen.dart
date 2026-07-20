import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_state.dart';
import '../../data/gallery_data.dart';
import 'cars_filter_screen.dart';
import 'listing_card.dart';

/// Results — trim chips, sort bottom sheet, editable filters (the tune
/// button opens [CarsFilterSheet] seeded with the current criteria).
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({
    super.key,
    this.make,
    this.model,
    this.fromYear,
    this.toYear,
  });

  final String? make;
  final String? model;
  final int? fromYear;
  final int? toYear;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late CarsFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = CarsFilter(
      make: widget.make,
      model: widget.model,
      fromYear: widget.fromYear,
      toYear: widget.toYear,
    );
  }

  List<GalleryListing> _results(List<GalleryListing> feed) =>
      _filter.apply(feed);

  /// Trim quick-chips reflect the filter's Sub-Model facet. Options are
  /// derived ignoring the trim constraint itself (so picking one never
  /// collapses the list).
  List<String> _trims(List<GalleryListing> feed) {
    final model = _filter.model;
    if (model != null) {
      final known = GalleryData.trimsFor(model);
      if (known.isNotEmpty) return ['All', ...known];
    }
    final base = _filter.copyWith(trims: const {});
    final seen = <String>{};
    for (final l in feed.where(base.matches)) {
      if (l.trim.isNotEmpty) seen.add(l.trim);
    }
    return ['All', ...(seen.toList()..sort())];
  }

  Future<void> _openFilters() async {
    HapticFeedback.selectionClick();
    final result = await Navigator.of(context).push<CarsFilter>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CarsFilterScreen(initial: _filter),
      ),
    );
    if (result != null) {
      setState(() => _filter = result);
    }
  }

  Future<void> _openSort() async {
    HapticFeedback.selectionClick();
    final ak = AkColors.of(context);
    final s = S.of(context);
    final sort = await showModalBottomSheet<GallerySort>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('الترتيب حسب', 'Sort by'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final sort in GallerySort.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, sort),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: ak.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _filter.sort == sort
                              ? ak.ink
                              : ak.border,
                          width: _filter.sort == sort ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _filter.sort == sort
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 19,
                            color: _filter.sort == sort
                                ? ak.ink
                                : ak.inkFaint,
                          ),
                          const SizedBox(width: 10),
                          Text(_sortLabel(s, sort),
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (sort != null) {
      setState(() => _filter = _filter.copyWith(sort: sort));
    }
  }

  String _sortLabel(S s, GallerySort sort) => switch (sort) {
        GallerySort.newest => s.t('الأحدث', 'Newest'),
        GallerySort.oldest => s.t('الأقدم', 'Oldest'),
        GallerySort.priceLowHigh =>
          s.t('السعر: الأقل أولاً', 'Price: low to high'),
        GallerySort.priceHighLow =>
          s.t('السعر: الأعلى أولاً', 'Price: high to low'),
      };

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final feed = ref.watch(galleryFeedProvider);
    final results = _results(feed);
    final trims = _trims(feed);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('النتائج', 'Results')),
        actions: [
          IconButton(
            onPressed: _openSort,
            icon: const Icon(Icons.sort_rounded),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Badge(
              isLabelVisible: _filter.activeCount > 0,
              label: Text('${_filter.activeCount}'),
              child: IconButton(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trims.length > 1)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final t in trims) ...[
                      SelectChip(
                        label: t == 'All' ? s.t('الكل', 'All') : t,
                        selected: t == 'All'
                            ? _filter.trims.isEmpty
                            : _filter.trims.length == 1 &&
                                _filter.trims.contains(t),
                        onTap: () => setState(() => _filter = _filter.copyWith(
                            trims: t == 'All' ? const {} : {t})),
                      ),
                      const SizedBox(width: 7),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                child: results.isEmpty
                    ? Center(
                        key: const ValueKey('empty'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 40, color: ak.inkFaint),
                            const SizedBox(height: 8),
                            Text(
                                s.t('لا سيارات تطابق هذه الفلاتر',
                                    'No cars match these filters'),
                                style: TextStyle(
                                    fontSize: 13, color: ak.inkSub)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        key: ValueKey('${_filter.trims.join()}-${_filter.sort}'),
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) => Entrance(
                          delayMs: 35 * i,
                          child: ListingCard(listing: results[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
