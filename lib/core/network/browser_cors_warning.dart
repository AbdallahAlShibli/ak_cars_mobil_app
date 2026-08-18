import 'package:dio/dio.dart';

/// No-op on every platform that is not the browser — there is no CORS off the
/// web, so there is nothing to quieten. See the web implementation for why
/// this exists at all.
void silenceBrowserCorsWarnings(Dio dio) {}
