import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';
import '../../../di/providers.dart';
import '../../../state/job_workspace_state.dart';
import '../../../state/provider_dashboard_state.dart';
import '../../operations/operator_shell.dart';
import '../../services/job_media_widgets.dart';
import 'job_workspace_common.dart';

/// The workshop's own record of the labour and parts that went into the job,
/// and the margin on it. Never shown to the customer — it carries costs.
/// A part picked from stock is deducted from inventory, and returned when its
/// line is removed.
class JobCardTab extends ConsumerWidget {
  const JobCardTab({super.key, required this.request});

  final ServiceRequest request;

  void _reload(WidgetRef ref) {
    ref.invalidate(jobCardProvider(request.id));
    if (ref.exists(workshopInventoryProvider)) {
      ref.invalidate(workshopInventoryProvider);
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JobLineSheet(requestId: request.id),
    );
    if (added == true && context.mounted) _reload(ref);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    JobCardLine line,
  ) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('حذف البند؟', 'Remove this line?')),
        content: Text(
          line.inventoryItemId != null
              ? s.t('تعود القطعة إلى المخزون.', 'The part goes back into stock.')
              : s.t('يُحذف من بطاقة العمل.', 'It comes off the job card.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.t('تراجع', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.t('حذف', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await runJobAction(
      context,
      () => ref
          .read(jobWorkspaceServiceProvider)
          .deleteJobCardLine(request.id, line.id),
    );
    if (ok && context.mounted) _reload(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final card = ref.watch(jobCardProvider(request.id));
    final editable = JobStages.jobCard.contains(request.escrow);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(jobCardProvider(request.id).future),
      child: ListView(
        padding: jobTabPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            s.t(
              'خاصة بورشتك — لا يرى العميل هذه البطاقة ولا التكاليف.',
              'Internal to your workshop — the customer never sees this card or its costs.',
            ),
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          card.when(
            loading: () => const Column(
              children: [
                MetricSkeleton(count: 2),
                SizedBox(height: AppSpacing.md),
                Skeleton(height: 120),
              ],
            ),
            error: (error, _) => EmptyState(
              compact: true,
              icon: LucideIcons.circleAlert,
              message: jobWorkspaceErrorText(s, error),
            ),
            data: (data) => _body(context, ref, data, editable),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    JobCard card,
    bool editable,
  ) {
    final s = S.of(context);
    final ak = AkColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: RialAmount(card.labourRevenue),
                label: s.t('إيراد العمالة', 'Labour revenue'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: RialAmount(card.partsRevenue),
                label: s.t('إيراد القطع', 'Parts revenue'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.itemGap),
        Row(
          children: [
            Expanded(
              child: OperatorFigure(
                value: RialAmount(card.partsCost),
                label: s.t('تكلفة القطع', 'Parts cost'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OperatorFigure(
                value: RialAmount(card.grossProfit),
                label: s.t('إجمالي الربح', 'Gross profit'),
                tone: card.grossProfit < 0 ? ak.danger : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          s.t(
            'إجمالي الربح = الإيراد ناقص تكلفة القطع. الأجور غير محتسبة.',
            'Gross profit is revenue minus parts cost. Wages are not included.',
          ),
          style: context.text.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionHeader(
          s.t('البنود', 'Lines'),
          action: editable ? s.t('إضافة', 'Add') : null,
          onAction: editable ? () => _add(context, ref) : null,
        ),
        const SizedBox(height: AppSpacing.headingGap),
        if (card.lines.isEmpty)
          EmptyState(
            compact: true,
            icon: LucideIcons.clipboardList,
            message: editable
                ? s.t(
                    'أضف العمالة والقطع التي دخلت في هذا العمل.',
                    'Add the labour and parts that went into this job.',
                  )
                : s.t(
                    'لم تُسجَّل بنود على هذا العمل.',
                    'No lines were recorded on this job.',
                  ),
          )
        else
          for (final (i, line) in card.lines.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _LineTile(
              line: line,
              onDelete: editable ? () => _delete(context, ref, line) : null,
            ),
          ],
      ],
    );
  }
}

String _quantity(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.onDelete});

  final JobCardLine line;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconTile(
            line.kind == JobLineKind.labour
                ? LucideIcons.hammer
                : LucideIcons.package,
            size: 36,
            radius: 12,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.description.isEmpty
                      ? line.kind.label.of(s)
                      : line.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyPrimary,
                ),
                const SizedBox(height: 2),
                Text(
                  '${line.kind.label.of(s)} · ${_quantity(line.quantity)} × ${line.unitPrice.toStringAsFixed(2)}',
                  style: context.text.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          RialAmount(line.revenue, style: context.text.labelStrong),
          if (onDelete != null)
            IconButton(
              tooltip: s.t('حذف', 'Remove'),
              onPressed: onDelete,
              icon: const Icon(LucideIcons.trash2, size: 17),
            ),
        ],
      ),
    );
  }
}

class _JobLineSheet extends ConsumerStatefulWidget {
  const _JobLineSheet({required this.requestId});

  final String requestId;

  @override
  ConsumerState<_JobLineSheet> createState() => _JobLineSheetState();
}

class _JobLineSheetState extends ConsumerState<_JobLineSheet> {
  JobLineKind _kind = JobLineKind.labour;
  InventoryItem? _stockItem;
  String? _staffId;
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _cost = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _pickStock() async {
    final s = S.of(context);
    final picked = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _StockPicker(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _stockItem = picked;
      _description.text = picked.name.of(s);
      _price.text = picked.sellPrice.toStringAsFixed(2);
      _cost.text = picked.unitCost.toStringAsFixed(2);
    });
  }

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    final s = S.of(context);
    final quantity = parseJobNumber(_quantity.text);
    final priceText = _price.text.trim();
    final costText = _cost.text.trim();
    final price = priceText.isEmpty ? null : parseJobNumber(priceText);
    final cost = costText.isEmpty ? null : parseJobNumber(costText);
    final description = _description.text.trim();
    final isPart = _kind == JobLineKind.part;

    if (quantity == null || quantity <= 0) {
      _say(s.t('أدخل كمية أكبر من صفر.', 'Enter a quantity above zero.'));
      return;
    }
    if ((priceText.isNotEmpty && (price == null || price < 0)) ||
        (costText.isNotEmpty && (cost == null || cost < 0))) {
      _say(s.t('الأسعار يجب أن تكون صفراً أو أكثر.', 'Prices must be zero or more.'));
      return;
    }
    if (description.isEmpty && _stockItem == null) {
      _say(s.t('صف البند أو اختر قطعة من المخزون.', 'Describe the line or pick a part from stock.'));
      return;
    }
    if (_stockItem == null && price == null) {
      _say(s.t('أدخل سعر الوحدة.', 'Enter a unit price.'));
      return;
    }

    setState(() => _saving = true);
    final ok = await runJobAction(
      context,
      () => ref
          .read(jobWorkspaceServiceProvider)
          .addJobCardLine(
            widget.requestId,
            kind: _kind,
            description: description.isEmpty ? null : description,
            quantity: quantity,
            unitPrice: price,
            unitCost: isPart ? cost : null,
            inventoryItemId: isPart ? _stockItem?.id : null,
            staffId: isPart ? null : _staffId,
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final isPart = _kind == JobLineKind.part;
    final stock = _stockItem;
    final staff = [
      for (final m in ref.watch(workshopStaffProvider).valueOrNull ?? const <WorkshopStaff>[])
        if (m.isActive) m,
    ];
    const decimal = TextInputType.numberWithOptions(decimal: true);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.t('إضافة بند', 'Add a line'), style: context.text.cardTitle),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final kind in JobLineKind.values)
                    ChoiceChip(
                      label: Text(kind.label.of(s)),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() {
                        _kind = kind;
                        if (kind == JobLineKind.labour) _stockItem = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (isPart) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.package),
                  title: Text(
                    stock?.name.of(s) ?? s.t('ليست من المخزون', 'Not from stock'),
                  ),
                  subtitle: Text(
                    stock == null
                        ? s.t('اختر قطعة ليُخصم من المخزون', 'Pick a part to deduct it from stock')
                        : s.t('${stock.quantityOnHand} في المخزون', '${stock.quantityOnHand} in stock'),
                  ),
                  trailing: stock == null
                      ? Icon(DirectionalIcons.forwardChevron(context))
                      : IconButton(
                          tooltip: s.t('إلغاء الاختيار', 'Clear'),
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () => setState(() => _stockItem = null),
                        ),
                  onTap: _pickStock,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (!isPart && staff.isNotEmpty) ...[
                Text(
                  s.t('الفني (اختياري)', 'Technician (optional)'),
                  style: TextStyle(fontSize: 12, color: ak.inkSub),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final member in staff)
                      ChoiceChip(
                        label: Text(member.name),
                        selected: _staffId == member.id,
                        onSelected: (on) =>
                            setState(() => _staffId = on ? member.id : null),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(
                controller: _description,
                decoration: InputDecoration(labelText: s.t('الوصف', 'Description')),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      keyboardType: decimal,
                      decoration: InputDecoration(
                        labelText: isPart
                            ? s.t('الكمية', 'Quantity')
                            : s.t('الساعات', 'Hours'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: decimal,
                      decoration: InputDecoration(
                        labelText: s.t('سعر الوحدة (ر.ع)', 'Unit price (OMR)'),
                      ),
                    ),
                  ),
                ],
              ),
              if (isPart) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _cost,
                  keyboardType: decimal,
                  decoration: InputDecoration(
                    labelText: s.t('تكلفة الوحدة (ر.ع)', 'Unit cost (OMR)'),
                    helperText: s.t('خاصة — لحساب ربحك', 'Private — used for your margin'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: BusyIcon(icon: LucideIcons.plus, busy: _saving),
                label: Text(s.t('إضافة البند', 'Add line')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockPicker extends ConsumerWidget {
  const _StockPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final inventory = ref.watch(workshopInventoryProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: inventory.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.screenMargin),
            child: Skeleton(height: 120),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: EmptyState(
              compact: true,
              icon: LucideIcons.circleAlert,
              message: jobWorkspaceErrorText(s, error),
            ),
          ),
          data: (items) {
            final active = [
              for (final item in items)
                if (item.isActive) item,
            ];
            if (active.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                child: EmptyState(
                  compact: true,
                  icon: LucideIcons.package,
                  message: s.t('لا قطع في المخزون.', 'No parts in stock.'),
                ),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final item in active)
                  ListTile(
                    enabled: item.quantityOnHand > 0,
                    title: Text(item.name.of(s)),
                    subtitle: Text(
                      s.t(
                        '${item.quantityOnHand} في المخزون · ${item.sellPrice.toStringAsFixed(2)} ر.ع',
                        '${item.quantityOnHand} in stock · OMR ${item.sellPrice.toStringAsFixed(2)}',
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(item),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
