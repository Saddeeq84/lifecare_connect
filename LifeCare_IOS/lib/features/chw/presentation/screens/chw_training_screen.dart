// ignore_for_file: avoid_print, prefer_const_constructors, avoid_function_literals_in_foreach_calls

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ...existing code...
import 'package:video_player/video_player.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
// ...existing code...
import 'dart:io';
import 'dart:async';

class CHWTrainingScreen extends StatefulWidget {
  const CHWTrainingScreen({super.key});

  @override
  State<CHWTrainingScreen> createState() => _CHWTrainingScreenState();
}

class _CHWTrainingScreenState extends State<CHWTrainingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, bool> _downloadingFiles = {};
  bool _showAllVideos = false;
  bool _showAllMaterials = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // ...existing code...
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Get training resources filtered by type
  Stream<QuerySnapshot> _getResourcesStream(String type) {
    print('🔍 Loading training materials for type: $type');
    return FirebaseFirestore.instance
        .collection('training_materials')
        .where('targetRole', isEqualTo: 'chw')
        .where('type', isEqualTo: type)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  /// Launch video URL in browser or video player
  Future<void> _playVideo(String url, String title) async {
    // Play video inline using video_player in a dialog
    try {
      if (_videoController != null) {
        await _videoController!.dispose();
      }
      _videoController = VideoPlayerController.network(url);
      await _videoController!.initialize();
      setState(() {});
      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing video: $e')));
      }
    }
  }

  /// Download and open PDF file
  Future<void> _downloadAndOpenPdf(
    String url,
    String fileName,
    String docId,
  ) async {
    // ...existing code...
    // View PDF inline using syncfusion_flutter_pdfviewer in a dialog
    setState(() => _downloadingFiles[docId] = true);
    try {
      if (kIsWeb) {
        // On web, open PDF in new tab
        if (mounted) {
          // Update download count with user tracking
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            FirebaseFirestore.instance.collection('user_activities').add({
              'userId': userId,
              'action': 'download',
              'category': 'training_material',
              'materialId': docId,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
          FirebaseFirestore.instance
              .collection('training_materials')
              .doc(docId)
              .update({'downloadCount': FieldValue.increment(1)});
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      } else {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final Directory tempDir = await getTemporaryDirectory();
          final String filePath = '${tempDir.path}/$fileName';
          final File file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          // Update download count with user tracking
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            FirebaseFirestore.instance.collection('user_activities').add({
              'userId': userId,
              'action': 'download',
              'category': 'training_material',
              'materialId': docId,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
          FirebaseFirestore.instance
              .collection('training_materials')
              .doc(docId)
              .update({'downloadCount': FieldValue.increment(1)});
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text(fileName),
                  content: SizedBox(
                    width: 400,
                    height: 500,
                    child: SfPdfViewer.file(file),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to load PDF file')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading PDF: $e')));
      }
    } finally {
      setState(() => _downloadingFiles[docId] = false);
    }
  }

  /// Build resource list for videos or materials
  Widget _buildResourceList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getResourcesStream(type),
      builder: (context, snapshot) {
        print(
          '📱 StreamBuilder for $type - State: ${snapshot.connectionState}',
        );
        print('📱 Has data: ${snapshot.hasData}');
        print('📱 Has error: ${snapshot.hasError}');

        if (snapshot.hasData) {
          print('📱 Documents count for $type: ${snapshot.data!.docs.length}');
          snapshot.data!.docs.forEach((doc) {
            final data = doc.data() as Map<String, dynamic>;
            print(
              '📱 Document: ${data['title']} (${data['type']}) - Active: ${data['isActive']}',
            );
          });
        }

        if (snapshot.hasError) {
          print('📱 Firestore error for $type: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading training materials'),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('📱 Showing loading indicator for $type');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading $type materials...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('📱 No data or empty docs for $type');
          return _buildEmptyState(type);
        }

        final resources = snapshot.data!.docs;
        const showMax = 3;
        bool showAll = type == 'video' ? _showAllVideos : _showAllMaterials;
        final showList = showAll
            ? resources
            : (resources.length > showMax
                  ? resources.sublist(0, showMax)
                  : resources);

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
                      : _buildMaterialCard(data, doc.id);
                },
              ),
            ),
            if (!showAll && resources.length > showMax)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: type == 'video'
                          ? Colors.red
                          : Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (type == 'video') {
                          _showAllVideos = true;
                        } else {
                          _showAllMaterials = true;
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
            type == 'video' ? Icons.video_library : Icons.description,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 24),
          Text(
            type == 'video' ? 'No Training Videos' : 'No Training Materials',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            type == 'video'
                ? 'Training videos will appear here when\nadmin uploads them for CHWs.'
                : 'Training materials and documents will\nappear here when admin uploads them.',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // ...existing code...
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.red,
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
                          'Uploaded: ${_formatDate(uploadedAt.toDate())}',
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
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Watch Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
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

  /// Build material (PDF) card
  Widget _buildMaterialCard(Map<String, dynamic> data, String docId) {
    final title = data['title'] ?? 'Untitled Document';
    final description = data['description'] ?? 'No description';
    final uploadedAt = data['uploadedAt'] as Timestamp?;
    final fileName = data['fileName'] ?? 'document.pdf';
    final downloadCount = data['downloadCount'] ?? 0;
    final isDownloading = _downloadingFiles[docId] ?? false;

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
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.teal,
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
                          'Uploaded: ${_formatDate(uploadedAt.toDate())}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      if (downloadCount > 0)
                        Text(
                          'Downloaded $downloadCount times',
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
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(isDownloading ? 'Loading...' : 'Read'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: isDownloading
                    ? null
                    : () => _downloadAndOpenPdf(
                        data['url'] ?? '',
                        fileName,
                        docId,
                      ),
              ),
            ),
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
        title: const Text('CHW Training'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.video_library), text: 'Training Videos'),
            Tab(icon: Icon(Icons.description), text: 'Training Materials'),
            Tab(icon: Icon(Icons.help_outline), text: 'Help Videos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildResourceList('video'),
          _buildResourceList('pdf'),
          _buildHelpVideosTab(),
        ],
      ),
    );
  }

  /// Build help videos tab for CHW-specific tutorial videos
  Widget _buildHelpVideosTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('help_videos')
          .where('targetUsers', arrayContains: 'chw')
          .where('isActive', isEqualTo: true)
          .orderBy('category')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.help_outline, size: 80, color: Colors.grey),
                SizedBox(height: 24),
                Text(
                  'No Help Videos Available',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Help videos for CHW training will appear here.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final videos = snapshot.data!.docs;

        // Group videos by category
        final Map<String, List<QueryDocumentSnapshot>> groupedVideos = {};
        for (var video in videos) {
          final category = video['category'] ?? 'general';
          if (!groupedVideos.containsKey(category)) {
            groupedVideos[category] = [];
          }
          groupedVideos[category]!.add(video);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedVideos.keys.length,
          itemBuilder: (context, index) {
            final category = groupedVideos.keys.elementAt(index);
            final categoryVideos = groupedVideos[category]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0) const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Text(
                    _formatCategoryName(category),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...categoryVideos.map((video) {
                  final data = video.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: data['thumbnailUrl'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  data['thumbnailUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.teal,
                                      size: 32,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.play_circle_outline,
                                color: Colors.teal,
                                size: 32,
                              ),
                      ),
                      title: Text(
                        data['title'] ?? 'Untitled Video',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            data['description'] ?? 'No description available',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                data['duration'] ?? 'Unknown duration',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.visibility,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${data['viewCount'] ?? 0} views',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.teal,
                        size: 32,
                      ),
                      onTap: () =>
                          _playHelpVideo(data['videoUrl'], data['title']),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  /// Format category name for display
  String _formatCategoryName(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Play help video
  void _playHelpVideo(String? videoUrl, String? title) {
    if (videoUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video URL not available')));
      return;
    }

    // Use the existing video playing logic
    _playVideo(videoUrl, title ?? 'Help Video');
  }
}
