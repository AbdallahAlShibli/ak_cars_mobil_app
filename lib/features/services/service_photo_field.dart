import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/attachment_view.dart';
import '../../data/models/models.dart';
import 'proof_upload_sheet.dart' show pickAttachments, showOversizedNotice;

/// The photo field on a service offering's create/edit form.
///
/// A workshop owner may leave this unset — the offering falls back to a
/// default placeholder wherever it is shown, same as [AttachmentUnavailable]
/// does for other attachments. Picking, size-capping and encoding all go
/// through [pickAttachments], the same path the proof sheet and the workshop
/// registration form use, so a service photo is capped at the same 4 MB and
/// downscaled the same way.
class ServicePhotoField extends StatefulWidget {
  const ServicePhotoField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MediaAttachment? value;
  final ValueChanged<MediaAttachment?> onChanged;

  @override
  State<ServicePhotoField> createState() => _ServicePhotoFieldState();
}

class _ServicePhotoFieldState extends State<ServicePhotoField> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _choose() async {
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
    if (result.media.isNotEmpty) widget.onChanged(result.media.first);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ak = AkColors.of(context);
    final photo = widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.t('صورة الخدمة (اختياري)', 'Service photo (optional)'),
          style: TextStyle(fontSize: 12, color: ak.inkSub),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        GestureDetector(
          onTap: _busy ? null : _choose,
          child: Container(
            height: 140,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: ak.surfaceDim,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ak.border),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photo != null)
                  AttachmentView(attachment: photo)
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.imagePlus,
                          size: 26,
                          color: ak.inkFaint,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          s.t(
                            'أضف صورة، أو اتركها للصورة الافتراضية',
                            'Add a photo, or leave the default',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: ak.inkFaint),
                        ),
                      ],
                    ),
                  ),
                if (_busy)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (photo != null && !_busy)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _RemoveButton(onTap: () => widget.onChanged(null)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A small rounded thumbnail for an offering's photo, wherever a catalogue
/// card lists one — the read-only counterpart to [ServicePhotoField]. Falls
/// back to a placeholder icon rather than an empty gap when the workshop
/// left the field unset.
class OfferingPhotoThumb extends StatelessWidget {
  const OfferingPhotoThumb({
    super.key,
    required this.photo,
    this.size = 56,
    this.radius = 12,
  });

  final MediaAttachment? photo;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: photo != null
            ? AttachmentView(attachment: photo!)
            : Container(
                color: ak.surfaceDim,
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.wrench,
                  size: size * 0.4,
                  color: ak.inkFaint,
                ),
              ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.55),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(LucideIcons.x, size: 14, color: Colors.white),
      ),
    ),
  );
}
