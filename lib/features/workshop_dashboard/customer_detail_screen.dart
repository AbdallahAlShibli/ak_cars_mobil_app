import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/widgets.dart';
import '../../state/provider_dashboard_state.dart';
import '../operations/escrow_action_bar.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ak = AkColors.of(context);
    final s = S.of(context);
    final detail = ref.watch(workshopCustomerDetailProvider(userId));

    return Scaffold(
      backgroundColor: ak.bg,
      appBar: AppBar(title: Text(s.t('العميل', 'Customer'))),
      body: SafeArea(
        child: detail.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            children: const [ListSkeleton()],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            children: [
              EmptyState(
                icon: LucideIcons.circleAlert,
                message: s.t(
                  'تعذّر تحميل بيانات العميل.',
                  'Couldn\'t load this customer.',
                ),
                action: FilledButton(
                  onPressed: () => ref
                      .read(workshopCustomerDetailProvider(userId).notifier)
                      .refresh(),
                  child: Text(s.t('إعادة المحاولة', 'Retry')),
                ),
              ),
            ],
          ),
          data: (data) {
            final customer = data.customer;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.t(
                    '${customer.bookingsCount} حجوزات · ${customer.carCount} سيارات',
                    '${customer.bookingsCount} bookings · ${customer.carCount} cars',
                  ),
                  style: TextStyle(fontSize: 12.5, color: ak.inkSub),
                ),
                const SizedBox(height: AppSpacing.md),
                if (customer.phone != null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Contact.call(context, customer.phone!),
                          icon: const Icon(LucideIcons.phone, size: 15),
                          label: Text(customer.phone!),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: () =>
                            Contact.whatsapp(context, customer.phone!),
                        child: const Icon(LucideIcons.messageCircle, size: 15),
                      ),
                    ],
                  )
                else
                  Text(
                    s.t(
                      'يتوفر التواصل المباشر بعد أن تُحجز الأموال في الضمان.',
                      'Direct contact unlocks once funds are held in escrow.',
                    ),
                    style: TextStyle(fontSize: 11.5, color: ak.inkFaint),
                  ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(s.t('الحجوزات', 'Bookings')),
                const SizedBox(height: AppSpacing.sm),
                if (data.bookings.isEmpty)
                  EmptyState(
                    icon: LucideIcons.clipboardList,
                    message: s.t('لا حجوزات بعد.', 'No bookings yet.'),
                    compact: true,
                  )
                else
                  for (final booking in data.bookings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        child: OperatorRequestHeader(request: booking),
                      ),
                    ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(s.t('الملاحظات', 'Notes')),
                const SizedBox(height: AppSpacing.sm),
                for (final note in data.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: AppCard(
                      color: ak.surfaceDim,
                      child: Text(
                        note.body,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                _AddNoteField(userId: userId),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AddNoteField extends ConsumerStatefulWidget {
  const _AddNoteField({required this.userId});

  final String userId;

  @override
  ConsumerState<_AddNoteField> createState() => _AddNoteFieldState();
}

class _AddNoteFieldState extends ConsumerState<_AddNoteField> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(workshopCustomerDetailProvider(widget.userId).notifier)
          .addNote(_controller.text.trim());
      _controller.clear();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: s.t('أضف ملاحظة', 'Add a note'),
            ),
          ),
        ),
        IconButton(
          tooltip: s.t('إرسال', 'Send'),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.send, size: 16),
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }
}
