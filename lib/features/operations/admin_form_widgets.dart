import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/sand_widgets.dart';

/// The small pieces the founder panel's editors and management lists share.
///
/// They used to be private to `admin_content_screen.dart`, back when that one
/// screen owned both the offer editor and the announcement editor. Offers now
/// live on their own tab, and a date field copied per screen is how two date
/// formats end up on one panel.

/// A read-only field that opens a date picker — the same shape as the text
/// fields around it, so a form does not visibly change control style halfway
/// down.
class AdminDatePickerField extends StatelessWidget {
  const AdminDatePickerField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(LucideIcons.calendar, size: 16, color: ak.inkSub),
        ),
        child: Text(formatAdminDate(date), style: TextStyle(color: ak.ink)),
      ),
    );
  }
}

/// `2026-08-31`. One date format across the whole founder panel — an operator
/// comparing an offer's window against the ledger should not have to reconcile
/// two.
String formatAdminDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class AdminLoadingBlock extends StatelessWidget {
  const AdminLoadingBlock({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );
}

class AdminErrorBlock extends StatelessWidget {
  const AdminErrorBlock({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return EmptyState(
      compact: true,
      icon: LucideIcons.circleAlert,
      message: message,
      action: InkPill(
        label: s.t('إعادة المحاولة', 'Retry'),
        outlined: true,
        onTap: onRetry,
      ),
    );
  }
}
