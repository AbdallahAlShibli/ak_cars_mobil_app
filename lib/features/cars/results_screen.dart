import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/gallery_data.dart';
import 'listing_card.dart';

/// Results — trim chips, sort bottom sheet, active-filter badge.
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
  String _trim = 'All';
  GallerySort _sort = GallerySort.newest;

  int get _activeFilters {
    var n = 0;
    if (widget.make != null) n++;
    if (widget.model != null) n++;
    if (widget.fromYear != null || widget.toYear != null) n++;
    return n;
  }

  List<GalleryListing> get _results {
    final list = GalleryData.listings.where((l) {
      if (widget.make != null && l.make != widget.make) return false;
      if (widget.model != null && l.model != widget.model) return false;
      if (widget.fromYear != null && l.year < widget.fromYear!) return false;
      if (widget.toYear != null && l.year > widget.toYear!) return false;
      if (_trim != 'All' && l.trim != _trim) return false;
      return true;
    }).toList();

    list.sort((a, b) => switch (_sort) {
          GallerySort.newest =>
            a.postedMinutesAgo.compareTo(b.postedMinutesAgo),
          GallerySort.oldest =>
            b.postedMinutesAgo.compareTo(a.postedMinutesAgo),
          GallerySort.priceLowHigh => (a.price ?? double.infinity)
              .compareTo(b.price ?? double.infinity),
          GallerySort.priceHighLow =>
            (b.price ?? -1).compareTo(a.price ?? -1),
        });
    return list;
  }

  List<String> get _trims {
    if (widget.model != null) {
      final known = GalleryData.trimsFor(widget.model!);
      if (known.isNotEmpty) return ['All', ...known];
    }
    final seen = <String>{};
    for (final l in _resultsUnfiltered) {
      if (l.trim.isNotEmpty) seen.add(l.trim);
    }
    return ['All', ...seen];
  }

  List<GalleryListing> get _resultsUnfiltered =>
      GalleryData.listings.where((l) {
        if (widget.make != null && l.make != widget.make) return false;
        if (widget.model != null && l.model != widget.model) return false;
        return true;
      }).toList();

  Future<void> _openSort() async {
    HapticFeedback.selectionClick();
    final sort = await showModalBottomSheet<GallerySort>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sort by',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final s in GallerySort.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _sort == s
                              ? AppColors.brand
                              : AppColors.border,
                          width: _sort == s ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _sort == s
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 19,
                            color: _sort == s
                                ? AppColors.brand
                                : AppColors.ink3,
                          ),
                          const SizedBox(width: 10),
                          Text(s.label,
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
    if (sort != null) setState(() => _sort = sort);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          IconButton(
            onPressed: _openSort,
            icon: const Icon(Icons.sort_rounded),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Badge(
              isLabelVisible: _activeFilters > 0,
              label: Text('$_activeFilters'),
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
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
            if (_trims.length > 1)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final t in _trims) ...[
                      SelectChip(
                        label: t,
                        selected: _trim == t,
                        onTap: () => setState(() => _trim = t),
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
                    ? const Center(
                        key: ValueKey('empty'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 40, color: AppColors.ink3),
                            SizedBox(height: 8),
                            Text('No cars match these filters',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.ink2)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        key: ValueKey('$_trim-$_sort'),
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
