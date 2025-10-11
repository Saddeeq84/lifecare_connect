import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../../../shared/data/services/agora_token_service.dart';

class ConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  const ConsultationScreen({
    super.key,
    required this.channelName,
    this.isVideo = true,
  });

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  // Production credentials for Agora
  final String appId =
      'a105462abb1746fc9075e6c2f81f5ac5'; // TODO: Move to secure config if needed
  RtcEngine? _engine;
  // int? _localUid; // Not used, remove
  bool _joined = false;
  bool _loading = true;
  String? _error;
  String? _token;
  final List<int> _remoteUids = [];

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    try {
      final int localUid = DateTime.now().millisecondsSinceEpoch % 1000000;
      // Fetch token from token server
      final token = await _fetchAgoraToken(widget.channelName, localUid);
      if (token == null) {
        setState(() {
          _error = 'Failed to fetch Agora token.';
          _loading = false;
        });
        return;
      }
      _token = token;
      _engine = createAgoraRtcEngine();
      if (_engine == null) {
        setState(() {
          _error = 'Failed to create Agora engine.';
          _loading = false;
        });
        return;
      }
      await _engine!.initialize(RtcEngineContext(appId: appId));
      _addAgoraEventHandlers();
      if (widget.isVideo) {
        await _engine!.enableVideo();
      } else {
        await _engine!.disableVideo();
      }
      await _engine!.joinChannel(
        token: _token ?? '',
        channelId: widget.channelName,
        uid: localUid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      setState(() {
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('Agora initialization error: $e\n$stack');
      setState(() {
        _error = 'Agora initialization error: $e';
        _loading = false;
      });
    }
  }

  Future<String?> _fetchAgoraToken(String channelName, int uid) async {
    return await AgoraTokenService.fetchToken(
      channelName: channelName,
      uid: uid,
      role: 'publisher',
      expireTime: 3600,
    );
  }

  void _addAgoraEventHandlers() {
    _engine?.registerEventHandler(
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
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              setState(() {
                _remoteUids.remove(remoteUid);
              });
            },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          setState(() {
            _joined = false;
            _remoteUids.clear();
          });
        },
      ),
    );
  }

  // ...existing code...

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Widget _buildVideoView() {
    if (!_joined) {
      return const Center(child: Text('Waiting to join channel...'));
    }
    List<Widget> views = [];
    if (widget.isVideo) {
      views.add(
        AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(
              uid: 0,
              renderMode: RenderModeType.renderModeHidden,
            ),
          ),
        ),
      );
      for (final uid in _remoteUids) {
        views.add(
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(
                uid: uid,
                renderMode: RenderModeType.renderModeHidden,
              ),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          ),
        );
      }
    } else {
      views.add(
        const Center(child: Icon(Icons.mic, size: 80, color: Colors.teal)),
      );
    }
    return GridView.count(
      crossAxisCount: views.length > 1 ? 2 : 1,
      children: views,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation'),
        backgroundColor: Colors.teal,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _buildVideoView(),
      floatingActionButton: _loading || _error != null
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'mic',
                  onPressed: () async {
                    // Toggle mute state (no direct getter, so just toggle and rely on UI feedback)
                    await _engine?.muteLocalAudioStream(true);
                    setState(() {});
                  },
                  tooltip: 'Mute Microphone',
                  child: const Icon(Icons.mic),
                ),
                const SizedBox(width: 12),
                if (widget.isVideo)
                  FloatingActionButton(
                    heroTag: 'camera',
                    onPressed: () async {
                      await _engine?.muteLocalVideoStream(true);
                      setState(() {});
                    },
                    tooltip: 'Mute Camera',
                    child: const Icon(Icons.videocam),
                  ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'leave',
                  backgroundColor: Colors.red,
                  onPressed: () async {
                    await _engine?.leaveChannel();
                    if (mounted) Navigator.of(context).pop();
                  },
                  tooltip: 'Leave Call',
                  child: const Icon(Icons.call_end),
                ),
              ],
            ),
    );
  }
}
