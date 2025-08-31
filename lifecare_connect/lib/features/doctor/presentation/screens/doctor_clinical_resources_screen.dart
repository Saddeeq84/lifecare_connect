import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'file_opener_stub.dart'
  if (dart.library.io) 'file_opener_io.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class DoctorClinicalResourcesScreen extends StatefulWidget {
  const DoctorClinicalResourcesScreen({super.key});

  @override
  State<DoctorClinicalResourcesScreen> createState() => _DoctorClinicalResourcesScreenState();
}

class _DoctorClinicalResourcesScreenState extends State<DoctorClinicalResourcesScreen> with SingleTickerProviderStateMixin {
      late TabController _tabController;
      final Map<String, bool> _downloadingFiles = {};
      bool _showAllVideos = false;
      bool _showAllMaterials = false;

      @override
      void initState() {
        super.initState();
        _tabController = TabController(length: 2, vsync: this);
      }

      Stream<QuerySnapshot> _getResourcesStream(String type) {
  // Use the same structure as CHW and shared service
  return FirebaseFirestore.instance
    .collection('training_materials')
    .where('targetRole', isEqualTo: 'doctor')
    .where('type', isEqualTo: type)
    .where('isActive', isEqualTo: true)
    .orderBy('uploadedAt', descending: true)
    .snapshots();
}

  Future<void> _downloadAndOpenPdf(String url, String fileName, String docId) async {
    setState(() => _downloadingFiles[docId] = true);
    try {
      String downloadUrl = url;
      // If the url is a Firebase Storage reference (gs://), get the download URL
      if (url.startsWith('gs://')) {
        final ref = FirebaseStorage.instance.refFromURL(url);
        downloadUrl = await ref.getDownloadURL();
      }
      if (kIsWeb) {
        // On web, show a message that download is not supported in mobile build
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Web download is not supported in mobile build.')),
          );
        }
      } else {
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200) {
          final dir = await getApplicationDocumentsDirectory();
          final filePath = '${dir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          await openFile(filePath); // Uses platform-specific file opener
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Downloaded and opened $fileName')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to download PDF.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _downloadingFiles[docId] = false);
    }
  }

  void _playVideoInline(String url, String title) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video URL is missing.')),
      );
      return;
    }
    VideoPlayerController controller = VideoPlayerController.network(url);
    await controller.initialize();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(8),
          content: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.pause();
                controller.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            IconButton(
              icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
                setState(() {});
              },
            ),
          ],
        );
      },
    );
  }

      String _formatDate(DateTime date) {
        return '${date.day}/${date.month}/${date.year}';
      }

      Widget _buildEmptyState(String type) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                type == 'video' ? Icons.video_library : Icons.description,
                size: 80,
                color: Colors.grey
              ),
              const SizedBox(height: 24),
              Text(
                type == 'video' ? 'No Training Videos' : 'No Clinical Materials',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey
                ),
              ),
              const SizedBox(height: 16),
              Text(
                type == 'video'
                    ? 'Training videos will appear here when\nadmin uploads them for doctors.'
                    : 'Clinical materials and documents will\nappear here when admin uploads them.',
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
                        color: Colors.red.withOpacity(0.1),
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
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _playVideoInline(data['url'] ?? '', title),
                  ),
                ),
              ],
            ),
          ),
        );
      }

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
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf,
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
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(isDownloading ? 'Downloading...' : 'Download & Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isDownloading 
                        ? null
                        : () => _downloadAndOpenPdf(data['url'] ?? '', fileName, docId),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Clinical Resources'),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(
                  icon: Icon(Icons.video_library),
                  text: 'Training Videos',
                ),
                Tab(
                  icon: Icon(Icons.description),
                  text: 'Clinical Materials',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Training Videos Tab
              StreamBuilder<QuerySnapshot>(
                stream: _getResourcesStream('video'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState('video');
                  }
                  final resources = snapshot.data!.docs;
                  final showMax = 3;
                  final showList = _showAllVideos ? resources : (resources.length > showMax ? resources.sublist(0, showMax) : resources);
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: showList.length,
                          itemBuilder: (context, index) {
                            final doc = showList[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildVideoCard(data, doc.id);
                          },
                        ),
                      ),
                      if (!_showAllVideos && resources.length > showMax)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white
                              ),
                              onPressed: () {
                                setState(() {
                                  _showAllVideos = true;
                                });
                              },
                              child: const Text('Watch More'),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              // Clinical Materials Tab
              StreamBuilder<QuerySnapshot>(
                stream: _getResourcesStream('pdf'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState('pdf');
                  }
                  final resources = snapshot.data!.docs;
                  final showMax = 3;
                  final showList = _showAllMaterials ? resources : (resources.length > showMax ? resources.sublist(0, showMax) : resources);
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: showList.length,
                          itemBuilder: (context, index) {
                            final doc = showList[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildMaterialCard(data, doc.id);
                          },
                        ),
                      ),
                      if (!_showAllMaterials && resources.length > showMax)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white
                              ),
                              onPressed: () {
                                setState(() {
                                  _showAllMaterials = true;
                                });
                              },
                              child: const Text('Read More'),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      }
  }
