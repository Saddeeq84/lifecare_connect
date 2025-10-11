// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class FacilityProfileScreen extends StatefulWidget {
  const FacilityProfileScreen({super.key});

  @override
  State<FacilityProfileScreen> createState() => _FacilityProfileScreenState();
}

class _FacilityProfileScreenState extends State<FacilityProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _facilityNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _servicesController = TextEditingController();
  final _operatingHoursController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  Map<String, dynamic> _facilityData = {};

  @override
  void initState() {
    super.initState();
    _loadFacilityData();
  }

  @override
  void dispose() {
    _facilityNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _servicesController.dispose();
    _operatingHoursController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilityData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _facilityData = doc.data() ?? {};
        _populateFields();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateFields() {
    _facilityNameController.text =
        _facilityData['facilityName'] ?? _facilityData['name'] ?? '';
    _emailController.text = _facilityData['email'] ?? '';
    _phoneController.text = _facilityData['phone'] ?? '';
    _addressController.text = _facilityData['address'] ?? '';
    _descriptionController.text = _facilityData['description'] ?? '';
    _servicesController.text =
        (_facilityData['services'] as List?)?.join(', ') ?? '';
    _operatingHoursController.text = _facilityData['operatingHours'] ?? '';
    _emergencyContactController.text = _facilityData['emergencyContact'] ?? '';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Prepare services list
      final servicesList = _servicesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final updateData = {
        'facilityName': _facilityNameController.text.trim(),
        'name': _facilityNameController.text
            .trim(), // Keep both for compatibility
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'services': servicesList,
        'operatingHours': _operatingHoursController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isProfileComplete': true,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _facilityData.addAll(updateData);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Facility Profile'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
            ),
          if (_isEditing) ...[
            TextButton(
              onPressed: () {
                setState(() => _isEditing = false);
                _populateFields(); // Reset fields
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            _isSaving
                ? Container(
                    padding: const EdgeInsets.all(14),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _saveProfile,
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ],
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.teal, width: 3),
                      ),
                      child: Icon(
                        Icons.local_hospital,
                        size: 60,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _facilityData['facilityName'] ??
                          _facilityData['name'] ??
                          'Facility Name',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Healthcare Facility',
                        style: TextStyle(
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Facility Information
              _buildSectionTitle('Facility Information'),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _facilityNameController,
                label: 'Facility Name',
                icon: Icons.local_hospital,
                enabled: _isEditing,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Facility name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email,
                enabled: false, // Email should not be editable
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on,
                enabled: _isEditing,
                maxLines: 2,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Service Information
              _buildSectionTitle('Service Information'),
              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _descriptionController,
                label: 'Facility Description',
                icon: Icons.description,
                enabled: _isEditing,
                maxLines: 3,
                hintText:
                    'Describe your facility, specializations, and services...',
              ),

              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _servicesController,
                label: 'Services Offered',
                icon: Icons.medical_services,
                enabled: _isEditing,
                maxLines: 2,
                hintText:
                    'Emergency care, Surgery, Laboratory, Radiology, etc. (comma-separated)',
              ),

              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _operatingHoursController,
                label: 'Operating Hours',
                icon: Icons.access_time,
                enabled: _isEditing,
                hintText: 'Mon-Fri: 8:00 AM - 6:00 PM, Sat: 9:00 AM - 2:00 PM',
              ),

              const SizedBox(height: 16),

              _buildTextFormField(
                controller: _emergencyContactController,
                label: 'Emergency Contact',
                icon: Icons.emergency,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                hintText: '24/7 emergency contact number',
              ),

              const SizedBox(height: 32),

              // Statistics Section (if not editing)
              if (!_isEditing) ...[
                _buildSectionTitle('Facility Statistics'),
                const SizedBox(height: 16),
                _buildStatisticsCards(),
                const SizedBox(height: 32),
              ],

              // Profile Completeness
              if (!_isEditing) ...[
                _buildSectionTitle('Profile Status'),
                const SizedBox(height: 16),
                _buildProfileCompleteness(),
                const SizedBox(height: 32),
                _buildSectionTitle('Registration Document'),
                const SizedBox(height: 16),
                _buildDocumentUploadCard(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.teal,
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: enabled ? Colors.teal : Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Requests',
            '0', // This would be fetched from Firestore
            Icons.assignment,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            '0', // This would be fetched from Firestore
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Pending',
            '0', // This would be fetched from Firestore
            Icons.pending,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCompleteness() {
    final requiredFields = [
      _facilityData['facilityName'],
      _facilityData['phone'],
      _facilityData['address'],
    ];

    final completedFields = requiredFields
        .where((field) => field != null && field.toString().trim().isNotEmpty)
        .length;

    final percentage = (completedFields / requiredFields.length * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profile Completeness',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: percentage == 100 ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage == 100 ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            percentage == 100
                ? '✅ Profile is complete!'
                : '⚠️ Complete your profile to receive more service requests',
            style: TextStyle(
              fontSize: 12,
              color: percentage == 100 ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadCard(BuildContext context) {
    final docUrl = _facilityData['documentUrl'] as String?;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (docUrl != null && docUrl.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Document uploaded',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (await canLaunchUrl(Uri.parse(docUrl))) {
                        await launchUrl(
                          Uri.parse(docUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: const Text('View'),
                  ),
                ],
              )
            else
              const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No document uploaded',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(
                docUrl == null ? 'Upload Document' : 'Re-upload Document',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _pickAndUploadDocument(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadDocument(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final fileBytes = file.bytes;
      final fileName = file.name;
      if (fileBytes == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to read file.')));
        return;
      }
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not logged in.')));
        return;
      }
      final storageRef = FirebaseStorage.instance.ref().child(
        'facility_documents/$userId/$fileName',
      );
      final uploadTask = storageRef.putData(fileBytes);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'documentUrl': downloadUrl,
        'documentUploadedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _facilityData['documentUrl'] = downloadUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload document: $e')));
    }
  }
}
