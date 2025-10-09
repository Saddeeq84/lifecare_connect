import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendStaffSetupPasswordEmail({required String email, required String name, required String staffId, required String setupLink}) async {
  const url = 'https://us-central1-lifecare-connect.cloudfunctions.net/sendStaffSetupPasswordEmail';
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'name': name,
      'staffId': staffId,
      'setupLink': setupLink,
    }),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to send setup password email');
  }
}
