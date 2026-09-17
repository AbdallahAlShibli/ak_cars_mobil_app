import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/guid.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../di/providers.dart';
import '../../../state/job_workspace_state.dart';
import '../../services/job_media_widgets.dart';
import '../../services/job_report_widgets.dart';
import 'extra_work_tab.dart';
import 'job_workspace_common.dart';

typedef _Draft = ({String key, InspectionItem item});

/// The digital inspection: a list of checked items, each good / needs
/// attention / urgent, with a note and photos. The customer reads it in their
/// booking. Saved as a whole; items the server already knows keep their ids.
class InspectionTab extends ConsumerStatefulWidget {
  const InspectionTab({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final ServiceRequest request;
  final JobRequestChanged onChanged;

  @override
  ConsumerState<InspectionTab> createState() => _InspectionTabState();
}

class _InspectionTabState extends ConsumerState<InspectionTab>
    with AutomaticKeepAliveClientMixin {
  static const _maxPhotos = 3;

  late List<_Draft> _items;
  bool _dirty = false;
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _items = _draftsFrom(widget.request.inspection);
  }

  static List<_Draft> _draftsFrom(List<InspectionItem> items) => [
    for (final item in items) (key: item.id ?? newGuid(), item: item),
  ];

  void _update(String key, InspectionItem item) => setState(() {
    _dirty = true;
    _items = [
      for (final d in _items) d.key == key ? (key: key, item: item) : d,
    ];
  });

  void _remove(String key) => setState(() {
    _dirty = true;
    _items = [
      for (final d in _items)
        if (d.key != key) d,
    ];
  });

  void _addNames(Iterable<String> names) => setState(() {
    final existing = {for (final d in _items) d.item.name.toLowerCase()};
    final added = [
      for (final name in names)
        if (!existing.contains(name.toLowerCase()))
          (key: newGuid(), item: InspectionItem(name: name)),
    ];
    if (added.isEmpty) return;
    _dirty = true;
    _items = [..._items, ...added];
  });

  Future<void> _addOne() async {
    final s = S.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => JobTextDialog(
        title: s.t('بند فحص جديد', 'New inspection item'),
        label: s.t('ما الذي فُحص؟', 'What was checked?'),
        confirmLabel: s.t('إضافة', 'Add'),
        mustFill: true,
      ),
    );
    if (name != null && name.isNotEmpty) _addNames([name]);
  }

  List<String> _standard(S s) => [
    s.t('الفرامل', 'Brakes'),
    s.t('الإطارات', 'Tyres'),
    s.t('البطارية', 'Battery'),
    s.t('الزيت والسوائل', 'Oil & fluids'),
    s.t('الأضواء', 'Lights'),
    s.t('المساحات', 'Wipers'),
    s.t('نظام التعليق', 'Suspension'),
    s.t('المكيّف', 'Air conditioning'),
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await runJobAction(context, () async {
      final saved = await ref
          .read(jobWorkspaceServiceProvider)
          .replaceInspection(widget.request.id, [
            for (final d in _items) d.item,
          ]);
      if (mounted) {
        setState(() {
          _items = _draftsFrom(saved);
          _dirty = false;
        });
      }
      widget.onChanged(widget.request.copyWith(inspection: saved));
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      final s = S.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('حُفظ الفحص', 'Inspection saved'))),
      );
    }
  }

  Future<void> _raiseExtraWork(InspectionItem item) async {
    final created = await showExtraWorkSheet(
      context,
      request: widget.request,
      fromItem: item,
    );
    if (created == null || !mounted) return;
    widget.onChanged(
      widget.request.copyWith(
        extraWork: [created, ...widget.request.extraWork],
      ),
    );
    DefaultTabController.maybeOf(context)?.animateTo(2);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final editable = JobStages.work.contains(widget.request.escrow);

    return ListView(
      padding: jobTabPadding,
      children: [
        if (!editable) ...[
          StageNotice(
            s.t(
              'يُعدَّل الفحص بعد قبول الطلب وأثناء العمل فقط.',
              'The inspection can be edited once the job is accepted and while it is in progress.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          s.t(
            'يرى العميل هذا التقرير في حجزه — الصور تبني الثقة.',
            'The customer sees this report in their booking — photos build trust.',
          ),
          style: context.text.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.md),
        if (editable)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => _addNames(_standard(s)),
                icon: const Icon(LucideIcons.listChecks, size: 17),
                label: Text(s.t('القائمة الأساسية', 'Standard checklist')),
              ),
              OutlinedButton.icon(
                onPressed: _addOne,
                icon: const Icon(LucideIcons.plus, size: 17),
                label: Text(s.t('بند', 'Item')),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        if (_items.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.clipboardList,
            message: s.t(
              'لا بنود فحص بعد.',
              'No inspection items yet.',
            ),
          )
        else
          for (final (i, draft) in _items.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _ItemEditor(
              key: ValueKey(draft.key),
              item: draft.item,
              editable: editable,
              maxPhotos: _maxPhotos,
              onChanged: (item) => _update(draft.key, item),
              onRemove: () => _remove(draft.key),
              onRaiseExtraWork:
                  editable &&
                      !_dirty &&
                      draft.item.id != null &&
                      draft.item.status != InspectionStatus.good
                  ? () => _raiseExtraWork(draft.item)
                  : null,
            ),
          ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: editable && _dirty && !_saving ? _save : null,
          icon: BusyIcon(icon: LucideIcons.save, busy: _saving),
          label: Text(s.t('حفظ الفحص', 'Save inspection')),
        ),
      ],
    );
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    super.key,
    required this.item,
    required this.editable,
    required this.maxPhotos,
    required this.onChanged,
    required this.onRemove,
    required this.onRaiseExtraWork,
  });

  final InspectionItem item;
  final bool editable;
  final int maxPhotos;
  final ValueChanged<InspectionItem> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onRaiseExtraWork;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.name, style: context.text.cardTitle)),
              if (editable)
                IconButton(
                  tooltip: s.t('حذف', 'Remove'),
                  onPressed: onRemove,
                  icon: const Icon(LucideIcons.trash2, size: 18),
                ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final status in InspectionStatus.values)
                ChoiceChip(
                  label: Text(status.label.of(s)),
                  selected: item.status == status,
                  selectedColor: InspectionReportCard.toneFor(
                    context,
                    status,
                  ).withValues(alpha: 0.18),
                  onSelected: editable
                      ? (_) => onChanged(item.copyWith(status: status))
                      : null,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: item.note,
            enabled: editable,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(labelText: s.t('ملاحظة', 'Note')),
            onChanged: (note) => onChanged(item.copyWith(note: note)),
          ),
          const SizedBox(height: AppSpacing.sm),
          JobPhotoPicker(
            photos: item.photos,
            max: maxPhotos,
            enabled: editable,
            onChanged: (photos) => onChanged(item.copyWith(photos: photos)),
          ),
          if (onRaiseExtraWork != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onRaiseExtraWork,
                icon: const Icon(LucideIcons.wrench, size: 16),
                label: Text(s.t('اطلب عملاً إضافياً', 'Request extra work')),
              ),
            ),
        ],
      ),
    );
  }
}
