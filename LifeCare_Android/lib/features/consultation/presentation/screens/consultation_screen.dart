import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/data/services/agora_token_service.dart';
import '../../../shared/data/services/message_service.dart';
import '../../../shared/presentation/screens/chat_screen.dart';

class ConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  final String? appointmentId;
  final String? otherParticipantId;
  final String? otherParticipantName;
  final String? otherParticipantRole;

  const ConsultationScreen({
    super.key,
    required this.channelName,
    this.isVideo = true,
    this.appointmentId,
    this.otherParticipantId,
    this.otherParticipantName,
    this.otherParticipantRole,
  });

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  // Production credentials for Agora
  static const String agoraAppId = 'a105462abb1746fc9075e6c2f81f5ac5';
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

  // Chat state
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeChat();
  }

  Future<void> _requestPermissions() async {
    try {
      // Check current permission status first
      PermissionStatus cameraStatus = await Permission.camera.status;
      PermissionStatus micStatus = await Permission.microphone.status;

      // If any permission is permanently denied, show settings dialog
      if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
        setState(() {
          _error =
              'Permissions permanently denied. Please enable them in app settings.';
          _loading = false;
        });
        _showPermissionSettingsDialog();
        return;
      }

      // Request camera and microphone permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      // Check if permissions are granted
      bool cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      bool micGranted = statuses[Permission.microphone]?.isGranted ?? false;

      if (!cameraGranted || !micGranted) {
        // Check if denied permanently after request
        bool cameraPermanentlyDenied =
            statuses[Permission.camera]?.isPermanentlyDenied ?? false;
        bool micPermanentlyDenied =
            statuses[Permission.microphone]?.isPermanentlyDenied ?? false;

        if (cameraPermanentlyDenied || micPermanentlyDenied) {
          setState(() {
            _error =
                'Permissions are required but were permanently denied. Please enable them in settings.';
            _loading = false;
          });
          _showPermissionSettingsDialog();
        } else {
          setState(() {
            _error =
                'Camera and microphone permissions are required for video calls. Please grant permissions to continue.';
            _loading = false;
          });
          _showPermissionRetryDialog();
        }
        return;
      }

      // Permissions granted, proceed with Agora initialization
      _initAgora();
    } catch (e) {
      setState(() {
        _error = 'Failed to request permissions: $e';
        _loading = false;
      });
    }
  }

  void _showPermissionSettingsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Permissions Required'),
            ],
          ),
          content: const Text(
            'Camera and microphone permissions are required for video calls.\n\n'
            'Please enable them in your device settings:\n'
            '1. Open Settings\n'
            '2. Find LifeCare Connect\n'
            '3. Enable Camera and Microphone permissions',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Exit consultation screen
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
                // Exit consultation screen
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionRetryDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Text('Permissions Required'),
            ],
          ),
          content: const Text(
            'Camera and microphone access is required for video consultations.\n\n'
            'Please grant the permissions to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Exit consultation screen
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _requestPermissions(); // Retry
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initAgora() async {
    try {
      debugPrint('🎥 Starting Agora initialization...');
      debugPrint(
        '📱 Channel: ${widget.channelName}, isVideo: ${widget.isVideo}',
      );

      final int localUid = DateTime.now().millisecondsSinceEpoch % 1000000;
      debugPrint('🆔 Generated UID: $localUid');

      // Fetch token from token server
      debugPrint('🔐 Fetching Agora token...');
      final token = await _fetchAgoraToken(widget.channelName, localUid);
      if (token == null) {
        debugPrint('❌ Failed to fetch Agora token');
        setState(() {
          _error =
              'Failed to fetch Agora token. Please check your internet connection.';
          _loading = false;
        });
        return;
      }
      debugPrint('✅ Token fetched successfully');
      _token = token;

      // Create Agora engine
      debugPrint('⚙️ Creating Agora RTC engine...');
      _engine = createAgoraRtcEngine();
      final engine = _engine;
      if (engine == null) {
        debugPrint('❌ Failed to create Agora engine');
        setState(() {
          _error = 'Failed to create Agora engine. Please restart the app.';
          _loading = false;
        });
        return;
      }
      debugPrint('✅ Engine created successfully');

      // Initialize engine
      debugPrint('🔧 Initializing Agora engine with App ID: $agoraAppId');
      await engine.initialize(RtcEngineContext(appId: agoraAppId));
      debugPrint('✅ Engine initialized');

      // Register event handlers
      debugPrint('📡 Registering event handlers...');
      _addAgoraEventHandlers();

      // Enable/disable video based on call type
      if (widget.isVideo) {
        debugPrint('📹 Enabling video...');
        await engine.enableVideo();
        debugPrint('✅ Video enabled');
      } else {
        debugPrint('🔇 Disabling video (audio-only call)...');
        await engine.disableVideo();
        debugPrint('✅ Video disabled');
      }

      // Join channel
      debugPrint(
        '🚀 Joining channel: ${widget.channelName} with UID: $localUid',
      );
      await engine.joinChannel(
        token: _token ?? '',
        channelId: widget.channelName,
        uid: localUid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      debugPrint('✅ Join channel command sent');

      setState(() {
        _loading = false;
      });
      debugPrint('✅ Agora initialization complete');
    } catch (e, stackTrace) {
      debugPrint('❌ Agora initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _error =
            'Agora initialization error: $e\n\nPlease ensure:\n• Camera and microphone permissions are granted\n• Internet connection is stable\n• Try restarting the app';
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
          debugPrint(
            '✅ Successfully joined channel: ${connection.channelId} with UID: $uid',
          );
          setState(() {
            _joined = true;
          });
          _startCallTimer();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('👤 Remote user joined: $remoteUid');
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
              debugPrint('👋 Remote user left: $remoteUid, reason: $reason');
              setState(() {
                _remoteUids.remove(remoteUid);
              });
            },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('🚪 Left channel: ${connection.channelId}');
          setState(() {
            _joined = false;
            _remoteUids.clear();
          });
          _stopCallTimer();
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('❌ Agora Error: $err - $msg');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Call error: $msg'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              debugPrint(
                '🔄 Connection state changed: $state, reason: $reason',
              );
              if (state == ConnectionStateType.connectionStateFailed) {
                if (mounted) {
                  setState(() {
                    _error =
                        'Connection failed. Please check your internet connection and try again.';
                    _loading = false;
                  });
                }
              }
            },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('⚠️ Token will expire soon, renewing...');
          // Auto-renew token
          _renewToken();
        },
      ),
    );
  }

  Future<void> _renewToken() async {
    try {
      final int localUid = DateTime.now().millisecondsSinceEpoch % 1000000;
      final newToken = await _fetchAgoraToken(widget.channelName, localUid);
      if (newToken != null && _engine != null) {
        await _engine!.renewToken(newToken);
        _token = newToken;
        debugPrint('✅ Token renewed successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to renew token: $e');
    }
  }

  void _startCallTimer() {
    _callStartTime = DateTime.now();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final startTime = _callStartTime;
      if (startTime != null) {
        final elapsed = DateTime.now().difference(startTime);
        final hours = elapsed.inHours;
        final minutes = elapsed.inMinutes % 60;
        final seconds = elapsed.inSeconds % 60;

        setState(() {
          _callDuration =
              '${hours.toString().padLeft(2, '0')}:'
              '${minutes.toString().padLeft(2, '0')}:'
              '${seconds.toString().padLeft(2, '0')}';
        });

        // Auto-end call after 1 hour
        if (elapsed.inMinutes >= _maxCallDurationMinutes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Call duration limit (1 hour) reached. Ending call.',
              ),
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
    final engine = _engine;
    if (engine == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call not ready yet. Please wait...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Toggle the mute state first, then apply it
      final newMuteState = !_isMuted;
      await engine.muteLocalAudioStream(newMuteState);
      setState(() {
        _isMuted = newMuteState;
      });

      // Provide user feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isMuted ? 'Microphone muted' : 'Microphone unmuted'),
            backgroundColor: _isMuted ? Colors.red : Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
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
    final engine = _engine;
    if (engine == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call not ready yet. Please wait...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Toggle the video mute state first, then apply it
      final newVideoMuteState = !_isVideoMuted;
      await engine.muteLocalVideoStream(newVideoMuteState);
      setState(() {
        _isVideoMuted = newVideoMuteState;
      });

      // Provide user feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isVideoMuted ? 'Camera turned off' : 'Camera turned on',
            ),
            backgroundColor: _isVideoMuted ? Colors.red : Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
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
    // Show confirmation dialog
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Call'),
          content: const Text(
            'Are you sure you want to leave the call? You can rejoin if the call is still active.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Leave Call'),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true) {
      _stopCallTimer();
      await _engine?.leaveChannel();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left call successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _endCall() async {
    // Show confirmation dialog
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Call'),
          content: const Text(
            'Are you sure you want to end the call? This will close the consultation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('End Call'),
            ),
          ],
        );
      },
    );

    if (shouldEnd == true) {
      _stopCallTimer();
      await _engine?.leaveChannel();
      if (mounted) {
        Navigator.of(context).pop();
        // Optionally show a completion message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _initializeChat() async {
    if (widget.otherParticipantId == null ||
        widget.otherParticipantName == null ||
        widget.otherParticipantRole == null) {
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get current user details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final currentUserName =
          '${userData['firstName']} ${userData['lastName']}';
      final currentUserRole = userData['role'];

      // Create or get conversation
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: currentUser.uid,
        user1Name: currentUserName,
        user1Role: currentUserRole,
        user2Id: widget.otherParticipantId!,
        user2Name: widget.otherParticipantName!,
        user2Role: widget.otherParticipantRole!,
        title: 'Video Call Chat',
        type: 'consultation',
        relatedId: widget.appointmentId,
      );

      setState(() {
        _conversationId = conversationId;
      });
    } catch (e) {}
  }

  void _openChat() {
    if (_conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat not available at the moment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: _conversationId!,
          otherParticipantName: widget.otherParticipantName ?? 'Participant',
          otherParticipantRole: widget.otherParticipantRole ?? 'user',
        ),
      ),
    );
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
    if (!_joined || _engine == null) {
      return const Center(child: Text('Waiting to join channel...'));
    }

    // Additional safety check for engine
    final engine = _engine;
    if (engine == null) {
      return const Center(child: Text('Initializing call...'));
    }

    List<Widget> views = [];
    if (widget.isVideo) {
      views.add(
        AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: engine,
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
              rtcEngine: engine,
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
        bottom: _joined
            ? PreferredSize(
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
              )
            : null,
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
                    tooltip: _isVideoMuted
                        ? 'Turn On Camera'
                        : 'Turn Off Camera',
                    child: Icon(
                      _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                    ),
                  ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'chat',
                  backgroundColor: Colors.blue,
                  onPressed: _openChat,
                  tooltip: 'Open Chat',
                  child: const Icon(Icons.chat),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'end',
                  backgroundColor: Colors.red[700],
                  onPressed: _endCall,
                  tooltip: 'End Call',
                  child: const Icon(Icons.call_end),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'leave',
                  backgroundColor: Colors.orange,
                  onPressed: _leaveCall,
                  tooltip: 'Leave Call',
                  child: const Icon(Icons.exit_to_app),
                ),
              ],
            ),
    );
  }
}
