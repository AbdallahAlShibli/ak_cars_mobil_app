import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../state/catalog_state.dart';

/// Make drill-in — choose model (searchable tiles) and year range,
/// then jump to results. Mirrors the reference marketplace flow.
class MakeFilterScreen extends ConsumerStatefulWidget {
  const MakeFilterScreen({super.key, required this.makeName});

  final String makeName;

  @override
  ConsumerState<MakeFilterScreen> createState() => _MakeFilterScreenState();
}

class _MakeFilterScreenState extends ConsumerState<MakeFilterScreen> {
  final _search = TextEditingController();
  String? _model;
  int? _fromYear;
  int? _toYear;

  VehicleCatalog get _catalog => ref.read(vehicleCatalogProvider);

  CarMake get _make =>
      _catalog.makeNamed(widget.makeName) ??
      (_catalog.makes.isEmpty
          ? const CarMake('', [])
          : _catalog.makes.first);

  List<String> get _models {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _make.models;
    return _make.models.where((m) => m.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showResults() {
    final params = <String>[
      'make=${Uri.encodeComponent(_make.name)}',
      if (_model != null) 'model=${Uri.encodeComponent(_model!)}',
      if (_fromYear != null) 'from=$_fromYear',
      if (_toYear != null) 'to=$_toYear',
    ].join('&');
    context.push('/cars/results?$params');
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_make.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  Text(s.t('اختر الموديل', 'Choose model'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: s.t('ابحث…', 'Search…'),
                      prefixIcon: const Icon(LucideIcons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 9,
                      crossAxisSpacing: 9,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: _models.length,
                    itemBuilder: (context, i) {
                      final model = _models[i];
                      final selected = _model == model;
                      return Entrance(
                        delayMs: 25 * i,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() =>
                                _model = selected ? null : model);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? AppColors.brand
                                    : AppColors.border,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.carFront,
                                  size: 30,
                                  color: selected
                                      ? AppColors.brand
                                      : AppColors.ink3,
                                ),
                                const SizedBox(height: 7),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: Text(
                                    model,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Text(s.t('اختر السنة', 'Choose year'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _fromYear,
                          hint: Text(s.t('من', 'From')),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                                LucideIcons.calendar,
                                size: 17),
                          ),
                          items: [
                            for (final y in _catalog.years)
                              if (_toYear == null || y <= _toYear!)
                                DropdownMenuItem(
                                    value: y, child: Text('$y')),
                          ],
                          onChanged: (v) => setState(() {
                            _fromYear = v;
                            if (v != null &&
                                _toYear != null &&
                                _toYear! < v) {
                              _toYear = v;
                            }
                          }),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('—',
                            style: TextStyle(color: AppColors.ink3)),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _toYear,
                          hint: Text(s.t('إلى', 'To')),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                                LucideIcons.calendar,
                                size: 17),
                          ),
                          items: [
                            for (final y in _catalog.years)
                              if (_fromYear == null || y >= _fromYear!)
                                DropdownMenuItem(
                                    value: y, child: Text('$y')),
                          ],
                          onChanged: (v) => setState(() => _toYear = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                onPressed: _showResults,
                child: Text(_model == null
                    ? s.t('كل نتائج ${_make.name}',
                        'All ${_make.name} results')
                    : s.t('عرض نتائج $_model', 'Show $_model results')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
