import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/attachment_view.dart';
import '../../data/models/models.dart';
import '../../state/job_workspace_state.dart';
import 'proof_upload_sheet.dart' show pickAttachments, showOversizedNotice;

/// Photos, dialogs and small helpers shared by the job workspace screens —
/// the workshop's editing side and the customer's read-only report.

String formatJobDate(DateTime at) {
  final local = at.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

/// A 0..1 rate as a whole percentage; null (nothing to divide by) as "—".
String formatJobRate(double? rate) =>
    rate == null ? '—' : '${(rate * 100).round()}%';

/// Runs [action] and reports a failure in a snackbar. Returns whether it
/// succeeded, so the caller decides what "done" looks like.
Future<bool> runJobAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final s = S.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on Exception catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(jobWorkspaceErrorText(s, error))),
    );
    return false;
  }
}

/// A one-field dialog that owns its controller, so the text survives the
/// dialog's closing animation. Pops the trimmed text, or null on cancel.
class JobTextDialog extends StatefulWidget {
  const JobTextDialog({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
    this.mustFill = false,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final bool mustFill;

  @override
  State<JobTextDialog> createState() => _JobTextDialogState();
}

class _JobTextDialogState extends State<JobTextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (widget.mustFill && text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.t('تراجع', 'Back')),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Read-only thumbnails; a tap opens the photo full size.
class JobPhotoThumbs extends StatelessWidget {
  const JobPhotoThumbs({super.key, required this.photos, this.size = 64});

  final List<MediaAttachment> photos;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                child: AttachmentView(
                  attachment: photos[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: size,
              height: size,
              child: AttachmentView(attachment: photos[i]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Editable photo tiles capped at [max]. Picking, the 4 MB cap and the
/// downscale all go through [pickAttachments], same as proof of work.
class JobPhotoPicker extends StatefulWidget {
  const JobPhotoPicker({
    super.key,
    required this.photos,
    required this.onChanged,
    required this.max,
    this.enabled = true,
  });

  final List<MediaAttachment> photos;
  final ValueChanged<List<MediaAttachment>> onChanged;
  final int max;
  final bool enabled;

  @override
  State<JobPhotoPicker> createState() => _JobPhotoPickerState();
}

class _JobPhotoPickerState extends State<JobPhotoPicker> {
  static const _tile = 72.0;

  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _add() async {
    final s = S.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: Text(s.t('تصوير', 'Camera')),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.images),
              title: Text(s.t('من المعرض', 'Gallery')),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _busy = true);
    final result = await pickAttachments(_picker, source);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.oversized > 0) showOversizedNotice(context, s, result);
    final room = widget.max - widget.photos.length;
    if (result.media.isEmpty || room <= 0) return;
    widget.onChanged([...widget.photos, ...result.media.take(room)]);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final canAdd = widget.enabled && widget.photos.length < widget.max;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final photo in widget.photos)
          SizedBox(
            width: _tile,
            height: _tile,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AttachmentView(attachment: photo),
                ),
                if (widget.enabled)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => widget.onChanged([
                          for (final p in widget.photos)
                            if (p.id != photo.id) p,
                        ]),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            LucideIcons.x,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (canAdd)
          InkWell(
            onTap: _busy ? null : _add,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: _tile,
              height: _tile,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ak.surfaceDim,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ak.border),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.imagePlus, size: 20, color: ak.inkSub),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.photos.length}/${widget.max}',
                          style: TextStyle(fontSize: 10.5, color: ak.inkFaint),
                        ),
                      ],
                    ),
            ),
          ),
        if (!canAdd && widget.photos.isEmpty)
          Text(
            s.t('لا صور', 'No photos'),
            style: TextStyle(fontSize: 12, color: ak.inkFaint),
          ),
      ],
    );
  }
}
