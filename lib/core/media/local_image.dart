/// Renders an image the user just captured on this device.
///
/// Completion-proof photos start life as a local file: `image_picker` hands
/// back a path (mobile) or a blob URL (web), and in the pilot there is no
/// upload step yet to turn either into an https URL. Both the workshop's
/// compose sheet and the customer's approval screen have to draw them.
///
/// The two platforms need genuinely different widgets — `Image.file` needs
/// `dart:io`, which does not exist on web, and a blob URL needs
/// `Image.network`, which cannot read a mobile file path. A conditional
/// export keeps `dart:io` out of the web build entirely rather than guarding
/// it at runtime, which would not compile.
library;

export 'local_image_io.dart'
    if (dart.library.js_interop) 'local_image_web.dart';
