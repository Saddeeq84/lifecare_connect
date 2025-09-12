// ignore_for_file: deprecated_member_use, prefer_const_constructors, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ...existing code...
import 'package:video_player/video_player.dart';
// ...existing code...

class PatientEducationScreen extends StatefulWidget {
  const PatientEducationScreen({super.key});

  @override
  State<PatientEducationScreen> createState() => _PatientEducationScreenState();
}

class _PatientEducationScreenState extends State<PatientEducationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showAllVideos = false;
  bool _showAllHealthTips = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Now only 2 tabs
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Get patient educational content filtered by type
  Stream<QuerySnapshot> _getContentStream(String type) {
    return FirebaseFirestore.instance
        .collection('training_materials')
        .where('targetRole', isEqualTo: 'patient')
        .where('type', isEqualTo: type)
        .where('isActive', isEqualTo: true)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  /// Launch video URL in browser or video player
  Future<void> _playVideo(String url, String title) async {
    // Show video in a dialog using video_player
    try {
      if (_videoController != null) {
        await _videoController!.dispose();
      }
      _videoController = VideoPlayerController.network(url);
      await _videoController?.initialize();
      setState(() {
        // No need to assign _currentVideoUrl
      });
      if (mounted) {
        if (_videoController != null) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(title),
                content: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _videoController?.pause();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
          _videoController!.play();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video failed to load.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: $e')),
        );
      }
    }
  }

  /// Build content list for videos or health tips
  Widget _buildContentList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getContentStream(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(type);
        }

        final content = snapshot.data!.docs;
        final showMax = 3;
        bool showAll = type == 'video' ? _showAllVideos : _showAllHealthTips;
        final showList = showAll ? content : (content.length > showMax ? content.sublist(0, showMax) : content);

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: showList.length,
                itemBuilder: (context, index) {
                  final doc = showList[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return type == 'video'
                      ? _buildVideoCard(data, doc.id)
                      : _buildHealthTipCard(data, doc.id);
                },
              ),
            ),
            if (!showAll && content.length > showMax)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: type == 'video' ? Colors.blue : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (type == 'video') {
                          _showAllVideos = true;
                        } else {
                          _showAllHealthTips = true;
                        }
                      });
                    },
                    child: Text(type == 'video' ? 'Watch More' : 'Read More'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build empty state for each tab
  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == 'video' ? Icons.video_library : Icons.tips_and_updates,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 24),
          Text(
            type == 'video' ? 'No Educational Videos' : 'No Health Tips',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            type == 'video'
                ? 'Educational videos will appear here when\nadmin uploads them for patients.'
                : 'Health tips and wellness advice will\nappear here when admin posts them.',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build video card
  Widget _buildVideoCard(Map<String, dynamic> data, String docId) {
    final title = data['title'] ?? 'Untitled Video';
    final description = data['description'] ?? 'No description';
    final uploadedAt = data['uploadedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (uploadedAt != null)
                        Text(
                          'Posted: ${_formatDate(uploadedAt.toDate())}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Watch Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _playVideo(data['url'] ?? '', title),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build health tip card
  Widget _buildHealthTipCard(Map<String, dynamic> data, String docId) {
    final title = data['title'] ?? 'Health Tip';
    final description = data['description'] ?? 'No description';
    final healthTip = data['healthTip'] ?? '';
    final uploadedAt = data['uploadedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.tips_and_updates,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (uploadedAt != null)
                        Text(
                          'Posted: ${_formatDate(uploadedAt.toDate())}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (description.isNotEmpty) ...[
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (healthTip.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.green[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Health Tip',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      healthTip,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Education'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.video_library),
              text: 'Educational Videos',
            ),
            Tab(
              icon: Icon(Icons.tips_and_updates),
              text: 'Health Tips',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContentList('video'),
          _buildContentList('health_tip'),
        ],
      ),
    );
  }
}
