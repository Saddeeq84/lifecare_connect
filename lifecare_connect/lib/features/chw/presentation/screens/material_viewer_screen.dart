// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';

class MaterialViewerScreen extends StatelessWidget {
  final String url;
  final String type;

  const MaterialViewerScreen({
    super.key,
    required this.url,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Training Viewer"),
        backgroundColor: Colors.teal,
      ),
      body: type == 'pdf'
          ? SfPdfViewer.network(url)
          : type == 'video'
          ? VideoPlayerWidget(videoUrl: url)
          : Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (await canLaunchUrl(Uri.parse(url))) {
                    launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ Cannot open URL')),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text("Open in Browser"),
              ),
            ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: GestureDetector(
                  onTap: () => setState(() => _showControls = !_showControls),
                  child: VideoPlayer(_controller),
                ),
              ),
              if (_showControls)
                Container(
                  color: Colors.black26,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                    ],
                  ),
                ),
            ],
          )
        : const Center(child: CircularProgressIndicator());
  }
}
