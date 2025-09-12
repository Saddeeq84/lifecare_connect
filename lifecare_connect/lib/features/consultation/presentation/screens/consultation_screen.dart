import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
// Only import Agora for mobile platforms

class ConsultationScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  const ConsultationScreen({super.key, required this.channelName, this.isVideo = true});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  static const String appId = 'YOUR_AGORA_APP_ID';
  // Only declare _engine for mobile
  // ignore: unused_field
  late dynamic _engine;
  final bool _joined = false;
  int? _localUid;
  final List<int> _remoteUids = [];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _initAgora();
    }
  }

  Future<void> _initAgora() async {
  // Only run Agora logic for mobile
  // ...existing code...
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Consultation'), backgroundColor: Colors.teal),
      body: Platform.isAndroid || Platform.isIOS
          ? (_joined
              ? Center(child: Text('Video/Audio Call in progress...'))
              : Center(child: CircularProgressIndicator()))
          : Center(
              child: ElevatedButton(
                child: Text('Start Video/Audio Call'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Not Supported'),
                      content: Text('Video/Audio calls are currently only available on the mobile app.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
