/// Record identity for the whole app: a RFC 4122 version-4 UUID, lowercase,
/// hyphenated, 36 characters.
///
/// **Every record carries one.** Not a sequence number, not a slug, not
/// `'m${microsecondsSinceEpoch}'` — those were the three schemes this file
/// replaced. A GUID is the identity the backend's tables use as their primary
/// key, so a record created offline on a phone already holds the id it will
/// keep once it is stored, and nothing has to be re-keyed on upload.
///
/// Written by hand rather than pulled from `package:uuid` on purpose: the app
/// needs one 30-line function out of that package, and a dependency is a thing
/// to keep updated, audit, and resolve at build time. If the app ever needs
/// v5/v7 as well, take the package and delete this.
library;

import 'dart:math';


/// Cryptographically seeded so two devices generating ids at the same instant
/// do not collide. `Random.secure()` is not guaranteed on every platform, so
/// a plain `Random` seeded off the clock stands in where it is unavailable —
/// worse entropy, but still 122 random bits and never a crash at start-up.
final Random _rng = () {
  try {
    return Random.secure();
  } on UnsupportedError {
    return Random(DateTime.now().microsecondsSinceEpoch);
  }
}();

const String _hex = '0123456789abcdef';

/// A fresh v4 GUID, e.g. `3f2a7c1e-8b4d-4e9a-a5f0-2c6d1b7e4a93`.
///
/// The two fixed nibbles are what make it *version 4* rather than a random
/// 32-digit string: position 12 is always `4`, and position 16 is one of
/// `8/9/a/b`. Anything reading these ids can tell they were generated, not
/// assigned by a counter.
String newGuid() {
  final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1 (RFC 4122)

  final out = StringBuffer();
  for (var i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) out.write('-');
    out
      ..write(_hex[(bytes[i] >> 4) & 0x0f])
      ..write(_hex[bytes[i] & 0x0f]);
  }
  return out.toString();
}

/// The all-zero GUID, for "no record yet" where a nullable id would force a
/// null check at every read site.
const String emptyGuid = '00000000-0000-0000-0000-000000000000';

final RegExp _guidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Whether [value] is a well-formed, lowercase, hyphenated GUID.
///
/// Deliberately strict about case: the app writes lowercase everywhere, and
/// accepting `A5F0` here would let two spellings of the same id compare
/// unequal as map keys and as `==` on a model.
bool isGuid(String value) => _guidPattern.hasMatch(value);

/// A GUID derived from [parts] — same inputs, same GUID, every run, on every
/// device.
///
/// For the records the app *composes* rather than stores: the stand-in
/// offering behind a custom-quote booking is rebuilt from the request on every
/// read, and a fresh [newGuid] each time would make the offering compare
/// unequal to the one built a frame earlier, rebuilding half the screen. The
/// demo dataset uses it for the same reason — a re-seed must produce the same
/// ids or nothing that compares two runs can pass.
///
/// **Not a UUID v5.** A real v5 is a namespaced SHA-1, and the app has no
/// SHA-1 without adding `package:crypto` for this one use. This is a
/// 128-bit FNV-1a-derived value stamped into the v4 layout: stable and well
/// distributed, but only as collision-resistant as a 122-bit hash of the
/// inputs, and not interoperable with a v5 computed anywhere else. That is
/// sufficient here because every caller derives from an id that is already
/// unique. Do not use it to derive an id from user-controlled text.
String derivedGuid(String namespace, [Object? a, Object? b]) {
  final seed = [namespace, ?a, ?b].join(' ');

  // Two FNV-1a passes over the same input with different offset bases give
  // the 16 bytes; one 64-bit pass would leave half the GUID constant.
  var h1 = BigInt.parse('cbf29ce484222325', radix: 16);
  var h2 = BigInt.parse('84222325cbf29ce4', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final unit in seed.codeUnits) {
    h1 = ((h1 ^ BigInt.from(unit)) * prime) & mask;
    h2 = ((h2 ^ BigInt.from(unit ^ 0x5a)) * prime) & mask;
  }

  final bytes = <int>[
    for (var i = 7; i >= 0; i--) ((h1 >> (i * 8)) & BigInt.from(0xff)).toInt(),
    for (var i = 7; i >= 0; i--) ((h2 >> (i * 8)) & BigInt.from(0xff)).toInt(),
  ];
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final out = StringBuffer();
  for (var i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) out.write('-');
    out
      ..write(_hex[(bytes[i] >> 4) & 0x0f])
      ..write(_hex[bytes[i] & 0x0f]);
  }
  return out.toString();
}

/// [value] when it is a GUID, otherwise a fresh one.
///
/// The seam for data that predates this scheme: a persisted record from an
/// older build carries `'m1754...'` or `'rev-501'`, and re-keying it on read
/// is better than either crashing or storing a non-GUID id forever. The old
/// value is dropped rather than hashed into the new one — a stable mapping
/// would imply the old id still means something, and it does not.
String coerceGuid(String? value) =>
    (value != null && isGuid(value)) ? value : newGuid();
