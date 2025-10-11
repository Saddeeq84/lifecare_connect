import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;

class CallScreen extends StatefulWidget {
	final String channelName;
	final int uid;
	final bool isVideo;
	final String tokenServerUrl;

	const CallScreen({
		Key? key,
		required this.channelName,
		required this.uid,
		required this.tokenServerUrl,
		this.isVideo = true,
	}) : super(key: key);

	@override
	State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
	late RtcEngine _engine;
	bool _joined = false;
	int? _remoteUid;
	String? _token;
	bool _loading = true;
	String? _error;

	@override
	void initState() {
		super.initState();
		_initAgora();
	}

	Future<void> _initAgora() async {
		try {
			await _fetchToken();
			_engine = createAgoraRtcEngine();
					await _engine.initialize(const RtcEngineContext(
						appId: 'a105462abb1746fc9075e6c2f81f5ac5',
					));
			_addAgoraEventHandlers();
			await _engine.enableVideo();
			await _engine.startPreview();
					if (_token == null) {
						throw Exception('Token is null after fetching.');
					}
					await _engine.joinChannel(
						token: _token!, // _token is guaranteed non-null here
						channelId: widget.channelName,
						uid: widget.uid,
						options: const ChannelMediaOptions(),
					);
			setState(() => _loading = false);
		} catch (e) {
			setState(() {
				_error = 'Failed to initialize call: $e';
				_loading = false;
			});
		}
	}

	Future<void> _fetchToken() async {
		final url = Uri.parse(
				'${widget.tokenServerUrl}?channelName=${widget.channelName}&uid=${widget.uid}');
		final response = await http.get(url);
		if (response.statusCode == 200) {
			final data = json.decode(response.body);
			setState(() {
				_token = data['token'] ?? data['rtcToken'];
			});
		} else {
			throw Exception('Failed to fetch token: ${response.body}');
		}
	}

	void _addAgoraEventHandlers() {
		_engine.registerEventHandler(
			RtcEngineEventHandler(
				onJoinChannelSuccess: (connection, elapsed) {
					setState(() => _joined = true);
				},
				onUserJoined: (connection, remoteUid, elapsed) {
					setState(() => _remoteUid = remoteUid);
				},
				onUserOffline: (connection, remoteUid, reason) {
					setState(() => _remoteUid = null);
				},
				onLeaveChannel: (connection, stats) {
					setState(() {
						_joined = false;
						_remoteUid = null;
					});
				},
			),
		);
	}

	@override
	void dispose() {
		_engine.leaveChannel();
		_engine.release();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) {
			return const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			);
		}
		if (_error != null) {
			return Scaffold(
				body: Center(child: Text(_error!)),
			);
		}
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.isVideo ? 'Video Call' : 'Audio Call'),
				actions: [
					IconButton(
						icon: const Icon(Icons.call_end, color: Colors.red),
						onPressed: () => Navigator.of(context).pop(),
					),
				],
			),
			body: Stack(
				children: [
					if (widget.isVideo && _joined)
						AgoraVideoView(
							controller: VideoViewController(
								rtcEngine: _engine,
								canvas: const VideoCanvas(uid: 0),
							),
						),
					if (_remoteUid != null && widget.isVideo)
						Align(
							alignment: Alignment.topRight,
							child: SizedBox(
								width: 120,
								height: 160,
								child: AgoraVideoView(
									controller: VideoViewController.remote(
										rtcEngine: _engine,
										canvas: VideoCanvas(uid: _remoteUid),
										connection: const RtcConnection(),
									),
								),
							),
						),
					if (!_joined)
						const Center(child: Text('Connecting to call...')),
					if (_joined && !widget.isVideo)
						Center(
							child: Icon(Icons.call, size: 100, color: Colors.green),
						),
				],
			),
		);
	}
}
