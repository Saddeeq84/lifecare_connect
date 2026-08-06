// Implementation for web
import 'package:web/web.dart' as web;

void openWebCallPage({
  String? channelName,
  String? uid,
  bool isVideo = true,
  String? userName,
  String? userRole,
}) {
  String url = '/agora_call/index.html';
  List<String> params = [];

  if (channelName != null && channelName.isNotEmpty) {
    params.add('channelName=${Uri.encodeComponent(channelName)}');
  }

  if (uid != null && uid.isNotEmpty) {
    params.add('uid=${Uri.encodeComponent(uid)}');
  }

  // Add call type parameter
  params.add('type=${isVideo ? 'video' : 'audio'}');

  // Add user information
  if (userName != null && userName.isNotEmpty) {
    params.add('userName=${Uri.encodeComponent(userName)}');
  }

  if (userRole != null && userRole.isNotEmpty) {
    params.add('userRole=${Uri.encodeComponent(userRole)}');
  }

  if (params.isNotEmpty) {
    url += '?${params.join('&')}';
  }

  web.window.open(url, '_blank');
}
