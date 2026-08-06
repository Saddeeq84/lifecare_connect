import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

// import '../sharedscreen/facility_register_widget.dart';

class AdminRegisterFacilityScreen extends StatefulWidget {
  const AdminRegisterFacilityScreen({super.key});

  @override
  State<AdminRegisterFacilityScreen> createState() =>
      _AdminRegisterFacilityScreenState();
}

class _AdminRegisterFacilityScreenState
    extends State<AdminRegisterFacilityScreen> {
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _typeController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _selectedDocument;
  Uint8List? _selectedDocumentBytes;
  String? _selectedDocumentName;

  // Helper to get content type for web uploads
  String _getContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String?> _uploadDocument(File file) async {
    try {
      final fileName =
          'facility_documents/${DateTime.now().millisecondsSinceEpoch}_${_selectedDocumentName ?? file.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      if (kIsWeb && _selectedDocumentBytes != null) {
        // Web: upload using bytes
        final uploadTask = await ref.putData(
          _selectedDocumentBytes!,
          SettableMetadata(
            contentType: _getContentType(_selectedDocumentName ?? fileName),
          ),
        );
        return await uploadTask.ref.getDownloadURL();
      } else {
        // Mobile/Desktop: upload using File
        await ref.putFile(file);
        return await ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint("Document upload failed: $e");
      return null;
    }
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: kIsWeb,
      );

      if (result != null) {
        setState(() {
          _selectedDocumentName = result.files.single.name;
          if (kIsWeb && result.files.single.bytes != null) {
            _selectedDocumentBytes = result.files.single.bytes;
            _selectedDocument = null;
          } else if (result.files.single.path != null) {
            _selectedDocument = File(result.files.single.path!);
            _selectedDocumentBytes = null;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking document: $e')));
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      String? docUrl;
      // Always require a document
      if (kIsWeb) {
        if (_selectedDocumentBytes == null || _selectedDocumentName == null) {
          throw Exception('Please select a registration document.');
        }
        // Use a dummy File for API compatibility, but only bytes are used
        docUrl = await _uploadDocument(File('dummy'));
      } else {
        if (_selectedDocument == null) {
          throw Exception('Please select a registration document.');
        }
        docUrl = await _uploadDocument(_selectedDocument!);
      }
      if (docUrl == null || docUrl.isEmpty) {
        throw Exception('Document upload failed. Please try again.');
      }

      // Add to users collection as facility
      await FirebaseFirestore.instance.collection('users').add({
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'type': _typeController.text.trim(),
        'role': 'facility',
        'createdBy': 'admin',
        'isApproved': true,
        'isRejected': false,
        'createdAt': FieldValue.serverTimestamp(),
        'contactPerson': _contactPersonController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'documentUrl': docUrl,
      });

      // Send password setup (reset) email to facility owner
      final ownerEmail = _emailController.text.trim();
      await FirebaseAuth.instance.sendPasswordResetEmail(email: ownerEmail);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "✅ Facility registration successful! The owner must check their email and follow the link to set up their password.",
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _typeController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Facility"),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Facility Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter facility name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location/Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _typeController.text.isEmpty
                    ? null
                    : _typeController.text,
                decoration: const InputDecoration(
                  labelText: 'Facility Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Hospital', child: Text('Hospital')),
                  DropdownMenuItem(
                    value: 'Clinic/PHC',
                    child: Text('Clinic/PHC'),
                  ),
                  DropdownMenuItem(
                    value: 'Dental Clinic',
                    child: Text('Dental Clinic'),
                  ),
                  DropdownMenuItem(
                    value: 'Laboratory',
                    child: Text('Laboratory'),
                  ),
                  DropdownMenuItem(value: 'Pharmacy', child: Text('Pharmacy')),
                  DropdownMenuItem(
                    value: 'Scan Center',
                    child: Text('Scan Center'),
                  ),
                  DropdownMenuItem(
                    value: 'Eye Clinic',
                    child: Text('Eye Clinic'),
                  ),
                  DropdownMenuItem(
                    value: 'Mental Health Center',
                    child: Text('Mental Health Center'),
                  ),
                  DropdownMenuItem(
                    value: 'Physiotherapy Center',
                    child: Text('Physiotherapy Center'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _typeController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select facility type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactPersonController,
                decoration: const InputDecoration(
                  labelText: 'Contact Person',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter contact person';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registration Document (Required)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedDocument != null) ...[
                        Text(
                          'Selected: ${_selectedDocument!.path.split('/').last}',
                          style: const TextStyle(color: Colors.green),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: _pickDocument,
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          (_selectedDocument != null ||
                                  _selectedDocumentBytes != null)
                              ? 'Change Document'
                              : 'Select Document',
                        ),
                      ),
                      if (_selectedDocument == null &&
                          _selectedDocumentBytes == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Please select a registration document.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed:
                    _isSubmitting ||
                        (_selectedDocument == null &&
                            _selectedDocumentBytes == null)
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Registration'),
                            content: const Text(
                              'Are you sure you want to register this facility?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          _handleSubmit();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Register Facility',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
