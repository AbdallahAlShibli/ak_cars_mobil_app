import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/models.dart';
import '../../state/provider_dashboard_state.dart';

Future<void> showStaffEditorSheet(
  BuildContext context, {
  WorkshopStaff? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _StaffEditorSheet(existing: existing),
  );
}

class _StaffEditorSheet extends ConsumerStatefulWidget {
  const _StaffEditorSheet({this.existing});

  final WorkshopStaff? existing;

  @override
  ConsumerState<_StaffEditorSheet> createState() => _StaffEditorSheetState();
}

class _StaffEditorSheetState extends ConsumerState<_StaffEditorSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _specialties = TextEditingController(
    text: widget.existing?.specialties.join(', '),
  );
  late WorkshopStaffRole _role =
      widget.existing?.role ?? WorkshopStaffRole.technician;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _specialties.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        left: AppSpacing.screenMargin,
        right: AppSpacing.screenMargin,
        top: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null
                ? s.t('عضو جديد', 'New team member')
                : s.t('تعديل العضو', 'Edit team member'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: s.t('الاسم', 'Name')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _phone,
            decoration: InputDecoration(labelText: s.t('الهاتف', 'Phone')),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<WorkshopStaffRole>(
            initialValue: _role,
            decoration: InputDecoration(labelText: s.t('الدور', 'Role')),
            items: [
              for (final role in WorkshopStaffRole.values)
                DropdownMenuItem(value: role, child: Text(role.label(s))),
            ],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _specialties,
            decoration: InputDecoration(
              labelText: s.t(
                'التخصصات (مفصولة بفاصلة)',
                'Specialties (comma-separated)',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _name.text.trim().isEmpty || _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    final notifier = ref.read(workshopStaffProvider.notifier);
                    final specialties = _specialties.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    try {
                      if (widget.existing == null) {
                        await notifier.create(
                          name: _name.text.trim(),
                          phone: _phone.text.trim().isEmpty
                              ? null
                              : _phone.text.trim(),
                          role: _role,
                          specialties: specialties,
                        );
                      } else {
                        await notifier.edit(
                          widget.existing!.id,
                          name: _name.text.trim(),
                          phone: _phone.text.trim().isEmpty
                              ? null
                              : _phone.text.trim(),
                          role: _role,
                          specialties: specialties,
                        );
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.t('حفظ', 'Save')),
          ),
        ],
      ),
    );
  }
}
