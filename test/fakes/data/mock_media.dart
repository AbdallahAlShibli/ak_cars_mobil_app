/// Placeholder attachment bytes for the demo dataset.
///
/// **These are generated placeholders, not photographs.** Each is a 240×160
/// PNG — a flat Sand-or-Ink-tinted panel with a border — so the demo shows the
/// real base64 pipeline end to end (encode, store, decode, draw) without
/// shipping stock imagery that pretends to be a customer's actual car or a
/// real commercial-registration certificate.
///
/// They look like placeholders on purpose. A demo proof gallery filled with
/// convincing stock photos would make the escrow-approval screens read as if
/// somebody's job had really been documented, and the one thing that screen
/// must never do is make invented evidence look real.
library;

import 'package:ak_cars_mobil_app/core/utils/guid.dart';
import 'package:ak_cars_mobil_app/data/models/media_attachment.dart';


/// Sand-tinted panel — stands in for a scanned document.
const String _placeholderDocumentPng =
    'iVBORw0KGgoAAAANSUhEUgAAAPAAAACgCAIAAAC9uXYyAAABXUlEQVR42u3SQQ0AIAwAsbngQf'
    'CvBwc8kTEb29KkCi4XZy8YIyTA0FB+6P8uNGVoDA2GBkODoTG0oTE0GBoMDYbG0IbG0GBoMDQ'
    'YGkPrgqHB0GBoMDSGBkODocHQYGgMDYYGQ4OhwdAYGgwNhgZDg6ExNBgaDA2GxtCGxtBgaDA0'
    'GBpDGxpDg6HB0GBoDG1oDA2GBkODoTE0GBoMDYYGQ2NoMDQYGgwNhsbQYGgwNBgaDI2hwdBga'
    'DA0GBpDg6HB0GBoDG1oDA2GBkODoTG0oTE0GBoMDYbG0LpgaDA0GBoMjaHB0GBoMDQYGkODoc'
    'HQYGgwNIYGQ4OhwdBgaAwNhgZDg6ExtKExNBgaDA2GxtCGxtBgaDA0GBpDGxpDg6HB0GBoDA2'
    'GBkODocHQGBoMDYYGQ4OhMTQYGgwNhgZDY2gwNBgaDA2GxtBgaDA0GBpDGxpDQ4+hYQBDY2io'
    'KgFEBZg5n7VjWAAAAABJRU5ErkJggg==';

/// Slate-tinted panel — stands in for a workshop's completion-proof photo.
const String _placeholderPhotoPng =
    'iVBORw0KGgoAAAANSUhEUgAAAPAAAACgCAIAAAC9uXYyAAABXElEQVR42u3SwQkAIAwAsW7hQ9'
    'x/I/HjLl2jLYFMcFycvWCMkABDQ/mh73/QlKExNBgaDA2GxtCGxtBgaDA0GBpDGxpDg6HB0GB'
    'oDK0LhgZDg6HB0BgaDA2GBkODoTE0GBoMDYYGQ2NoMDQYGgwNhsbQYGgwNBgaQxsaQ4OhwdBg'
    'aAxtaAwNhgZDg6ExtKExNBgaDA2GxtBgaDA0GBoMjaHB0GBoMDQYGkODocHQYGgwNIYGQ4Ohw'
    'dBgaAwNhgZDg6ExtKExNBgaDA2GxtCGxtBgaDA0GBpD64KhwdBgaDA0hgZDg6HB0GBoDA2GBk'
    'ODocHQGBoMDYYGQ4OhMTQYGgwNhsbQhsbQYGgwNBgaQxsaQ4OhwdBgaAxtaAwNhgZDg6ExNBg'
    'aDA2GBkNjaDA0GBoMDYbG0GBoMDQYGgyNocHQYGgwNBgaQ4OhwdBgaAxtaAwNPYaGAQyNoaGq'
    'BEtg5QntxnMnAAAAAElFTkSuQmCC';

/// A demo commercial-registration certificate for the workshop with [crNumber].
///
/// The file name carries the CR number so the founder's review dialog shows
/// something that distinguishes one seeded application from another — the
/// image bytes themselves are identical for all of them.
MediaAttachment mockCrDocument({required String id, required String crNumber}) =>
    MediaAttachment(
      id: id,
      base64Data: _placeholderDocumentPng,
      mimeType: 'image/png',
      fileName: 'cr-$crNumber.png',
    );

/// A demo completion-proof photo.
MediaAttachment mockProofPhoto({
  required String id,
  required String fileName,
  required String caption,
}) =>
    MediaAttachment(
      id: id,
      base64Data: _placeholderPhotoPng,
      mimeType: 'image/jpeg',
      fileName: fileName,
      caption: caption,
    );

/// Deterministic proof-photo ids for a seeded request.
///
/// The seed builds proofs for several requests from one helper, so their
/// attachment ids have to be derived from the request rather than written out
/// one by one — but they still have to be *stable* GUIDs, because a test that
/// re-seeds and compares two runs would otherwise see every attachment change.
/// [derivedGuid] does that: same inputs, same GUID, every run.
String mockProofMediaId(String requestId, int index) =>
    derivedGuid('proof-media', requestId, index);
