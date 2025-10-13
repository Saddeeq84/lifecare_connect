// Implementation for web
import 'dart:html' as html;

void openWebCallPage({String? channelName, String? uid, bool isVideo = true}) {
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
  
  if (params.isNotEmpty) {
    url += '?${params.join('&')}';
  }
  
  html.window.open(url, '_blank');
}
