import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/i18n/strings.dart';
import '../../core/media/local_image.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

/// What the workshop composed, handed back to whoever opened the sheet.
typedef ProofDraft = ({
  String notes,
  List<ProofMedia> media,
  bool includesPartBoxPhoto,
});

/// Where a workshop assembles its completion proof (spec §3).
///
/// This is the gate the whole escrow rests on: the customer releases money
/// because of what is collected here, so the sheet enforces the two rules the
/// state machine also enforces (`ServiceRequest.proofSatisfiesRules`) rather
/// than letting the user fill a form that will be silently rejected —
///
/// 1. **At least one photo or video.** Notes alone are a claim; a photo is
///    evidence. The submit button stays disabled until there is one.
/// 2. **On a part-and-fitting job, a declared photo of the part's own box.**
///    The customer paid for a specific part from a specific brand, and a shot
///    of a closed bonnet proves neither.
///
/// The app cannot look inside a picture, so rule 2 is the workshop's own
/// declaration — which is exactly why the customer is shown that it was made.
///
/// Lives under `features/services/` rather than with the workshop panel
/// because it is the customer-facing side of the transaction that gives it its
/// rules; the panel is only the surface that happens to open it.
class ProofUploadSheet extends StatefulWidget {
  const ProofUploadSheet({
    super.key,
    required this.s,
    required this.request,
    this.picker,
  });

  final S s;
  final ServiceRequest request;

  /// Injectable so a widget test can compose a proof without a real camera.
  /// Null in production — the sheet makes its own.
  final ImagePicker? picker;

  @override
  State<ProofUploadSheet> createState() => _ProofUploadSheetState();
}

class _ProofUploadSheetState extends State<ProofUploadSheet> {
  final _notes = TextEditingController();
  final _media = <ProofMedia>[];
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  bool _partBoxShown = false;
  bool _busy = false;

  /// Only a part-and-fitting job has a part whose box can be shown.
  bool get _needsPartBox => widget.request.type == BookingType.customQuote;

  /// The same two conditions `ServiceRequest.proofSatisfiesRules` applies.
  bool get _canSubmit => _media.isNotEmpty && (!_needsPartBox || _partBoxShown);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _add(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    final picked = await pickAttachments(_picker, source, startIndex: _media.length);
    if (!mounted) return;
    setState(() {
      _media.addAll(picked);
      _busy = false;
    });
  }

  void _remove(String id) =>
      setState(() => _media.removeWhere((m) => m.id == id));

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final ak = AkColors.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('إثبات الإنجاز', 'Proof of work'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              s.t(
                'صوّر ما أنجزته واكتب ما تم بالضبط. يراها العميل قبل أن يوافق على تحرير المبلغ.',
                'Photograph what you finished and describe exactly what was done. The customer sees this before releasing the payment.',
              ),
              style: TextStyle(fontSize: 12, color: ak.inkSub),
            ),
            const SizedBox(height: 14),

            MediaStrip(
              s: s,
              media: _media,
              busy: _busy,
              onRemove: _remove,
              onCamera: () => _add(ImageSource.camera),
              onGallery: () => _add(ImageSource.gallery),
            ),

            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: s.t(
                  'ما الذي تم؟ (اختياري)',
                  'What was done? (optional)',
                ),
              ),
            ),

            if (_needsPartBox) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _partBoxShown,
                onChanged: (v) => setState(() => _partBoxShown = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s.t(
                    'من بين الصور صورة علبة القطعة أو ملصقها',
                    'One of these photos shows the part’s box or label',
                  ),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  s.t(
                    'مطلوب لطلبات «قطعة + تركيب» قبل إرسال الإثبات.',
                    'Required on part-and-fitting jobs before proof can be submitted.',
                  ),
                  style: TextStyle(fontSize: 11, color: ak.inkSub),
                ),
              ),
            ],

            const SizedBox(height: 14),
            FilledButton(
              onPressed: _canSubmit
                  ? () => Navigator.of(context).pop((
                      notes: _notes.text,
                      media: List<ProofMedia>.unmodifiable(_media),
                      includesPartBoxPhoto: _partBoxShown,
                    ))
                  : null,
              child: Text(s.t('إرسال الإثبات', 'Submit proof')),
            ),
            // Says which rule is still unmet rather than leaving a dead button
            // with no explanation.
            if (!_canSubmit) ...[
              const SizedBox(height: 8),
              Text(
                _media.isEmpty
                    ? s.t(
                        'أضف صورة واحدة على الأقل لإرسال الإثبات.',
                        'Add at least one photo to submit the proof.',
                      )
                    : s.t(
                        'أكّد أن من بين الصور صورة علبة القطعة.',
                        'Confirm that one of the photos shows the part’s box.',
                      ),
                style: TextStyle(fontSize: 11, color: ak.inkSub),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Picks one or more images and wraps them as [ProofMedia].
///
/// Shared by the proof sheet and the workshop-registration form (§10), which
/// attach very different things for very different reasons but pick them
/// identically.
///
/// Photos are downscaled on capture: an attachment is looked at on a phone, and
/// a full-resolution image would make the eventual upload the slowest part of
/// whatever the user was doing.
///
/// A denied permission or a cancelled picker returns an empty list rather than
/// throwing — both are ordinary outcomes, not errors worth a dialog. The caller
/// keeps whatever was already attached, and its disabled submit button goes on
/// saying what is still missing.
Future<List<ProofMedia>> pickAttachments(
  ImagePicker picker,
  ImageSource source, {
  int startIndex = 0,
}) async {
  try {
    final shots = source == ImageSource.gallery
        ? await picker.pickMultiImage(maxWidth: 1600, imageQuality: 82)
        : [
            ?await picker.pickImage(
              source: source,
              maxWidth: 1600,
              imageQuality: 82,
            ),
          ];
    return [
      for (final (i, shot) in shots.indexed)
        ProofMedia(
          id: 'm${DateTime.now().microsecondsSinceEpoch}-${startIndex + i}',
          uri: shot.path,
        ),
    ];
  } on Exception {
    return const [];
  }
}

/// The attached shots, with the two ways to add one.
///
/// Public because the workshop-registration form attaches a commercial
/// registration certificate through exactly this control (§10). Two upload
/// widgets that look almost the same is how a design drifts, so this is the
/// one — the *caller* owns what the attachments mean and what rule they have
/// to satisfy, and this owns only how they are picked and shown.
class MediaStrip extends StatelessWidget {
  const MediaStrip({
    super.key,
    required this.s,
    required this.media,
    required this.busy,
    required this.onRemove,
    required this.onCamera,
    required this.onGallery,
  });

  final S s;
  final List<ProofMedia> media;
  final bool busy;
  final void Function(String id) onRemove;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (media.isNotEmpty)
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _Thumb(
                media: media[i],
                onRemove: () => onRemove(media[i].id),
              ),
            ),
          ),
        if (media.isNotEmpty) const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onCamera,
                icon: const Icon(LucideIcons.camera, size: 18),
                label: Text(s.t('تصوير', 'Camera')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onGallery,
                icon: const Icon(LucideIcons.images, size: 18),
                label: Text(s.t('من المعرض', 'Gallery')),
              ),
            ),
          ],
        ),
        if (media.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            s.t('لم تُرفق صور بعد.', 'No photos attached yet.'),
            style: TextStyle(fontSize: 11, color: ak.inkFaint),
          ),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.media, required this.onRemove});

  final ProofMedia media;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 112,
            height: 86,
            child: localImage(
              media.uri,
              onError: (context) => Container(
                color: ak.surfaceDim,
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.imageOff,
                  size: 22,
                  color: ak.inkFaint,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(LucideIcons.x, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
