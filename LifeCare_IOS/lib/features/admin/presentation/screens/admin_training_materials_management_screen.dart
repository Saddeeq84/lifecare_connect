import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'admin_help_videos_screen.dart';
import 'admin_training_analytics_screen.dart';

class AdminTrainingMaterialsManagementScreen extends StatefulWidget {
  const AdminTrainingMaterialsManagementScreen({super.key});

  @override
  State<AdminTrainingMaterialsManagementScreen> createState() =>
      _AdminTrainingMaterialsManagementScreenState();
}

class _AdminTrainingMaterialsManagementScreenState
    extends State<AdminTrainingMaterialsManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training & Help Resources'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddMaterialDialog,
            tooltip: 'Add New Training Material',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Training Materials', icon: Icon(Icons.school)),
            Tab(text: 'Help Videos', icon: Icon(Icons.play_circle_outline)),
            Tab(text: 'Training Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTrainingMaterialsTab(),
          const AdminHelpVideosScreen(),
          const AdminTrainingAnalyticsScreen(),
        ],
      ),
    );
  }

  Widget _buildTrainingMaterialsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('training_materials')
          .orderBy('targetRole')
          .orderBy('type')
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final materials = snapshot.data?.docs ?? [];

        if (materials.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school, size: 80, color: Colors.grey),
                SizedBox(height: 24),
                Text(
                  'No Training Materials',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Upload your first training material to get started.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Group materials by role
        final Map<String, List<QueryDocumentSnapshot>> groupedMaterials = {};
        for (var material in materials) {
          final role = material['targetRole'] ?? 'general';
          if (!groupedMaterials.containsKey(role)) {
            groupedMaterials[role] = [];
          }
          groupedMaterials[role]!.add(material);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedMaterials.keys.length,
          itemBuilder: (context, index) {
            final role = groupedMaterials.keys.elementAt(index);
            final roleMaterials = groupedMaterials[role]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0) const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getRoleColor(role).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_getRoleIcon(role), color: _getRoleColor(role)),
                      const SizedBox(width: 12),
                      Text(
                        '${_formatRoleName(role)} Training Materials (${roleMaterials.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(role),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...roleMaterials.map((material) {
                  final data = material.data() as Map<String, dynamic>;
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
                          color: _getTypeColor(data['type']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getTypeIcon(data['type']),
                          color: _getTypeColor(data['type']),
                          size: 32,
                        ),
                      ),
                      title: Text(
                        data['title'] ?? 'Untitled Material',
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getTypeColor(
                                    data['type'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getTypeColor(
                                      data['type'],
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  data['type']?.toUpperCase() ?? 'UNKNOWN',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getTypeColor(data['type']),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(data['uploadedAt']),
                                style: TextStyle(
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
                                _toggleMaterialStatus(material.id, value),
                          ),
                          PopupMenuButton(
                            onSelected: (action) {
                              switch (action) {
                                case 'edit':
                                  _showEditMaterialDialog(material.id, data);
                                  break;
                                case 'download':
                                  _downloadMaterial(data['url'], data['title']);
                                  break;
                                case 'delete':
                                  _showDeleteConfirmation(
                                    material.id,
                                    data['title'],
                                  );
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
                                value: 'download',
                                child: Row(
                                  children: [
                                    Icon(Icons.download),
                                    SizedBox(width: 8),
                                    Text('Download'),
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

  void _showAddMaterialDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTrainingMaterialDialog(
        onSave: _uploadMaterial,
        isUploading: _isUploading,
        uploadProgress: _uploadProgress,
      ),
    );
  }

  void _showEditMaterialDialog(String materialId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => EditTrainingMaterialDialog(
        materialId: materialId,
        initialData: data,
        onSave: _updateMaterial,
      ),
    );
  }

  Future<void> _uploadMaterial(
    Map<String, dynamic> materialData,
    PlatformFile file,
  ) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      print('📚 [TRAINING MATERIAL UPLOAD] Starting upload process...');
      print(
        '📁 [TRAINING MATERIAL UPLOAD] File: ${file.name}, Size: ${file.size} bytes',
      );

      // Small delay to show "Preparing upload..." state
      await Future.delayed(const Duration(milliseconds: 500));

      // Upload file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath =
          'training_materials/${materialData['targetRole']}/${materialData['type']}s/$timestamp.${file.extension}';
      final fileRef = _storage.ref().child(filePath);

      print('📤 [TRAINING MATERIAL UPLOAD] Uploading to: $filePath');

      final uploadTask = fileRef.putData(
        file.bytes!,
        SettableMetadata(
          contentType: _getContentType(file.extension ?? ''),
          cacheControl: 'public, max-age=31536000',
        ),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
        print(
          '📊 [TRAINING MATERIAL UPLOAD] Progress: ${(_uploadProgress * 100).toInt()}%',
        );
      });

      await uploadTask;
      final downloadUrl = await fileRef.getDownloadURL();
      print(
        '✅ [TRAINING MATERIAL UPLOAD] File uploaded successfully: $downloadUrl',
      );

      // Save to Firestore
      print('💾 [TRAINING MATERIAL UPLOAD] Saving metadata to Firestore...');
      await _firestore.collection('training_materials').add({
        ...materialData,
        'url': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'downloadCount': 0,
      });
      print(
        '✅ [TRAINING MATERIAL UPLOAD] Metadata saved to Firestore successfully!',
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Training material uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ [TRAINING MATERIAL UPLOAD] Upload failed: $e');
      print('🔍 [TRAINING MATERIAL UPLOAD] Error details: ${e.toString()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload material: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _updateMaterial(
    String materialId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore
          .collection('training_materials')
          .doc(materialId)
          .update(updates);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Training material updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleMaterialStatus(String materialId, bool isActive) async {
    try {
      await _firestore.collection('training_materials').doc(materialId).update({
        'isActive': isActive,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive ? 'Material activated' : 'Material deactivated',
          ),
          backgroundColor: isActive ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(String materialId, String? title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Training Material'),
        content: Text(
          'Are you sure you want to delete "${title ?? 'this material'}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteMaterial(materialId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMaterial(String materialId) async {
    try {
      // Get material data to delete file from storage
      final doc = await _firestore
          .collection('training_materials')
          .doc(materialId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final url = data['url'] as String?;

        // Delete from Firebase Storage
        if (url != null) {
          try {
            await _storage.refFromURL(url).delete();
          } catch (e) {
            print('Warning: Could not delete file from storage: $e');
          }
        }
      }

      // Delete from Firestore
      await _firestore
          .collection('training_materials')
          .doc(materialId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Training material deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _downloadMaterial(String? url, String? title) {
    if (url != null) {
      // Open URL for download
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening "${title ?? 'material'}" for download...'),
          backgroundColor: Colors.blue,
        ),
      );
      // In web, this would open in a new tab
      // You might want to use url_launcher package for this
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'doctor':
        return Colors.blue;
      case 'patient':
        return Colors.green;
      case 'chw':
        return Colors.teal;
      case 'facility':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role) {
      case 'doctor':
        return Icons.medical_services;
      case 'patient':
        return Icons.person;
      case 'chw':
        return Icons.health_and_safety;
      case 'facility':
        return Icons.business;
      default:
        return Icons.school;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'video':
        return Colors.blue;
      case 'audio':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'video':
        return Icons.play_circle_outline;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'chw':
        return 'CHW';
      default:
        return role[0].toUpperCase() + role.substring(1);
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }
}

// Add Material Dialog
class AddTrainingMaterialDialog extends StatefulWidget {
  final Function(Map<String, dynamic>, PlatformFile) onSave;
  final bool isUploading;
  final double uploadProgress;

  const AddTrainingMaterialDialog({
    super.key,
    required this.onSave,
    required this.isUploading,
    required this.uploadProgress,
  });

  @override
  State<AddTrainingMaterialDialog> createState() =>
      _AddTrainingMaterialDialogState();
}

class _AddTrainingMaterialDialogState extends State<AddTrainingMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedRole = 'chw';
  String _selectedType = 'pdf';
  PlatformFile? _selectedFile;

  final List<String> _roles = ['chw', 'doctor', 'patient', 'facility'];
  final List<String> _types = ['pdf', 'video', 'audio'];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.isUploading,
      child: AlertDialog(
        title: const Text('Add Training Material'),
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
                      labelText: 'Material Title *',
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
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Target Role',
                      border: OutlineInputBorder(),
                    ),
                    items: _roles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Material Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _types.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: widget.isUploading ? null : _selectFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _selectedFile == null
                          ? 'Select File *'
                          : 'File Selected: ${_selectedFile!.name}',
                    ),
                  ),
                  if (widget.isUploading) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: widget.uploadProgress > 0
                                      ? widget.uploadProgress
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.uploadProgress > 0
                                      ? 'Uploading material... ${(widget.uploadProgress * 100).toInt()}%'
                                      : 'Preparing upload...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: widget.uploadProgress,
                              backgroundColor: Colors.blue.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.uploadProgress > 0
                                ? 'Please wait while your material is being uploaded. Do not close this dialog.'
                                : 'Getting ready to upload your material...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
            onPressed: widget.isUploading ? null : _saveMaterial,
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

  Future<void> _selectFile() async {
    FileType fileType;
    List<String>? allowedExtensions;

    switch (_selectedType) {
      case 'pdf':
        fileType = FileType.custom;
        allowedExtensions = ['pdf'];
        break;
      case 'video':
        fileType = FileType.video;
        break;
      case 'audio':
        fileType = FileType.audio;
        break;
      default:
        fileType = FileType.any;
    }

    final result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedFile = result.files.single;
      });
    }
  }

  void _saveMaterial() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog before uploading
    _showUploadConfirmationDialog();
  }

  void _showUploadConfirmationDialog() {
    final fileSize = (_selectedFile!.size / (1024 * 1024)).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload_file, color: Colors.teal),
            SizedBox(width: 8),
            Text('Confirm Material Upload'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You are about to upload the following training material:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
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
                          'Target Role: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_selectedRole.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Material Type: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_selectedType.toUpperCase()),
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
                        Expanded(child: Text(_selectedFile!.name)),
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
                        'This training material will be uploaded to Firebase Storage and made available to the selected target role. The upload may take several minutes depending on file size.',
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _proceedWithUpload();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Row(
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
    final materialData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'targetRole': _selectedRole,
      'type': _selectedType,
    };

    widget.onSave(materialData, _selectedFile!);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Edit Material Dialog
class EditTrainingMaterialDialog extends StatefulWidget {
  final String materialId;
  final Map<String, dynamic> initialData;
  final Function(String, Map<String, dynamic>) onSave;

  const EditTrainingMaterialDialog({
    super.key,
    required this.materialId,
    required this.initialData,
    required this.onSave,
  });

  @override
  State<EditTrainingMaterialDialog> createState() =>
      _EditTrainingMaterialDialogState();
}

class _EditTrainingMaterialDialogState
    extends State<EditTrainingMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _selectedRole;
  late String _selectedType;

  final List<String> _roles = ['chw', 'doctor', 'patient', 'facility'];
  final List<String> _types = ['pdf', 'video', 'audio'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialData['title'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialData['description'] ?? '',
    );
    _selectedRole = widget.initialData['targetRole'] ?? 'chw';
    _selectedType = widget.initialData['type'] ?? 'pdf';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Training Material'),
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
                    labelText: 'Material Title *',
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
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Target Role',
                    border: OutlineInputBorder(),
                  ),
                  items: _roles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Material Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _types.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
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
          onPressed: _saveMaterial,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  void _saveMaterial() {
    if (!_formKey.currentState!.validate()) return;

    final updates = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'targetRole': _selectedRole,
      'type': _selectedType,
    };

    widget.onSave(widget.materialId, updates);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
