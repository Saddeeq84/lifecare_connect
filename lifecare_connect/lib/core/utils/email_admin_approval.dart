

import 'package:http/http.dart' as http;
import 'dart:convert';

/// Sends an admin approval required email by calling your backend/cloud function endpoint.
///
/// You must manually implement the backend endpoint (e.g., Firebase Cloud Function or REST API)
/// that actually sends the email. Replace the URL below with your deployed endpoint.
Future<void> sendAdminApprovalRequiredEmail(String email, String name) async {
  // Updated to use deployed Firebase Cloud Function endpoint
  const String endpointUrl = 'https://us-central1-lifecare-connect.cloudfunctions.net/sendAdminApprovalEmail';

  final response = await http.post(
    Uri.parse(endpointUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'name': name}),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to send admin approval email: \\${response.body}');
  }
}
