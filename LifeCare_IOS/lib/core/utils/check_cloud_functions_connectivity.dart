import 'package:http/http.dart' as http;
import 'dart:async';

/// Checks if Cloud Functions are reachable from the current network
/// Returns true if reachable, false otherwise
Future<bool> checkCloudFunctionsConnectivity() async {
  try {
    print('[Connectivity] Testing Cloud Functions connectivity...');

    // Try to reach the Cloud Function with a HEAD request (faster than POST)
    final response = await http
        .head(
          Uri.parse(
            'https://us-central1-lifecare-connect.cloudfunctions.net/sendStaffSetupPasswordEmail',
          ),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('[Connectivity] ⏱️ Connection test timed out');
            throw TimeoutException('Connection test timed out');
          },
        );

    // Any response (even 400) means we can reach the server
    print(
      '[Connectivity] ✅ Cloud Functions reachable (status: ${response.statusCode})',
    );
    return true;
  } on TimeoutException {
    print(
      '[Connectivity] ❌ Connection timeout - Cloud Functions not reachable',
    );
    return false;
  } catch (e) {
    final errorMsg = e.toString().toLowerCase();
    if (errorMsg.contains('failed to fetch') ||
        errorMsg.contains('name not resolved') ||
        errorMsg.contains('err_name_not_resolved') ||
        errorMsg.contains('network') ||
        errorMsg.contains('dns')) {
      print(
        '[Connectivity] ❌ DNS/Network error - Cloud Functions not reachable: $e',
      );
      return false;
    }

    // Other errors might still mean the endpoint is reachable
    print('[Connectivity] ⚠️ Unexpected error (might still be reachable): $e');
    return true; // Assume reachable for non-network errors
  }
}

/// Gets a user-friendly error message based on connectivity status
String getConnectivityErrorMessage() {
  return '''
Cannot connect to email service (DNS error).

This is a network issue, not an app problem.

Common causes:
• Corporate/school firewall blocking Google Cloud
• VPN interfering with DNS resolution
• DNS server issues
• Network restrictions on googleapis.com

Solutions:
1. Try a different network (mobile hotspot)
2. Disable VPN temporarily
3. Restart your router/modem
4. Use Google DNS (8.8.8.8, 8.8.4.4)
5. Contact IT support if on corporate network

The staff account was created successfully.
You can resend the email later from Staff List.
''';
}
