// Stub for web: prevents Agora code from being used on web builds
class RtcEngine {}
class RtcEngineContext {
  RtcEngineContext({required String appId});
}
class RtcEngineEventHandler {
  RtcEngineEventHandler({Function? onJoinChannelSuccess, Function? onUserJoined, Function? onUserOffline});
}
class RtcConnection {}
enum UserOfflineReasonType { quit }
class ChannelMediaOptions {}
RtcEngine createAgoraRtcEngine() => RtcEngine();
