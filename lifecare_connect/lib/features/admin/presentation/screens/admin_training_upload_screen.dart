// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminTrainingUploadScreen extends StatefulWidget {
  const AdminTrainingUploadScreen({super.key});

  @override
  State<AdminTrainingUploadScreen> createState() => _AdminTrainingUploadScreenState();
}

class _AdminTrainingUploadScreenState extends State<AdminTrainingUploadScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKeyCHW = GlobalKey<FormState>();
  final _formKeyPatient = GlobalKey<FormState>();
  final _formKeyDoctor = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _healthTipController = TextEditingController(); // For patient health tips

  String _selectedType = 'pdf';
  File? _selectedFile;
  Uint8List? _selectedFileBytes;
  bool _isUploading = false;
  String _currentRole = 'chw'; // Track current tab role

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // Update current role when tab changes
      setState(() {
        switch (_tabController.index) {
          case 0:
            _currentRole = 'chw';
            break;
          case 1:
            _currentRole = 'patient';
            // Reset to video for patients
            _selectedType = 'video';
            break;
          case 2:
            _currentRole = 'doctor';
            break;
        }
        // Clear file selection when changing tabs
        _selectedFile = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _healthTipController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // For patients, only allow video files
    final isPatient = _currentRole == 'patient';
    final result = await FilePicker.platform.pickFiles(
      type: isPatient
          ? FileType.video
          : (_selectedType == 'video' ? FileType.video : FileType.custom),
      allowedExtensions: !isPatient && _selectedType == 'pdf' ? ['pdf'] : null,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        final file = result.files.single;
        _selectedFile = file.path != null ? File(file.path!) : null;
        _selectedFileBytes = file.bytes;
      });
    }
  }

  Future<void> _uploadMaterial(String targetRole, GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the form.')),
      );
      return;
    }

    // For patients, we can upload health tips without files
    if (targetRole == 'patient' && _selectedFile == null && _healthTipController.text.trim().isNotEmpty) {
      // Upload health tip as text-only content
      await _uploadHealthTip(targetRole);
      return;
    }

    // For all other cases, require a file
    if (_selectedFile == null && _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final fileName = _selectedFile != null ? p.basename(_selectedFile!.path) : 'web_upload_${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('training_materials/$targetRole/${_selectedType}s/${timestamp}_$fileName');

      String downloadUrl;
      int fileSize;

  // Platform check for web
  bool isWeb = kIsWeb;

      if (isWeb && _selectedFileBytes != null) {
        fileSize = _selectedFileBytes!.length;
        // Firebase Storage web upload limit is 10MB
        if (fileSize > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File too large. Max 10MB allowed for web uploads.'), backgroundColor: Colors.red),
          );
          setState(() => _isUploading = false);
          return;
        }
        try {
          final uploadTask = await ref.putData(_selectedFileBytes!);
          downloadUrl = await uploadTask.ref.getDownloadURL();
        } catch (e) {
          debugPrint('Web upload error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Web upload failed: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isUploading = false);
          return;
        }
      } else if (_selectedFile != null) {
        try {
          final uploadTask = await ref.putFile(_selectedFile!);
          downloadUrl = await uploadTask.ref.getDownloadURL();
          fileSize = await _selectedFile!.length();
        } catch (e) {
          debugPrint('Mobile/desktop upload error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isUploading = false);
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file data available for upload.'), backgroundColor: Colors.red),
        );
        setState(() => _isUploading = false);
        return;
      }

      final materialData = {
        'id': '${timestamp}_${targetRole}_$_selectedType',
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'url': downloadUrl,
        'type': _selectedType,
        'targetRole': targetRole,
        'fileName': fileName,
        'fileSize': fileSize,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'version': 1,
        'isActive': true,
        'downloadCount': 0,
        'tags': _generateTags(targetRole, _selectedType),
        'syncStatus': 'synced',
      };

      try {
        await FirebaseFirestore.instance.collection('training_materials').add(materialData);
      } catch (e) {
        debugPrint('Firestore write error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save material: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isUploading = false);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Material uploaded successfully for $targetRole users!'),
          backgroundColor: Colors.green,
        ),
      );

      _titleController.clear();
      _descController.clear();
      if (targetRole == 'patient') {
        _healthTipController.clear();
      }
      setState(() {
        _selectedType = targetRole == 'patient' ? 'video' : 'pdf';
        _selectedFile = null;
        _selectedFileBytes = null;
      });
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadHealthTip(String targetRole) async {
    setState(() => _isUploading = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Upload health tip as text-only content
      final materialData = {
        'id': '${timestamp}_${targetRole}_health_tip',
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'healthTip': _healthTipController.text.trim(),
        'type': 'health_tip',
        'targetRole': targetRole,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'version': 1,
        'isActive': true,
        'tags': _generateTags(targetRole, 'health_tip'),
        'syncStatus': 'synced',
      };

      await FirebaseFirestore.instance.collection('training_materials').add(materialData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Health tip uploaded successfully for $targetRole users!'),
          backgroundColor: Colors.green,
        ),
      );

      _titleController.clear();
      _descController.clear();
      _healthTipController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  List<String> _generateTags(String targetRole, String type) {
    List<String> tags = [targetRole, type];
    
    // Add contextual tags based on role
    switch (targetRole.toLowerCase()) {
      case 'chw':
        tags.addAll(['community_health', 'field_work', 'primary_care']);
        break;
      case 'doctor':
        tags.addAll(['clinical', 'medical', 'diagnosis', 'treatment']);
        break;
      case 'patient':
        tags.addAll(['education', 'self_care', 'health_literacy']);
        break;
    }
    
    // Add type-specific tags
    if (type == 'video') {
      tags.addAll(['multimedia', 'visual_learning']);
    } else if (type == 'pdf') {
      tags.addAll(['document', 'reference']);
    } else if (type == 'health_tip') {
      tags.addAll(['quick_tips', 'wellness']);
    }
    
    return tags;
  }

  Widget _buildUploadForm(String roleLabel, GlobalKey<FormState> formKey) {
    final isPatient = roleLabel.toLowerCase() == 'patient';
    
    // Define custom headings based on role
    String heading;
    switch (roleLabel.toLowerCase()) {
      case 'patient':
        heading = 'Upload Educational Materials & Health Tips';
        break;
      case 'chw':
        heading = 'Upload Training Resources';
        break;
      case 'doctor':
        heading = 'Upload Clinical Resources';
        break;
      default:
        heading = "Upload Training Material for $roleLabel";
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: ListView(
          children: [
            Text(
              heading,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => value == null || value.isEmpty ? 'Enter title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) => value == null || value.isEmpty ? 'Enter description' : null,
            ),
            
            // Health Tips field (Patient only)
            if (isPatient) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _healthTipController,
                decoration: const InputDecoration(
                  labelText: 'Health Tip (Optional)',
                  hintText: 'Enter a quick health tip for patients',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Text(
                'Note: You can upload either a video file OR just post a health tip (or both).',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Material Type dropdown (hidden for patients - always video)
            if (!isPatient) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Material Type'),
                items: ['pdf', 'video'].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
            ] else ...[
              // For patients, show that only videos are allowed
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.video_library, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Patient uploads: Video files only',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            ElevatedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: Text(isPatient ? 'Choose Video File (Optional)' : 'Choose File'),
              onPressed: _pickFile,
            ),
            if (_selectedFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Selected: ${p.basename(_selectedFile!.path)}'),
              ),
            const SizedBox(height: 20),
            _isUploading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: Text(isPatient ? 'Upload Content' : 'Upload Material'),
                    onPressed: () => _uploadMaterial(roleLabel.toLowerCase(), formKey),
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
        title: const Text('Admin: Upload Training Materials'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'CHWs'),
            Tab(text: 'Patients'),
            Tab(text: 'Doctors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUploadForm('CHW', _formKeyCHW),
          _buildUploadForm('Patient', _formKeyPatient),
          _buildUploadForm('Doctor', _formKeyDoctor),
        ],
      ),
    );
  }
}
