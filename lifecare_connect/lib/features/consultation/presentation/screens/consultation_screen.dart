import 'dart:async';
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
  
  // Call timer and microphone state
  DateTime? _callStartTime;
  Timer? _callTimer;
  String _callDuration = '00:00:00';
  bool _isMuted = false;
  bool _isVideoMuted = false;
  static const int _maxCallDurationMinutes = 60;

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
          _startCallTimer();
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
          _stopCallTimer();
        },
      ),
    );
  }

  void _startCallTimer() {
    _callStartTime = DateTime.now();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callStartTime != null) {
        final elapsed = DateTime.now().difference(_callStartTime!);
        final hours = elapsed.inHours;
        final minutes = elapsed.inMinutes % 60;
        final seconds = elapsed.inSeconds % 60;
        
        setState(() {
          _callDuration = '${hours.toString().padLeft(2, '0')}:'
                        '${minutes.toString().padLeft(2, '0')}:'
                        '${seconds.toString().padLeft(2, '0')}';
        });

        // Auto-end call after 1 hour
        if (elapsed.inMinutes >= _maxCallDurationMinutes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call duration limit (1 hour) reached. Ending call.'),
              backgroundColor: Colors.orange,
            ),
          );
          _leaveCall();
        }
      }
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    _callStartTime = null;
    setState(() {
      _callDuration = '00:00:00';
    });
  }

  Future<void> _toggleMicrophone() async {
    try {
      await _engine?.muteLocalAudioStream(_isMuted);
      setState(() {
        _isMuted = !_isMuted;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle microphone: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleCamera() async {
    try {
      await _engine?.muteLocalVideoStream(_isVideoMuted);
      setState(() {
        _isVideoMuted = !_isVideoMuted;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle camera: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveCall() async {
    _stopCallTimer();
    await _engine?.leaveChannel();
    if (mounted) Navigator.of(context).pop();
  }

  // ...existing code...

  @override
  void dispose() {
    _stopCallTimer();
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
        bottom: _joined ? PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  _callDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ) : null,
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
                  backgroundColor: _isMuted ? Colors.red : Colors.teal,
                  onPressed: _toggleMicrophone,
                  tooltip: _isMuted ? 'Unmute Microphone' : 'Mute Microphone',
                  child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                ),
                const SizedBox(width: 12),
                if (widget.isVideo)
                  FloatingActionButton(
                    heroTag: 'camera',
                    backgroundColor: _isVideoMuted ? Colors.red : Colors.teal,
                    onPressed: _toggleCamera,
                    tooltip: _isVideoMuted ? 'Turn On Camera' : 'Turn Off Camera',
                    child: Icon(_isVideoMuted ? Icons.videocam_off : Icons.videocam),
                  ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'leave',
                  backgroundColor: Colors.red,
                  onPressed: _leaveCall,
                  tooltip: 'Leave Call',
                  child: const Icon(Icons.call_end),
                ),
              ],
            ),
    );
  }
}
