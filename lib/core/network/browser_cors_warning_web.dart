import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Stops Dio's web adapter warning, once per request, that the call will
/// trigger a CORS preflight.
///
/// It is right about the mechanism and useless as a signal here: this client
/// sends `application/json` and an `Authorization` header on nearly every
/// call, so *every* request is a non-simple one, and each warning arrives with
/// a 25-line stack trace. A single screen's worth of traffic buried the
/// console deep enough that real failures could not be found in it, which is
/// the actual cost.
///
/// The preflights themselves are fine — the API answers `OPTIONS` with `204`
/// (see the `DevWeb` policy in the API's `Program.cs`), and the requests
/// succeed.
///
/// **The caveat that policy is `Development`-only.** A *production* web build
/// against a production API would find no CORS configuration there at all, and
/// every one of these requests would fail. This silences a warning, not a
/// safeguard: that failure would still be loud, arriving as a
/// `NetworkException` naming the host it could not reach. Web is a
/// development convenience for this app — the shipping targets are Android and
/// iOS, which are not browsers and have no CORS to preflight.
void silenceBrowserCorsWarnings(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is BrowserHttpClientAdapter) {
    adapter.enableCORSWarning = false;
  }
}
