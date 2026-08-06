import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class AdminHelpVideosScreen extends StatefulWidget {
  const AdminHelpVideosScreen({super.key});

  @override
  State<AdminHelpVideosScreen> createState() => _AdminHelpVideosScreenState();
}

class _AdminHelpVideosScreenState extends State<AdminHelpVideosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStage = 'preparing'; // preparing, uploading, saving, completed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Videos Management'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddVideoDialog,
            tooltip: 'Add New Video',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('help_videos')
            .orderBy('category')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final videos = snapshot.data?.docs ?? [];

          if (videos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No help videos uploaded yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the + button to add your first help video',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              final data = video.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getCategoryColor(data['category']),
                    child: Icon(
                      _getCategoryIcon(data['category']),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(data['title'] ?? 'Untitled'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['description'] ?? ''),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Chip(
                            label: Text(
                              data['category'] ?? 'general',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: _getCategoryColor(
                              data['category'],
                            ).withOpacity(0.2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${data['duration'] ?? 'Unknown'} • ${data['viewCount'] ?? 0} views',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: data['isActive'] ?? true,
                        onChanged: (value) =>
                            _toggleVideoStatus(video.id, value),
                      ),
                      PopupMenuButton(
                        onSelected: (action) {
                          switch (action) {
                            case 'edit':
                              _showEditVideoDialog(video.id, data);
                              break;
                            case 'delete':
                              _showDeleteConfirmation(video.id, data['title']);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddVideoDialog() {
    showDialog(
      context: context,
      builder: (context) => AddHelpVideoDialog(
        onSave: _uploadVideo,
        isUploading: _isUploading,
        uploadProgress: _uploadProgress,
        uploadStage: _uploadStage,
      ),
    );
  }

  void _showEditVideoDialog(String videoId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => EditHelpVideoDialog(
        videoId: videoId,
        initialData: data,
        onSave: _updateVideo,
      ),
    );
  }

  Future<void> _uploadVideo(
    Map<String, dynamic> videoData,
    PlatformFile videoFile,
    PlatformFile? thumbnailFile,
  ) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStage = 'preparing';
    });

    try {
      print('🎬 [HELP VIDEO UPLOAD] Starting upload process...');
      print(
        '📁 [HELP VIDEO UPLOAD] Video file: ${videoFile.name}, Size: ${videoFile.size} bytes',
      );

      // Validate file size (limit to 100MB)
      if (videoFile.size > 100 * 1024 * 1024) {
        throw Exception(
          'Video file is too large. Please select a file smaller than 100MB.',
        );
      }

      // Validate video file bytes
      if (videoFile.bytes == null || videoFile.bytes!.isEmpty) {
        throw Exception(
          'Video file is corrupted or empty. Please select a different file.',
        );
      }

      // Small delay to show "Preparing upload..." state
      await Future.delayed(const Duration(milliseconds: 500));

      // Start uploading stage
      setState(() => _uploadStage = 'uploading');

      // Upload video file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoPath = 'help_videos/videos/$timestamp.mp4';
      final videoRef = _storage.ref().child(videoPath);

      print('📤 [HELP VIDEO UPLOAD] Uploading to: $videoPath');

      final uploadTask = videoRef.putData(
        videoFile.bytes!,
        SettableMetadata(
          contentType: 'video/mp4',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
          print(
            '📊 [HELP VIDEO UPLOAD] Progress: ${(_uploadProgress * 100).toInt()}%',
          );
        }
      });

      // Wait for upload to complete with timeout
      final taskSnapshot = await uploadTask.timeout(
        const Duration(minutes: 10), // 10 minute timeout
        onTimeout: () {
          throw Exception(
            'Upload timed out after 10 minutes. Please check your internet connection and try again.',
          );
        },
      );

      if (taskSnapshot.state != TaskState.success) {
        throw Exception(
          'Video upload failed with state: ${taskSnapshot.state}. Please try again.',
        );
      }

      final videoUrl = await videoRef.getDownloadURL();
      if (videoUrl.isEmpty) {
        throw Exception('Failed to get video download URL. Please try again.');
      }

      print('✅ [HELP VIDEO UPLOAD] Video uploaded successfully: $videoUrl');

      // Upload thumbnail if provided
      String? thumbnailUrl;
      if (thumbnailFile != null && thumbnailFile.bytes != null) {
        print('🖼️ [HELP VIDEO UPLOAD] Uploading thumbnail...');
        final thumbnailPath = 'help_videos/thumbnails/$timestamp.jpg';
        final thumbnailRef = _storage.ref().child(thumbnailPath);

        final thumbnailTask = await thumbnailRef.putData(
          thumbnailFile.bytes!,
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'public, max-age=31536000',
          ),
        );

        if (thumbnailTask.state == TaskState.success) {
          thumbnailUrl = await thumbnailRef.getDownloadURL();
          print(
            '✅ [HELP VIDEO UPLOAD] Thumbnail uploaded successfully: $thumbnailUrl',
          );
        } else {
          print(
            '⚠️ [HELP VIDEO UPLOAD] Thumbnail upload failed, proceeding without thumbnail',
          );
        }
      }

      // Save to Firestore
      setState(() => _uploadStage = 'saving');
      print('💾 [HELP VIDEO UPLOAD] Saving metadata to Firestore...');
      final docRef = await _firestore.collection('help_videos').add({
        ...videoData,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'viewCount': 0,
        'isActive': true,
      });

      if (docRef.id.isEmpty) {
        throw Exception('Failed to save video metadata to database.');
      }

      print(
        '✅ [HELP VIDEO UPLOAD] Metadata saved to Firestore successfully! Doc ID: ${docRef.id}',
      );

      // Mark as completed
      setState(() => _uploadStage = 'completed');

      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 800));

      // Show success and close dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close the add video dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Video uploaded successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ [HELP VIDEO UPLOAD] Upload failed: $e');
      print('🔍 [HELP VIDEO UPLOAD] Error details: ${e.toString()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upload failed: ${e.toString()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () =>
                  _uploadVideo(videoData, videoFile, thumbnailFile),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadStage = 'preparing';
        });
      }
    }
  }

  Future<void> _updateVideo(
    String videoId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection('help_videos').doc(videoId).update(updates);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleVideoStatus(String videoId, bool isActive) async {
    try {
      await _firestore.collection('help_videos').doc(videoId).update({
        'isActive': isActive,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update video status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(String videoId, String? title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: Text(
          'Are you sure you want to delete "${title ?? 'this video'}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteVideo(videoId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVideo(String videoId) async {
    try {
      // Get video data to delete storage files
      final doc = await _firestore.collection('help_videos').doc(videoId).get();
      final data = doc.data();

      if (data != null) {
        // Delete video file
        if (data['videoUrl'] != null) {
          try {
            await _storage.refFromURL(data['videoUrl']).delete();
          } catch (e) {
            print('Failed to delete video file: $e');
          }
        }

        // Delete thumbnail file
        if (data['thumbnailUrl'] != null) {
          try {
            await _storage.refFromURL(data['thumbnailUrl']).delete();
          } catch (e) {
            print('Failed to delete thumbnail file: $e');
          }
        }
      }

      // Delete Firestore document
      await _firestore.collection('help_videos').doc(videoId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'appointment_booking':
        return Colors.blue;
      case 'wallet_usage':
        return Colors.green;
      case 'emergency_procedures':
        return Colors.red;
      case 'profile_management':
        return Colors.purple;
      case 'messaging_guide':
        return Colors.orange;
      case 'chw_training':
        return Colors.teal;
      case 'doctor_resources':
        return Colors.indigo;
      case 'patient_education':
        return Colors.pink;
      case 'system_navigation':
        return Colors.brown;
      case 'troubleshooting':
        return Colors.grey;
      default:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'appointment_booking':
        return Icons.calendar_today;
      case 'wallet_usage':
        return Icons.account_balance_wallet;
      case 'emergency_procedures':
        return Icons.emergency;
      case 'profile_management':
        return Icons.person;
      case 'messaging_guide':
        return Icons.chat;
      case 'chw_training':
        return Icons.school;
      case 'doctor_resources':
        return Icons.medical_services;
      case 'patient_education':
        return Icons.health_and_safety;
      case 'system_navigation':
        return Icons.explore;
      case 'troubleshooting':
        return Icons.build;
      default:
        return Icons.help;
    }
  }
}

class AddHelpVideoDialog extends StatefulWidget {
  final Function(Map<String, dynamic>, PlatformFile, PlatformFile?) onSave;
  final bool isUploading;
  final double uploadProgress;
  final String uploadStage;

  const AddHelpVideoDialog({
    super.key,
    required this.onSave,
    required this.isUploading,
    required this.uploadProgress,
    required this.uploadStage,
  });

  @override
  State<AddHelpVideoDialog> createState() => _AddHelpVideoDialogState();
}

class _AddHelpVideoDialogState extends State<AddHelpVideoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  String _selectedCategory = 'appointment_booking';
  List<String> _selectedTargetUsers = [
    'patient',
  ]; // Start with patient as default
  PlatformFile? _selectedVideoFile;
  PlatformFile? _selectedThumbnailFile;

  final List<String> _categories = [
    'appointment_booking', // How to book appointments
    'wallet_usage', // Payment and wallet features
    'emergency_procedures', // Emergency protocols
    'profile_management', // Profile setup and editing
    'messaging_guide', // How to use messaging
    'chw_training', // CHW-specific training content
    'doctor_resources', // Doctor-specific resources
    'patient_education', // Patient health education
    'system_navigation', // General app navigation
    'troubleshooting', // Common issues and fixes
  ];

  final List<String> _userTypes = ['doctor', 'patient', 'chw', 'facility'];

  /// Helper function to format category names for display
  String _formatCategoryName(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isUploading, // Prevent dismissal during upload
      child: AlertDialog(
        title: const Text('Add Help Video'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Video Title *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(_formatCategoryName(category)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                        _updateTargetUsersForCategory(value);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (MM:SS)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 2:30',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Target Users:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    children: _userTypes.map((userType) {
                      return CheckboxListTile(
                        title: Text(userType.toUpperCase()),
                        value: _selectedTargetUsers.contains(userType),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedTargetUsers.add(userType);
                            } else {
                              _selectedTargetUsers.remove(userType);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _selectVideoFile,
                    icon: const Icon(Icons.video_file),
                    label: Text(
                      _selectedVideoFile != null
                          ? 'Video: ${_selectedVideoFile!.name}'
                          : 'Select Video File *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _selectThumbnailFile,
                    icon: const Icon(Icons.image),
                    label: Text(
                      _selectedThumbnailFile != null
                          ? 'Thumbnail: ${_selectedThumbnailFile!.name}'
                          : 'Select Thumbnail (Optional)',
                    ),
                  ),
                  if (widget.isUploading) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.blue.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade200.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header with icon and status
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.cloud_upload,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.uploadProgress > 0
                                          ? 'Uploading Video'
                                          : 'Preparing Upload',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    Text(
                                      widget.uploadProgress > 0
                                          ? '${(widget.uploadProgress * 100).toInt()}% Complete'
                                          : 'Initializing...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Circular progress indicator
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: Stack(
                                  children: [
                                    CircularProgressIndicator(
                                      strokeWidth: 4,
                                      value: widget.uploadProgress > 0
                                          ? widget.uploadProgress
                                          : null,
                                      backgroundColor: Colors.blue.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue.shade600,
                                      ),
                                    ),
                                    if (widget.uploadProgress > 0)
                                      Center(
                                        child: Text(
                                          '${(widget.uploadProgress * 100).toInt()}%',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Progress bar with enhanced styling
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Upload Progress',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  if (_selectedVideoFile != null)
                                    Text(
                                      '${(_selectedVideoFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.blue.shade200,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: widget.uploadProgress,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      widget.uploadProgress > 0.8
                                          ? Colors.green.shade600
                                          : Colors.blue.shade600,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Status message with icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  widget.uploadProgress > 0
                                      ? Icons.upload_file
                                      : Icons.hourglass_empty,
                                  color: Colors.blue.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.uploadProgress > 0
                                        ? 'Uploading your video to the cloud. Please keep this dialog open until upload completes.'
                                        : 'Preparing your video for upload. This may take a moment for large files.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade700,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Upload stages indicator
                          if (widget.uploadProgress > 0) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildUploadStage(
                                  icon: Icons.check_circle,
                                  label: 'Prepared',
                                  isActive: widget.uploadStage == 'preparing',
                                  isCompleted: [
                                    'uploading',
                                    'saving',
                                    'completed',
                                  ].contains(widget.uploadStage),
                                ),
                                _buildUploadStage(
                                  icon: Icons.cloud_upload,
                                  label: 'Uploading',
                                  isActive: widget.uploadStage == 'uploading',
                                  isCompleted: [
                                    'saving',
                                    'completed',
                                  ].contains(widget.uploadStage),
                                ),
                                _buildUploadStage(
                                  icon: Icons.save,
                                  label: 'Saving',
                                  isActive: widget.uploadStage == 'saving',
                                  isCompleted:
                                      widget.uploadStage == 'completed',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.isUploading
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: widget.isUploading ? null : _saveVideo,
            child: widget.isUploading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Uploading...'),
                    ],
                  )
                : const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        // Check if file has bytes (for web)
        if (file.bytes == null || file.bytes!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to read video file. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Check file size (max 100MB)
        if (file.size > 100 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Video file is too large. Please select a file smaller than 100MB.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        setState(() {
          _selectedVideoFile = file;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video selected: ${file.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // User cancelled or no file selected
        print('No video file selected');
      }
    } catch (e) {
      print('Error selecting video file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting video file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectThumbnailFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        // Check if file has bytes (for web)
        if (file.bytes == null || file.bytes!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to read thumbnail file. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Check file size (max 5MB for thumbnails)
        if (file.size > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Thumbnail file is too large. Please select a file smaller than 5MB.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        setState(() {
          _selectedThumbnailFile = file;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thumbnail selected: ${file.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // User cancelled or no file selected
        print('No thumbnail file selected');
      }
    } catch (e) {
      print('Error selecting thumbnail file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting thumbnail file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Smart targeting based on category selection
  void _updateTargetUsersForCategory(String category) {
    switch (category) {
      case 'appointment_booking':
      case 'patient_education':
        _selectedTargetUsers = ['patient'];
        break;
      case 'doctor_resources':
        _selectedTargetUsers = ['doctor'];
        break;
      case 'chw_training':
        _selectedTargetUsers = ['chw'];
        break;
      case 'emergency_procedures':
        _selectedTargetUsers = ['doctor', 'chw', 'facility'];
        break;
      case 'wallet_usage':
      case 'messaging_guide':
      case 'profile_management':
        _selectedTargetUsers = ['doctor', 'patient', 'chw'];
        break;
      case 'system_navigation':
      case 'troubleshooting':
        _selectedTargetUsers = ['doctor', 'patient', 'chw', 'facility'];
        break;
      default:
        _selectedTargetUsers = ['patient'];
    }
  }

  void _saveVideo() {
    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate video file selection
    if (_selectedVideoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Please select a video file'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate target users selection
    if (_selectedTargetUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Please select at least one target user type'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog before uploading
    _showUploadConfirmationDialog();
  }

  void _showUploadConfirmationDialog() {
    final fileSize = (_selectedVideoFile!.size / (1024 * 1024)).toStringAsFixed(
      1,
    );
    final targetUsersText = _selectedTargetUsers.join(', ').toUpperCase();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload_file, color: Colors.blue),
            SizedBox(width: 8),
            Text('Confirm Video Upload'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You are about to upload the following help video:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Title: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(_titleController.text.trim())),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_selectedCategory.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Target Users: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(targetUsersText)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'File: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(_selectedVideoFile!.name)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Size: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('$fileSize MB'),
                      ],
                    ),
                    if (_durationController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Duration: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_durationController.text.trim()),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This video will be uploaded to Firebase Storage and made available to the selected user types. The upload may take several minutes depending on file size.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.isUploading
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: widget.isUploading
                ? null
                : () {
                    Navigator.of(context).pop(); // Close confirmation dialog
                    _proceedWithUpload();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: widget.isUploading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Uploading...'),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_upload, size: 18),
                      SizedBox(width: 8),
                      Text('Proceed with Upload'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _proceedWithUpload() {
    final videoData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'targetUsers': _selectedTargetUsers,
      'duration': _durationController.text.trim().isNotEmpty
          ? _durationController.text.trim()
          : null,
      'order': 0, // Will be updated when reordering is implemented
    };

    // Call the upload function
    widget.onSave(videoData, _selectedVideoFile!, _selectedThumbnailFile);
  }

  /// Build upload stage indicator widget
  Widget _buildUploadStage({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color iconColor;
    Color textColor;

    if (isCompleted) {
      iconColor = Colors.green.shade600;
      textColor = Colors.green.shade700;
    } else if (isActive) {
      iconColor = Colors.blue.shade600;
      textColor = Colors.blue.shade700;
    } else {
      iconColor = Colors.grey.shade400;
      textColor = Colors.grey.shade500;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? (isCompleted ? Colors.green.shade100 : Colors.blue.shade100)
                : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive || isCompleted
                  ? (isCompleted ? Colors.green.shade300 : Colors.blue.shade300)
                  : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check_circle : icon,
            color: iconColor,
            size: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}

class EditHelpVideoDialog extends StatefulWidget {
  final String videoId;
  final Map<String, dynamic> initialData;
  final Function(String, Map<String, dynamic>) onSave;

  const EditHelpVideoDialog({
    super.key,
    required this.videoId,
    required this.initialData,
    required this.onSave,
  });

  @override
  State<EditHelpVideoDialog> createState() => _EditHelpVideoDialogState();
}

class _EditHelpVideoDialogState extends State<EditHelpVideoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;
  late String _selectedCategory;
  late List<String> _selectedTargetUsers;

  final List<String> _categories = [
    'appointment_booking', // How to book appointments
    'wallet_usage', // Payment and wallet features
    'emergency_procedures', // Emergency protocols
    'profile_management', // Profile setup and editing
    'messaging_guide', // How to use messaging
    'chw_training', // CHW-specific training content
    'doctor_resources', // Doctor-specific resources
    'patient_education', // Patient health education
    'system_navigation', // General app navigation
    'troubleshooting', // Common issues and fixes
  ];

  final List<String> _userTypes = ['doctor', 'patient', 'chw', 'facility'];

  /// Helper function to format category names for display
  String _formatCategoryName(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialData['title'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialData['description'] ?? '',
    );
    _durationController = TextEditingController(
      text: widget.initialData['duration'] ?? '',
    );
    _selectedCategory = widget.initialData['category'] ?? 'general';
    _selectedTargetUsers = List<String>.from(
      widget.initialData['targetUsers'] ??
          ['doctor', 'patient', 'chw', 'facility'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Help Video'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Video Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_formatCategoryName(category)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                      _updateTargetUsersForCategory(value);
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (MM:SS)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 2:30',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Target Users:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  children: _userTypes.map((userType) {
                    return CheckboxListTile(
                      title: Text(userType.toUpperCase()),
                      value: _selectedTargetUsers.contains(userType),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedTargetUsers.add(userType);
                          } else {
                            _selectedTargetUsers.remove(userType);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  void _saveChanges() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTargetUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one target user type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updates = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory,
      'targetUsers': _selectedTargetUsers,
      'duration': _durationController.text.trim().isNotEmpty
          ? _durationController.text.trim()
          : null,
    };

    widget.onSave(widget.videoId, updates);
  }

  /// Smart targeting based on category selection
  void _updateTargetUsersForCategory(String category) {
    switch (category) {
      case 'appointment_booking':
      case 'patient_education':
        _selectedTargetUsers = ['patient'];
        break;
      case 'doctor_resources':
        _selectedTargetUsers = ['doctor'];
        break;
      case 'chw_training':
        _selectedTargetUsers = ['chw'];
        break;
      case 'emergency_procedures':
        _selectedTargetUsers = ['doctor', 'chw', 'facility'];
        break;
      case 'wallet_usage':
      case 'messaging_guide':
      case 'profile_management':
        _selectedTargetUsers = ['doctor', 'patient', 'chw'];
        break;
      case 'system_navigation':
      case 'troubleshooting':
        _selectedTargetUsers = ['doctor', 'patient', 'chw', 'facility'];
        break;
      default:
        _selectedTargetUsers = ['patient'];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
