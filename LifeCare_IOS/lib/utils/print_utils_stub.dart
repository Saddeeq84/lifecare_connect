// Non-web implementation for printing HTML content
// For mobile platforms, we can't directly print HTML like on web
// This is a stub that does nothing or shows a message

Future<void> printHtml(String htmlContent) async {
  // On mobile, printing HTML directly is not supported
  // Could integrate with a PDF library or show a message
  print('Print functionality is only available on web platform');
}
