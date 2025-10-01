// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _ageController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String _gender = 'Female';
  String _bloodGroup = 'O+';

  bool _isLoading = true;
  String? _photoUrl;
  File? _newImageFile;

  final List<String> _genderOptions = ['Female', 'Male', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('patient_profiles').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _fullNameController.text = data['fullName'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _locationController.text = data['address'] ?? '';
        _ageController.text = (data['age'] ?? '').toString();
        _gender = data['gender'] ?? _gender;
        _bloodGroup = data['bloodGroup'] ?? _bloodGroup;
        _photoUrl = data['photoUrl'];
        _emergencyNameController.text = data['emergencyContact']?['name'] ?? '';
        _emergencyPhoneController.text = data['emergencyContact']?['phone'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _newImageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_newImageFile == null) return null;
    try {
      final ref = _storage.ref().child('profile_photos/$uid.jpg');
      await ref.putFile(_newImageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload failed: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    String? uploadedUrl;
    if (_newImageFile != null) {
      uploadedUrl = await _uploadImage(user.uid);
    }

    final data = {
      'fullName': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _locationController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()) ?? 0,
      'gender': _gender,
      'bloodGroup': _bloodGroup,
      'emergencyContact': {
        'name': _emergencyNameController.text.trim(),
        'phone': _emergencyPhoneController.text.trim(),
      },
      if (uploadedUrl != null) 'photoUrl': uploadedUrl,
    };

    try {
      await _firestore.collection('patient_profiles').doc(user.uid).set(data, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), backgroundColor: Colors.green),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _newImageFile != null
                                ? FileImage(_newImageFile!)
                                : (_photoUrl != null
                                    ? NetworkImage(_photoUrl!) as ImageProvider
                                    : const AssetImage('assets/images/patient_avatar.png')),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Colors.green,
                              radius: 16,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                onPressed: _pickImage,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildField('Full Name', _fullNameController),
                    _buildField('Phone Number', _phoneController, keyboardType: TextInputType.phone),
                    _buildField('Location', _locationController),
                    _buildField('Age', _ageController, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildDropdown('Gender', _gender, _genderOptions, (val) => setState(() => _gender = val!)),
                    const SizedBox(height: 12),
                    _buildDropdown('Blood Group', _bloodGroup, _bloodGroups, (val) => setState(() => _bloodGroup = val!)),
                    const SizedBox(height: 20),
                    const Text('Emergency Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildField('Name', _emergencyNameController),
                    _buildField('Phone Number', _emergencyPhoneController, keyboardType: TextInputType.phone),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Save Changes'),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}
