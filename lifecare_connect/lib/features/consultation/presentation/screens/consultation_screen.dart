import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  const ConsultationScreen({super.key, required this.channelName, this.isVideo = true});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final String appId = 'a105462abb1746fc9075e6c2f81f5ac5';
  // TODO: Set this to your deployed token server URL for production
  final String tokenServerUrl = 'https://YOUR_DEPLOYED_TOKEN_SERVER_URL';
  RtcEngine? _engine;
  bool _joined = false;
  final List<int> _remoteUids = [];

  Future<String?> _fetchAgoraToken(String channelName) async {
    final url = Uri.parse('$tokenServerUrl/agora-token?channelName=$channelName&uid=0');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final token = jsonDecode(response.body)['token'];
        if (token == null || token.isEmpty) {
          throw Exception('Token is null or empty');
        }
        return token;
      } else {
        throw Exception('Failed to fetch Agora token: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Token fetch error: $e');
      setState(() {
        _agoraError = 'Failed to fetch Agora token: $e';
      });
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  String? _agoraError;
  Future<void> _initAgora() async {
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int uid) {
            setState(() {
              _joined = true;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              _remoteUids.add(remoteUid);
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            setState(() {
              _remoteUids.remove(remoteUid);
            });
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('Agora error: $err, $msg');
            setState(() {
              _agoraError = 'Agora error: $err, $msg';
            });
          },
        ),
      );
      await engine.enableVideo();
      final token = await _fetchAgoraToken(widget.channelName);
      if (token == null || token.isEmpty) {
        setState(() {
          _engine = null;
          _agoraError = 'Agora token is null or empty. Check your token server.';
        });
        return;
      }
      await engine.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
      setState(() {
        _engine = engine;
      });
    } catch (e, stack) {
      debugPrint('Agora initialization error: $e\n$stack');
      setState(() {
        _engine = null;
        _agoraError = 'Agora initialization error: $e';
      });
    }
  }

  @override
  void dispose() {
    if (_engine != null) {
      _engine!.leaveChannel();
      _engine!.release();
    }
    super.dispose();
  }

  Widget _buildWebCallUI() {
    if (_agoraError != null) {
      return Center(child: Text(_agoraError!, style: TextStyle(color: Colors.red)));
    }
    if (_engine == null) {
      return Center(child: Text('Failed to initialize Agora. Please try again later.'));
    }
    if (!_joined) {
      return Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Center(
          child: _engine != null
              ? AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                )
              : Container(),
        ),
        ..._remoteUids.map((uid) => Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: 120,
            height: 120,
            child: _engine != null
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine!,
                      canvas: VideoCanvas(uid: uid),
                      connection: RtcConnection(channelId: widget.channelName),
                    ),
                  )
                : Container(),
          ),
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Consultation'), backgroundColor: Colors.teal),
      body: _buildWebCallUI(),
    );
  }
}
