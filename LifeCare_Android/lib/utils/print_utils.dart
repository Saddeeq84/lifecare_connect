// Utility for printing PDFs
// Uses conditional import to handle platform differences

import 'print_utils_stub.dart'
    if (dart.library.js_interop) 'print_utils_web.dart'
    if (dart.library.io) 'print_utils_stub.dart';

Future<void> printHtmlContent(String htmlContent) => printHtml(htmlContent);
