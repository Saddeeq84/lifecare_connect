import 'package:http/http.dart' as http;
import 'dart:convert';

/// Sends email notification to admin when a new user registers requiring approval
Future<void> sendAdminNewUserNotification({
  required String email,
  required String name,
  required String role,
  required String userId,
}) async {
  const String endpointUrl =
      'https://us-central1-lifecare-connect.cloudfunctions.net/sendAdminNewUserNotification';

  final registrationDate = DateTime.now().toString().split(
    '.',
  )[0]; // Remove microseconds

  try {
    final response = await http.post(
      Uri.parse(endpointUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'name': name,
        'role': role,
        'userId': userId,
        'registrationDate': registrationDate,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send admin notification: ${response.body}');
    }
  } catch (e) {
    // Don't throw - notification failure shouldn't block registration
  }
}

/// Sends email notification to admin when a service provider requests withdrawal
Future<void> sendAdminWithdrawalNotification({
  required String userId,
  required String userName,
  required String userEmail,
  required String role,
  required double amount,
  required String bankName,
  required String accountNumber,
  required String accountName,
  required String withdrawalId,
}) async {
  const String endpointUrl =
      'https://us-central1-lifecare-connect.cloudfunctions.net/sendAdminWithdrawalNotification';

  final requestDate = DateTime.now().toString().split(
    '.',
  )[0]; // Remove microseconds

  try {
    final response = await http.post(
      Uri.parse(endpointUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'role': role,
        'amount': amount,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'requestDate': requestDate,
        'withdrawalId': withdrawalId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to send admin withdrawal notification: ${response.body}',
      );
    }
  } catch (e) {
    // Don't throw - notification failure shouldn't block withdrawal request
  }
}
