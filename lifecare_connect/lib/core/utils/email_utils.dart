import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendAccountRejectedEmail(
  String email,
  String name,
  String reason,
) async {
  const String endpointUrl =
      'https://us-central1-lifecare-connect.cloudfunctions.net/sendAccountRejectedEmail';
  final response = await http.post(
    Uri.parse(endpointUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'name': name, 'reason': reason}),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to send rejection email: [${response.body}');
  }
}

Future<void> sendAccountApprovedEmail(String email, String name) async {
  const String endpointUrl =
      'https://us-central1-lifecare-connect.cloudfunctions.net/sendAccountApprovedEmail';
  final response = await http.post(
    Uri.parse(endpointUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'name': name}),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to send approval email: ${response.body}');
  }
}
