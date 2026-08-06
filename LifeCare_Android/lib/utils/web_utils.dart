// Utility for web-only features (e.g., opening a new tab)
// Uses conditional import to avoid issues on non-web platforms

// ignore: avoid_web_libraries_in_flutter
import 'web_utils_web.dart'
    if (dart.library.js_interop) 'web_utils_web.dart'
    if (dart.library.io) 'web_utils_stub.dart';

Future<void> openWebTab(String url) => webOpenTab(url);

Future<void> printCurrentWindow() => webPrintCurrentWindow();
