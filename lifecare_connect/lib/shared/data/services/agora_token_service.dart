import 'dart:convert';
import 'package:http/http.dart' as http;

class AgoraTokenService {
  static const String _tokenServerUrl = 'https://your-production-token-server.com/rtcToken'; // TODO: Replace with your deployed server URL

  static Future<String?> fetchToken({
    required String channelName,
    required int uid,
    String role = 'publisher',
    int expireTime = 3600,
  }) async {
    final uri = Uri.parse('$_tokenServerUrl?channelName=$channelName&uid=$uid&role=$role&expireTime=$expireTime');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['rtcToken'] as String?;
    } else {
      return null;
    }
  }
}
