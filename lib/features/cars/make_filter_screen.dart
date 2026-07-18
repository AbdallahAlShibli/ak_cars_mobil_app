import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/car_catalog.dart';

/// Make drill-in — choose model (searchable tiles) and year range,
/// then jump to results. Mirrors the reference marketplace flow.
class MakeFilterScreen extends StatefulWidget {
  const MakeFilterScreen({super.key, required this.makeName});

  final String makeName;

  @override
  State<MakeFilterScreen> createState() => _MakeFilterScreenState();
}

class _MakeFilterScreenState extends State<MakeFilterScreen> {
  final _search = TextEditingController();
  String? _model;
  int? _fromYear;
  int? _toYear;

  CarMake get _make => CarCatalog.makes.firstWhere(
        (m) => m.name == widget.makeName,
        orElse: () => CarCatalog.makes.first,
      );

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
    return Scaffold(
      appBar: AppBar(title: Text(_make.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  const Text('Choose model',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search…',
                      prefixIcon: Icon(Icons.search_rounded),
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
                                  Icons.directions_car_filled_rounded,
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
                  const Text('Choose year',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _fromYear,
                          hint: const Text('From'),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                                Icons.calendar_today_outlined,
                                size: 17),
                          ),
                          items: [
                            for (final y in CarCatalog.years)
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
                          hint: const Text('To'),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                                Icons.calendar_today_outlined,
                                size: 17),
                          ),
                          items: [
                            for (final y in CarCatalog.years)
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
                    ? 'All ${_make.name} results'
                    : 'Show $_model results'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
