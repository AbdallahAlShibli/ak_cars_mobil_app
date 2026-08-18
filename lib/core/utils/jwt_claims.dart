import 'dart:convert';

/// The JSON key `TokenService.GenerateAccessToken` writes a founder's role
/// claim under on the backend (`AKCarsMobileAPI`).
///
/// `new Claim(ClaimTypes.Role, "founder")` serialises to this full URI, not
/// the short `"role"` string one might expect — confirmed by decoding a
/// token the real `TokenService` produced, since `JwtPayload.AddClaims`
/// writes `Claim.Type` verbatim rather than remapping well-known types (that
/// remapping only happens on the *inbound*/validation side, which is why
/// `ICurrentUser.IsFounder`'s `FindFirstValue(ClaimTypes.Role)` still works).
const _roleClaimKey =
    'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

/// Whether a stored access token carries the backend's `founder` role claim.
///
/// This is the one fact `/auth/*` responses don't carry — `UserProfileDto`
/// mirrors the `Users` table, and founder status lives only in the JWT (see
/// `TokenService.GenerateAccessToken`). Reading it here is how the app tells
/// a founder's device from anyone else's without a local, user-settable
/// "which panel am I" switch.
///
/// **Not a trust boundary.** This is read-only, client-side, for deciding
/// which button to show — every `/admin`-only endpoint still enforces
/// `[Authorize(Roles = "founder")]` server-side regardless of what this
/// returns. A forged or stale token can make this answer wrong; it can never
/// make a server call succeed that shouldn't.
bool jwtHasFounderRole(String? token) {
  final role = _decodeJwtClaims(token)?[_roleClaimKey];
  if (role is String) return role == 'founder';
  if (role is List) return role.contains('founder');
  return false;
}

Map<String, dynamic>? _decodeJwtClaims(String? token) {
  if (token == null) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    // A malformed or non-JWT string reads as "no founder claim", the same
    // answer as a guest with no token at all — never a crash on a value this
    // is only ever used to gate a UI affordance.
    return null;
  }
}
