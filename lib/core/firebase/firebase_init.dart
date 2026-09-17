import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

Future<FirebaseApp>? _starting;

/// Starts the default Firebase app once, however many features ask for it.
///
/// Push registration and phone sign-in both need Firebase and can both ask in
/// the same frame at sign-in; two concurrent `initializeApp` calls race to
/// register the same app. A failure clears the memo so a later call can try
/// again (a first launch with no network, say).
///
/// Explicit options rather than the native config files: web has no
/// `google-services.json` equivalent to fall back on.
Future<FirebaseApp> ensureFirebaseInitialized() {
  if (Firebase.apps.isNotEmpty) return Future.value(Firebase.app());
  return _starting ??= Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).catchError((Object error, StackTrace stack) {
    _starting = null;
    Error.throwWithStackTrace(error, stack);
  });
}