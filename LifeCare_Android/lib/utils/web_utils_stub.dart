// Implementation for non-web platforms (mobile)
import 'package:url_launcher/url_launcher.dart';

Future<void> webOpenTab(String url) async {
  try {
    final uri = Uri.parse(url);

    // Try different launch modes to ensure compatibility
    bool launched = false;

    // First try external application mode
    if (await canLaunchUrl(uri)) {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // If external app fails, try platform default
    if (!launched) {
      launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    }

    // If still not launched, try in-app browser
    if (!launched) {
      launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
    }

    if (!launched) {
      throw 'Failed to launch URL with all methods: $url';
    }
  } catch (e) {
    throw 'Could not launch $url: $e';
  }
}

Future<void> webPrintCurrentWindow() async {}
