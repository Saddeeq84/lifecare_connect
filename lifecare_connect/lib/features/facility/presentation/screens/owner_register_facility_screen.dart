import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lifecare_connect/core/utils/email_admin_approval.dart';
import 'dart:typed_data';

class OwnerRegisterFacilityScreen extends StatefulWidget {
  const OwnerRegisterFacilityScreen({super.key});

  @override
  State<OwnerRegisterFacilityScreen> createState() => _OwnerRegisterFacilityScreenState();
}
class _OwnerRegisterFacilityScreenState extends State<OwnerRegisterFacilityScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedFacilityType;
  Uint8List? _selectedDocumentBytes;
  String? _selectedDocumentName;
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();
  // firebase_auth 6.x does not support fetchSignInMethodsForEmail; always return false so registration proceeds.

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedDocumentBytes = result.files.single.bytes;
        _selectedDocumentName = result.files.single.name;
      });
    }
  }

  Future<void> _handleSubmit() async {
  // ...existing code...
    setState(() {
      _isSubmitting = true;
    });
    try {
      // 1. Create user with Firebase Auth
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final location = _locationController.text.trim();
      final contact = _contactController.text.trim();
      final phone = _phoneController.text.trim();
      final facilityType = _selectedFacilityType;
      String? documentUrl;

      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Upload document if present
      if (_selectedDocumentBytes != null && _selectedDocumentName != null) {
        final fileName = 'facility_docs/${userCredential.user!.uid}_$_selectedDocumentName';
        final ref = storage.ref().child(fileName);
        await ref.putData(_selectedDocumentBytes!);
        documentUrl = await ref.getDownloadURL();
      }

      // 3. Save facility data to Firestore (pending approval) in 'users' collection
      await firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'location': location,
        'role': 'facility',
        'type': facilityType,
        'contact': contact,
        'email': email,
        'phone': phone,
        'documentUrl': documentUrl,
        'ownerUid': userCredential.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isApproved': false,
        'isRejected': false,
      });

      // 4. Send admin approval email notification
      try {
        await sendAdminApprovalRequiredEmail(email, name);
      } catch (e) {
        debugPrint('Failed to send admin approval email: $e');
      }

      // 5. Show success dialog and clear form
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text(
            'Facility registered successfully!\n\nYour account requires admin review and approval. '
            'Your account will become active after admin approval and you will receive an email notification.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _formKey.currentState!.reset();
      _nameController.clear();
      _locationController.clear();
      _contactController.clear();
      _emailController.clear();
      _phoneController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _selectedFacilityType = null;
        _selectedDocumentBytes = null;
        _selectedDocumentName = null;
      });
    } on FirebaseAuthException catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registration Error'),
          content: Text(e.message ?? 'An error occurred.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
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
                  initialValue: _selectedFacilityType,
                  decoration: const InputDecoration(
                    labelText: 'Facility Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Hospital', child: Text('Hospital')),
                    DropdownMenuItem(value: 'Clinic', child: Text('Clinic')),
                    DropdownMenuItem(value: 'Laboratory', child: Text('Laboratory')),
                    DropdownMenuItem(value: 'Pharmacy', child: Text('Pharmacy')),
                    DropdownMenuItem(value: 'Imaging Center', child: Text('Imaging Center')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFacilityType = value;
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
                  controller: _contactController,
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (_selectedDocumentBytes != null && _selectedDocumentName != null) ...[
                          Text(
                            'Selected: $_selectedDocumentName',
                            style: const TextStyle(color: Colors.green),
                          ),
                          const SizedBox(height: 8),
                        ],
                        ElevatedButton.icon(
                          onPressed: _pickDocument,
                          icon: const Icon(Icons.attach_file),
                          label: Text(_selectedDocumentBytes != null ? 'Change Document' : 'Select Document'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please confirm password';
                    if (value != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Registration'),
                              content: const Text('Are you sure you want to register this facility?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
// This code defines a screen for facility owners to register their facilities.
