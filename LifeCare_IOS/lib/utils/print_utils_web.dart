// Web implementation for printing HTML content
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> printHtml(String htmlContent) async {
  final blob = web.Blob(
    [htmlContent.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);

  // Open in new window for printing
  web.window.open(url, '_blank');

  // Cleanup after a delay
  Future.delayed(const Duration(seconds: 1), () {
    web.URL.revokeObjectURL(url);
  });
}
