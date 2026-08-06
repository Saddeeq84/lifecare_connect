// Actual implementation for web
import 'package:web/web.dart' as web;

Future<void> webOpenTab(String url) async {
  web.window.open(url, '_blank');
}

Future<void> webPrintCurrentWindow() async {
  web.window.print();
}
