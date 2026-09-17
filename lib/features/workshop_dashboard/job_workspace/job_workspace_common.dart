import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/models.dart';

/// Hands the workspace screen a booking with a just-saved change applied, so
/// the tab shows it before the refreshed list comes back from the server.
typedef JobRequestChanged = void Function(ServiceRequest updated);

const jobTabPadding = EdgeInsets.fromLTRB(
  AppSpacing.screenMargin,
  AppSpacing.lg,
  AppSpacing.screenMargin,
  AppSpacing.xxl,
);

/// Says why a section cannot be edited at the booking's current stage.
class StageNotice extends StatelessWidget {
  const StageNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return AppCard(
      color: ak.surfaceDim,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 16, color: ak.inkSub),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: context.text.bodySecondary)),
        ],
      ),
    );
  }
}

/// A button icon that turns into a spinner while its action runs.
class BusyIcon extends StatelessWidget {
  const BusyIcon({super.key, required this.icon, required this.busy});

  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => busy
      ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon, size: 17);
}

/// Parses a typed amount, accepting a comma as the decimal separator.
double? parseJobNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
