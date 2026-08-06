// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';

class CHWProfileScreen extends StatefulWidget {
  const CHWProfileScreen({super.key});

  @override
  State<CHWProfileScreen> createState() => _CHWProfileScreenState();
}

class _CHWProfileScreenState extends State<CHWProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _specializationController =
      TextEditingController();

  String? _profileImageUrl;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, int> _stats = {
    'patients': 0,
    'referrals': 0,
    'consultations': 0,
    'trainings': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Try to load from chw_profiles first, then users collection
        DocumentSnapshot doc = await _firestore
            .collection('chw_profiles')
            .doc(user.uid)
            .get();

        if (!doc.exists) {
          doc = await _firestore.collection('users').doc(user.uid).get();
        }

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          _nameController.text = data['fullName'] ?? data['name'] ?? '';
          _emailController.text = data['email'] ?? user.email ?? '';
          _phoneController.text = data['phone'] ?? '';
          _locationController.text = data['location'] ?? '';
          _experienceController.text = data['experience'] ?? '';
          _specializationController.text = data['specialization'] ?? '';
          _profileImageUrl = data['photoUrl'] ?? data['profileImageUrl'];
        } else {
          // Set default email if profile doesn't exist
          _emailController.text = user.email ?? '';
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load profile')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Load patient count
        final patientsQuery = await _firestore
            .collection('patients')
            .where('chwId', isEqualTo: user.uid)
            .get();

        // Load referrals count
        final referralsQuery = await _firestore
            .collection('referrals')
            .where('referredBy', isEqualTo: user.uid)
            .get();

        // Load consultations count
        final consultationsQuery = await _firestore
            .collection('consultations')
            .where('chwId', isEqualTo: user.uid)
            .get();

        // Load training completions count
        final trainingsQuery = await _firestore
            .collection('training_completions')
            .where('userId', isEqualTo: user.uid)
            .get();

        setState(() {
          _stats = {
            'patients': patientsQuery.docs.length,
            'referrals': referralsQuery.docs.length,
            'consultations': consultationsQuery.docs.length,
            'trainings': trainingsQuery.docs.length,
          };
        });
      }
    } catch (e) {}
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _profileImageUrl;

    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final ref = _storage.ref().child('chw_profile_photos/${user.uid}.jpg');
      await ref.putFile(_selectedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Upload image if selected
      final imageUrl = await _uploadImage();

      final data = {
        'fullName': _nameController.text.trim(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'experience': _experienceController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userType': 'chw',
      };

      if (imageUrl != null) {
        data['photoUrl'] = imageUrl;
        data['profileImageUrl'] = imageUrl;
      }

      // Update both collections to maintain compatibility
      await _firestore
          .collection('chw_profiles')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      setState(() {
        _isEditing = false;
        _selectedImage = null;
        if (imageUrl != null) _profileImageUrl = imageUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHW Profile'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _selectedImage = null;
                    });
                    _loadProfile(); // Reload original data
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _saveProfile,
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Picture Section
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.teal.shade100,
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child:
                              _selectedImage == null && _profileImageUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.teal.shade700,
                                )
                              : null,
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.teal.shade700,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18),
                                color: Colors.white,
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Profile Form
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    enabled: false, // Email shouldn't be editable
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _locationController,
                    label: 'Location/Area of Service',
                    icon: Icons.location_on,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _experienceController,
                    label: 'Years of Experience',
                    icon: Icons.work,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _specializationController,
                    label: 'Specialization/Focus Areas',
                    icon: Icons.medical_services,
                    enabled: _isEditing,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 32),

                  // Profile Stats Cards
                  if (!_isEditing) ...[
                    const Text(
                      'Profile Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Patients Registered',
                            '${_stats['patients']}',
                            Icons.people,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Referrals Made',
                            '${_stats['referrals']}',
                            Icons.share,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Consultations',
                            '${_stats['consultations']}',
                            Icons.medical_services,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Training Completed',
                            '${_stats['trainings']}',
                            Icons.school,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.teal.shade700),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
