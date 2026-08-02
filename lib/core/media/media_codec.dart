/// Base64 encode/decode and MIME resolution — the byte-level half of the
/// attachment pipeline.
///
/// Deliberately knows nothing about `MediaAttachment`, `image_picker`, or
/// widgets: it takes bytes and paths and returns bytes and strings, so it can
/// be unit-tested without a Flutter binding and reused by whatever picks the
/// next kind of file.
library;

import 'dart:convert';
import 'dart:typed_data';


/// Largest file the app will attach, **before** encoding: 4 MB.
///
/// The ceiling exists because these bytes live in a database column and travel
/// inside every request and response that carries the record. Base64 inflates
/// by 4/3, so 4 MB of file is ~5.6 MB of JSON — already more than a phone on
/// Omani mobile data should be asked to send. Camera captures land far under
/// it (`maxWidth: 1600, imageQuality: 82` puts a photo at 200–500 KB); the
/// limit is there for a PDF or an unscaled gallery original.
const int maxAttachmentBytes = 4 * 1024 * 1024;

/// Encodes [bytes] for storage. Plain base64, no `data:` prefix, no line
/// breaks — see `MediaAttachment.base64Data` for why the prefix is not stored.
String encodeAttachmentBytes(Uint8List bytes) => base64Encode(bytes);

/// Decodes [base64Data] back to bytes, or null when it is empty or malformed.
///
/// Returns null instead of throwing because every caller is a widget deciding
/// what to paint: a corrupt attachment has to become a "cannot preview" tile,
/// not an exception in a build method. It also tolerates a `data:` prefix, so
/// a value that came from somewhere that does use the URL convention still
/// renders instead of failing on the first character.
Uint8List? tryDecodeAttachment(String base64Data) {
  if (base64Data.isEmpty) return null;
  var payload = base64Data;
  if (payload.startsWith('data:')) {
    final comma = payload.indexOf(',');
    if (comma == -1) return null;
    payload = payload.substring(comma + 1);
  }
  try {
    return base64Decode(payload);
  } on FormatException {
    return null;
  }
}

/// The MIME type to record for a picked file.
///
/// [declared] is what the picker reported — authoritative when present, which
/// on web it always is. On Android and iOS it is usually null, so the file
/// extension decides. When neither answers, the type is
/// `application/octet-stream`: a wrong guess would make the app try to render
/// a PDF as an image, and "no preview available" is the honest outcome.
String resolveMimeType({String? declared, String path = ''}) {
  final reported = declared?.trim().toLowerCase();
  if (reported != null && reported.isNotEmpty && reported.contains('/')) {
    return reported;
  }
  final dot = path.lastIndexOf('.');
  if (dot == -1 || dot == path.length - 1) return 'application/octet-stream';
  return _byExtension[path.substring(dot + 1).toLowerCase()] ??
      'application/octet-stream';
}

/// Only the types the app's own pickers can actually produce, plus PDF, which
/// is what a commercial-registration certificate is most often scanned as.
/// An unlisted extension resolves to `application/octet-stream` rather than
/// being guessed at.
const Map<String, String> _byExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'bmp': 'image/bmp',
  'pdf': 'application/pdf',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
};

/// The trailing name of [path], for [MediaAttachment.fileName]. Handles both
/// separators because a web blob path and an Android content path disagree.
String fileNameFrom(String path) {
  final cut = path.lastIndexOf(RegExp(r'[/\\]'));
  return cut == -1 ? path : path.substring(cut + 1);
}

/// A byte count as a short human label: `842 KB`, `1.4 MB`.
///
/// Shown next to a document that has no thumbnail — the size is most of what
/// tells a reviewer whether a "certificate" is a real scan or a stray 3 KB
/// screenshot.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.round()} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
