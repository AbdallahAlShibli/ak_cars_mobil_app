import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_flags.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../di/providers.dart';
import '../../state/app_state.dart';

/// Search across services, parts and cars — what the home pill's hint
/// ("ابحث عن خدمة، قطعة، أو سيارة…" / "Search services, parts, cars…") has
/// always promised. Until now that pill was decorative: tapping it went to
/// `/services` and nothing was ever searched.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery;

  /// Sections start capped; each can be expanded in place rather than
  /// handing the query off to another screen that would drop it.
  final Set<String> _expanded = {};

  static const _preview = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) => setState(() => _query = value);

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final results = ref.watch(searchResultsProvider(_query));
    final asked = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(
        backgroundColor: ak.bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsetsDirectional.only(end: 16),
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _controller,
              autofocus: widget.initialQuery.isEmpty,
              textInputAction: TextInputAction.search,
              onChanged: _setQuery,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: ak.surface,
                hintText: s.searchHint,
                hintStyle: TextStyle(fontSize: 12.5, color: ak.inkFaint),
                prefixIcon:
                    Icon(LucideIcons.search, size: 19, color: ak.inkSub),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(LucideIcons.x,
                            size: 17, color: ak.inkSub),
                        onPressed: () {
                          _controller.clear();
                          _setQuery('');
                        },
                      ),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: ak.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: ak.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: ak.ink, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: !asked
            ? _suggestions(s, ak)
            : results.isEmpty
                ? _noResults(s, ak)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Text(
                        s.resultsCount(results.total),
                        style: TextStyle(fontSize: 12, color: ak.inkSub),
                      ),
                      const SizedBox(height: 14),
                      if (results.services.isNotEmpty)
                        _section(
                          id: 'services',
                          title: s.t('الخدمات', 'Services'),
                          count: results.services.length,
                          s: s,
                          ak: ak,
                          rows: [
                            for (final o in results.services)
                              _ResultRow(
                                icon: LucideIcons.wrench,
                                title: o.name.of(s),
                                subtitle: o.provider.name.of(s),
                                trailing: o.price == null
                                    ? s.t('عرض سعر', 'Quote')
                                    : 'OMR ${o.price!.toStringAsFixed(2)}',
                                onTap: () => context.push('/service/${o.id}'),
                              ),
                          ],
                        ),
                      if (results.parts.isNotEmpty)
                        _section(
                          id: 'parts',
                          title: s.t('قطع الغيار', 'Parts'),
                          count: results.parts.length,
                          s: s,
                          ak: ak,
                          rows: [
                            for (final p in results.parts)
                              _ResultRow(
                                icon: p.icon,
                                title: p.name.of(s),
                                subtitle: [
                                  if (p.brand != null) p.brand!.of(s),
                                  if (p.partNumber != null) p.partNumber!,
                                ].join(' · '),
                                trailing:
                                    'OMR ${p.price.toStringAsFixed(2)}',
                                onTap: () =>
                                    context.push('/shop/product/${p.id}'),
                              ),
                          ],
                        ),
                      if (results.cars.isNotEmpty)
                        _section(
                          id: 'cars',
                          title: s.t('السيارات', 'Cars'),
                          count: results.cars.length,
                          s: s,
                          ak: ak,
                          rows: [
                            for (final l in results.cars)
                              _ResultRow(
                                icon: l.icon,
                                title: l.displayTitle,
                                subtitle: ref
                                    .watch(locationCatalogProvider)
                                    .localizedRegion(l.region, s.isAr),
                                trailing: l.price == null
                                    ? s.t('عند الطلب', 'Ask')
                                    : 'OMR ${l.price!.toStringAsFixed(0)}',
                                onTap: () =>
                                    context.push('/cars/listing/${l.id}'),
                              ),
                          ],
                        ),
                    ],
                  ),
      ),
    );
  }

  /// A capped section with an in-place "show all N" toggle.
  Widget _section({
    required String id,
    required String title,
    required int count,
    required S s,
    required AkColors ak,
    required List<Widget> rows,
  }) {
    final open = _expanded.contains(id);
    final visible = open ? rows : rows.take(_preview).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('$title · $count'),
          const SizedBox(height: 8),
          for (final row in visible) ...[
            row,
            const SizedBox(height: 8),
          ],
          if (rows.length > _preview)
            GestureDetector(
              onTap: () => setState(
                  () => open ? _expanded.remove(id) : _expanded.add(id)),
              child: Text(
                open
                    ? s.t('عرض أقل', 'Show less')
                    : s.t('عرض الكل (${rows.length})',
                        'Show all (${rows.length})'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ak.ink),
              ),
            ),
        ],
      ),
    );
  }

  /// Empty-query state. The chips are read off the real catalogues rather
  /// than being a hand-written list of "popular searches" nobody measured.
  Widget _suggestions(S s, AkColors ak) {
    // Suggestions follow the saved car: an EV owner's first four service
    // chips are their own services, and their parts chips lead with charging.
    // Both lists are still read off the real catalogues — the order changes,
    // nothing is invented.
    final powertrain = ref.watch(primaryPowertrainProvider);
    final categories = ref
        .watch(serviceMarketplaceRepositoryProvider)
        .categoriesFor(powertrain)
        .take(4);
    final partEntries = ref.watch(partCategoriesProvider).entries.toList();
    if (powertrain?.plugsIn ?? false) {
      partEntries.sort((a, b) => a.key == 'charging'
          ? -1
          : b.key == 'charging'
              ? 1
              : 0);
    }
    final parts = partEntries.take(3);
    final makes = ref.watch(vehicleCatalogProvider).makes.take(4);

    Widget group(String title, List<Widget> chips) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 9),
              Wrap(spacing: 7, runSpacing: 7, children: chips),
            ],
          ),
        );

    Widget chip(String label) => SelectChip(
          label: label,
          selected: false,
          onTap: () {
            _controller.text = label;
            _controller.selection =
                TextSelection.collapsed(offset: label.length);
            _setQuery(label);
          },
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          // The blurb names only what this build can actually return, so it
          // cannot promise a catalogue the search does not search.
          AppFlags.partsStoreEnabled || AppFlags.carMarketplaceEnabled
              ? s.t('ابحث في الخدمات وقطع الغيار وإعلانات السيارات.',
                  'Search across services, parts and car ads.')
              : s.t('ابحث في الخدمات والورش.',
                  'Search across services and workshops.'),
          style: TextStyle(fontSize: 12.5, color: ak.inkSub),
        ),
        const SizedBox(height: 18),
        group(s.t('خدمات', 'Services'), [
          for (final c in categories) chip(c.name.of(s).replaceAll('\n', ' ')),
        ]),
        if (AppFlags.partsStoreEnabled)
          group(s.t('قطع الغيار', 'Parts'), [
            for (final e in parts) chip(e.value.of(s)),
          ]),
        if (AppFlags.carMarketplaceEnabled)
          group(s.t('ماركات', 'Makes'), [
            for (final m in makes) chip(m.name),
          ]),
      ],
    );
  }

  Widget _noResults(S s, AkColors ak) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.searchX, size: 44, color: ak.inkFaint),
            const SizedBox(height: 12),
            Text(
              s.t('لا نتائج لـ "$_query"', 'Nothing found for "$_query"'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              s.t('جرّب اسم خدمة، أو رقم قطعة، أو ماركة سيارة.',
                  'Try a service name, a part number, or a car make.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: ak.inkSub, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// One search hit: icon, what it is, where it is, and what it costs.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          IconTile(icon, size: 38, radius: 12, foreground: ak.inkSub),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: ak.inkSub),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
