import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

Future<void> sendStaffSetupPasswordEmail({
  required String email,
  required String name,
  required String staffId,
  required String setupLink,
  int maxRetries = 2, // Reduced from 3 to 2 retries
  Duration timeout = const Duration(
    seconds: 60,
  ), // Increased to 60 seconds for cold starts
}) async {
  const url =
      'https://us-central1-lifecare-connect.cloudfunctions.net/sendStaffSetupPasswordEmail';

  int retryCount = 0;
  Exception? lastError;

  while (retryCount < maxRetries) {
    try {
      print(
        '[StaffEmail] Attempt ${retryCount + 1}/$maxRetries - Sending setup email to: $email for staff ID: $staffId',
      );

      // Use same timeout for all attempts now (20 seconds is reasonable)
      final attemptTimeout = timeout;

      print('[StaffEmail] Using timeout: ${attemptTimeout.inSeconds}s');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'name': name,
              'staffId': staffId,
              'setupLink': setupLink,
            }),
          )
          .timeout(
            attemptTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Email request timed out after ${attemptTimeout.inSeconds} seconds',
              );
            },
          );

      print('[StaffEmail] Response status: ${response.statusCode}');
      print('[StaffEmail] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print(
          '[StaffEmail] ✅ Setup email sent successfully: ${responseData['message']}',
        );
        return;
      } else {
        print('[StaffEmail] ❌ Failed with status ${response.statusCode}');
        throw Exception(
          'Failed to send setup password email: ${response.body}',
        );
      }
    } on TimeoutException catch (e) {
      lastError = Exception(
        'Network timeout: ${e.message}. The server might be slow or your connection unstable.',
      );
      print('[StaffEmail] ⏱️ Timeout error: $e');
      retryCount++;
      if (retryCount < maxRetries) {
        // Quick retry - just 2 seconds
        print('[StaffEmail] Retrying in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      // Check for specific network errors
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('failed to fetch') ||
          errorMsg.contains('name not resolved') ||
          errorMsg.contains('err_name_not_resolved') ||
          errorMsg.contains('network') ||
          errorMsg.contains('dns') ||
          errorMsg.contains('connection')) {
        lastError = Exception(
          'Network error: Cannot reach email service. Your network may be blocking Google Cloud Functions. Try a different network or disable VPN.',
        );
      } else {
        lastError = Exception('Failed to send email: ${e.toString()}');
      }

      print('[StaffEmail] ❌ Error sending email: $e');
      retryCount++;
      if (retryCount < maxRetries) {
        // Quick retry - just 2 seconds
        print('[StaffEmail] Retrying in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  // All retries failed
  print('[StaffEmail] ❌ All $maxRetries attempts failed');
  throw lastError ??
      Exception('Failed to send email after $maxRetries attempts');
}
