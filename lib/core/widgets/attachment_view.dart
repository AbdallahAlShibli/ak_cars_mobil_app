/// Renders a stored [MediaAttachment] — the display half of the base64
/// pipeline, and the only place in the app that turns stored characters back
/// into something a person can look at.
///
/// One widget covers every platform. That is the main thing base64 bought:
/// the app used to need a conditional import (`Image.file` behind `dart:io` on
/// mobile, `Image.network` on a blob URL on web) because an attachment was a
/// path, and a path means something different on each. Bytes do not, so
/// `Image.memory` is correct everywhere and the three-file shim is gone.
library;

import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/media_attachment.dart';
import '../media/media_codec.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';


/// Decoded bytes, kept so a rebuild does not re-decode.
///
/// Two costs are being avoided, not one. Base64-decoding a 500 KB photo on
/// every `build` is the obvious one; the subtler one is that `Image.memory`
/// keys Flutter's own image cache on the *identity* of the byte list it is
/// given, so handing it a fresh `Uint8List` each time re-decodes the JPEG into
/// a bitmap as well. Returning the same instance for the same attachment id
/// makes both caches hit.
///
/// Bounded by total decoded size rather than entry count: twenty thumbnails
/// and one 4 MB certificate are very different amounts of memory to be holding
/// on a mid-range phone. Eviction is oldest-inserted-first — a
/// `LinkedHashMap` preserves insertion order, and re-inserting on read would
/// make it a true LRU at the cost of mutating during a build.
class _DecodedCache {
  static const int _maxBytes = 16 * 1024 * 1024;

  static final LinkedHashMap<String, Uint8List> _entries = LinkedHashMap();
  static int _heldBytes = 0;

  /// The decoded bytes of [attachment], or null when it holds nothing
  /// decodable. Null is cached as absence, so a corrupt attachment is retried
  /// on each rebuild — cheap, because `tryDecodeAttachment` fails fast.
  static Uint8List? of(MediaAttachment attachment) {
    final hit = _entries[attachment.id];
    if (hit != null) return hit;

    final bytes = tryDecodeAttachment(attachment.base64Data);
    if (bytes == null) return null;

    _entries[attachment.id] = bytes;
    _heldBytes += bytes.lengthInBytes;
    while (_heldBytes > _maxBytes && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      _heldBytes -= _entries.remove(oldest)!.lengthInBytes;
    }
    return bytes;
  }

  /// Drops everything. Called by tests so one test's attachment bytes cannot
  /// satisfy another test's lookup of the same id.
  static void clear() {
    _entries.clear();
    _heldBytes = 0;
  }
}

/// Test-only: empties the decoded-attachment cache.
@visibleForTesting
void resetAttachmentCache() => _DecodedCache.clear();

/// An attachment drawn at whatever size its parent gives it.
///
/// Images render; videos and documents cannot be previewed without a decoder
/// this app does not ship, so they get a labelled tile naming the file and its
/// size instead. A tile that says "PDF · 842 KB" is useful; a grey rectangle
/// that might be a failed image is not, and the difference matters most to the
/// one screen that reads these to approve a business.
class AttachmentView extends StatelessWidget {
  const AttachmentView({
    super.key,
    required this.attachment,
    this.fit = BoxFit.cover,
  });

  final MediaAttachment attachment;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (attachment.kind != MediaKind.image) {
      return _AttachmentFileTile(attachment: attachment);
    }
    final bytes = _DecodedCache.of(attachment);
    if (bytes == null) return const AttachmentUnavailable();
    return Image.memory(
      bytes,
      fit: fit,
      // Reaches here when the bytes decoded from base64 fine but are not a
      // format the engine can draw — a renamed file, or a truncated upload.
      errorBuilder: (_, _, _) => const AttachmentUnavailable(),
    );
  }
}

/// Fixed-size rounded thumbnail, for strips and galleries.
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({
    super.key,
    required this.attachment,
    this.width = 112,
    this.height = 86,
    this.radius = 16,
  });

  final MediaAttachment attachment;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: width,
          height: height,
          child: AttachmentView(attachment: attachment),
        ),
      );
}

/// What a non-image attachment looks like: icon, file name, size.
class _AttachmentFileTile extends StatelessWidget {
  const _AttachmentFileTile({required this.attachment});

  final MediaAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final isVideo = attachment.kind == MediaKind.video;
    return Container(
      color: ak.surfaceDim,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isVideo ? LucideIcons.video : LucideIcons.fileText,
            size: 20,
            color: ak.inkSub,
          ),
          const SizedBox(height: 4),
          Text(
            attachment.fileName.isEmpty
                ? attachment.mimeType
                : attachment.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: ak.inkSub),
          ),
          Text(
            formatBytes(attachment.byteLength),
            style: TextStyle(fontSize: 9.5, color: ak.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// The "there is nothing to show here" tile.
///
/// Says so in an icon rather than rendering blank space: an attachment that
/// failed to decode and an attachment that was never added must not look the
/// same, least of all on the approval screens where the presence of evidence
/// is the whole decision.
class AttachmentUnavailable extends StatelessWidget {
  const AttachmentUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      color: ak.surfaceDim,
      alignment: Alignment.center,
      child: Icon(LucideIcons.imageOff, size: 22, color: ak.inkFaint),
    );
  }
}

/// A document shown at full width with its name and size beside it — the
/// reviewer-facing form, used where an attachment is the thing being judged
/// rather than a thumbnail in a row.
class AttachmentDocumentCard extends StatelessWidget {
  const AttachmentDocumentCard({
    super.key,
    required this.attachment,
    this.maxImageHeight = 320,
  });

  final MediaAttachment attachment;
  final double maxImageHeight;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (attachment.kind == MediaKind.image)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxImageHeight),
              child: AttachmentView(attachment: attachment, fit: BoxFit.contain),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: ak.surfaceDim,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.fileText, size: 18, color: ak.inkSub),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    attachment.fileName.isEmpty
                        ? attachment.mimeType
                        : attachment.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySecondary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${attachment.mimeType} · ${formatBytes(attachment.byteLength)}',
          style: context.text.bodySecondary.copyWith(color: ak.inkFaint),
        ),
      ],
    );
  }
}
