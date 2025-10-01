// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

/// Standardized CHW Profile Edit Screen following Flutter best practices
/// Includes proper form validation, error handling, and user feedback
class CHWProfileEditScreen extends StatefulWidget {
  const CHWProfileEditScreen({super.key});

  @override
  State<CHWProfileEditScreen> createState() => _CHWProfileEditScreenState();
}

class _CHWProfileEditScreenState extends State<CHWProfileEditScreen> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Form key and controllers
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _isSaving = false;
  String? _profileImageUrl;
  File? _selectedImage;
  String _selectedGender = 'Not specified';
  DateTime? _selectedBirthDate;

  // Dropdown options
  final List<String> _genderOptions = [
    'Not specified',
    'Male',
    'Female',
    'Other'
  ];

  final List<String> _specializationOptions = [
    'General CHW',
    'Maternal Health',
    'Child Health',
    'Chronic Diseases',
    'Mental Health',
    'Infectious Diseases',
    'Community Education',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    _specializationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Load user profile data
  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Try CHW profiles collection first, then users collection
        DocumentSnapshot doc = await _firestore
            .collection('chw_profiles')
            .doc(user.uid)
            .get();

        if (!doc.exists) {
          doc = await _firestore.collection('users').doc(user.uid).get();
        }

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          _populateFields(data, user.email);
        } else {
          // Set default email for new profiles
          _emailController.text = user.email ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      _showErrorSnackBar('Failed to load profile data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Populate form fields with user data
  void _populateFields(Map<String, dynamic> data, String? email) {
    _nameController.text = data['fullName'] ?? data['name'] ?? '';
    _emailController.text = data['email'] ?? email ?? '';
    _phoneController.text = data['phone'] ?? '';
    _locationController.text = data['location'] ?? '';
    _experienceController.text = data['experience'] ?? '';
    _bioController.text = data['bio'] ?? '';
    _profileImageUrl = data['photoUrl'] ?? data['profileImageUrl'];
    _selectedGender = data['gender'] ?? 'Not specified';
    
    // Handle specialization
    String specialization = data['specialization'] ?? 'General CHW';
    if (_specializationOptions.contains(specialization)) {
      _specializationController.text = specialization;
    } else {
      _specializationController.text = 'Other';
    }

    // Handle birth date
    if (data['birthDate'] != null) {
      if (data['birthDate'] is Timestamp) {
        _selectedBirthDate = (data['birthDate'] as Timestamp).toDate();
      } else if (data['birthDate'] is String) {
        _selectedBirthDate = DateTime.tryParse(data['birthDate']);
      }
    }
  }

  /// Select profile image
  Future<void> _selectImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      debugPrint('Error selecting image: $e');
      _showErrorSnackBar('Failed to select image');
    }
  }

  /// Upload profile image to Firebase Storage
  Future<String?> _uploadProfileImage() async {
    if (_selectedImage == null) return _profileImageUrl;

    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final storageRef = _storage
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      final uploadTask = storageRef.putFile(_selectedImage!);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      _showErrorSnackBar('Failed to upload profile image');
      return null;
    }
  }

  /// Save profile data
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      // Upload image if selected
      String? imageUrl = await _uploadProfileImage();

      // Prepare profile data
      final profileData = {
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'experience': _experienceController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': _selectedGender,
        'birthDate': _selectedBirthDate?.toIso8601String(),
        'role': 'chw',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null) {
        profileData['photoUrl'] = imageUrl;
        profileData['profileImageUrl'] = imageUrl;
      }

      // Save to both collections for compatibility
      await Future.wait([
        _firestore.collection('chw_profiles').doc(user.uid).set(
              profileData,
              SetOptions(merge: true),
            ),
        _firestore.collection('users').doc(user.uid).set(
              profileData,
              SetOptions(merge: true),
            ),
      ]);

      _showSuccessSnackBar('Profile updated successfully');
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error saving profile: $e');
      _showErrorSnackBar('Failed to save profile: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Select birth date
  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)), // Minimum 16 years old
    );

    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  /// Show success message
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Show error message
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: 'Save Profile',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Image Section
            _buildProfileImageSection(),
            const SizedBox(height: 24),

            // Personal Information
            _buildPersonalInfoSection(),
            const SizedBox(height: 24),

            // Professional Information
            _buildProfessionalInfoSection(),
            const SizedBox(height: 24),

            // Bio Section
            _buildBioSection(),
            const SizedBox(height: 32),

            // Save Button
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  /// Build profile image section
  Widget _buildProfileImageSection() {
    return Center(
      child: GestureDetector(
        onTap: _selectImage,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
            border: Border.all(color: Colors.teal, width: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(60),
            child: _selectedImage != null
                ? Image.file(_selectedImage!, fit: BoxFit.cover)
                : _profileImageUrl != null
                    ? Image.network(_profileImageUrl!, fit: BoxFit.cover)
                    : const Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: Colors.teal,
                      ),
          ),
        ),
      ),
    );
  }

  /// Build personal information section
  Widget _buildPersonalInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.trim().isEmpty == true
                  ? 'Please enter your full name'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.trim().isEmpty == true) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) => value?.trim().isEmpty == true
                  ? 'Please enter your phone number'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: _genderOptions
                  .map((gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedGender = value);
                }
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectBirthDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedBirthDate != null
                      ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                      : 'Select date of birth',
                  style: TextStyle(
                    color: _selectedBirthDate != null
                        ? Colors.black87
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build professional information section
  Widget _buildProfessionalInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Professional Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Work Location/Area',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _specializationController.text.isNotEmpty
                  ? _specializationController.text
                  : 'General CHW',
              decoration: const InputDecoration(
                labelText: 'Specialization',
                prefixIcon: Icon(Icons.medical_services),
                border: OutlineInputBorder(),
              ),
              items: _specializationOptions
                  .map((spec) => DropdownMenuItem(
                        value: spec,
                        child: Text(spec),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _specializationController.text = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _experienceController,
              decoration: const InputDecoration(
                labelText: 'Years of Experience',
                prefixIcon: Icon(Icons.work),
                border: OutlineInputBorder(),
                helperText: 'e.g., 2 years, 6 months',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build bio section
  Widget _buildBioSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About Me',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio/Description',
                hintText: 'Tell us about yourself, your experience, and your passion for community health...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }

  /// Build save button
  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveProfile,
      icon: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
      label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
