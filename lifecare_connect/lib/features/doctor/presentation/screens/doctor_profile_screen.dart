import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool isLoading = true;
  Map<String, dynamic> doctorData = {};
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadDoctorProfile();
  }

  Future<void> _loadDoctorProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          doctorData = doc.data()!;
          profileImageUrl = doctorData['profileImageUrl'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("My Profile"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final name = doctorData['name'] ?? doctorData['fullName'] ?? 'Doctor';
    final email =
        doctorData['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
    final phone = doctorData['phone'] ?? 'Not provided';
    final specialty = doctorData['specialty'] ?? 'Not specified';
    final hospital = doctorData['hospitalAffiliation'] ?? 'Not specified';
    final license = doctorData['licenseNumber'] ?? 'Not provided';
    final licenseUrl = doctorData['licenseUrl'] as String?;
    final experience = doctorData['yearsOfExperience']?.toString() ?? '0';
    final bio = doctorData['bio'] ?? 'No bio available';

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditDoctorProfileScreen(),
                ),
              ).then((_) => _loadDoctorProfile());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDoctorProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.indigo.shade100,
                backgroundImage: profileImageUrl != null
                    ? NetworkImage(profileImageUrl!)
                    : null,
                child: profileImageUrl == null
                    ? const Icon(Icons.person, size: 60, color: Colors.indigo)
                    : null,
              ),
              const SizedBox(height: 16),

              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                specialty,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              _buildSectionHeader('Contact Information'),
              _buildInfoCard([
                _buildInfoTile(Icons.email, 'Email', email),
                _buildInfoTile(Icons.phone, 'Phone', phone),
              ]),

              const SizedBox(height: 24),

              _buildSectionHeader('Professional Information'),
              _buildInfoCard([
                _buildInfoTile(
                  Icons.local_hospital,
                  'Hospital/Clinic',
                  hospital,
                ),
                _buildInfoTile(Icons.badge, 'License Number', license),
                _buildInfoTile(
                  Icons.work,
                  'Years of Experience',
                  '$experience years',
                ),
              ]),

              const SizedBox(height: 24),

              _buildSectionHeader('Medical License'),
              _buildLicenseUploadCard(context, licenseUrl),
              const SizedBox(height: 24),

              if (bio.isNotEmpty && bio != 'No bio available') ...[
                _buildSectionHeader('About'),
                _buildInfoCard([
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      bio,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
              ],

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditDoctorProfileScreen(),
                          ),
                        ).then((_) => _loadDoctorProfile());
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("Edit Profile"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseUploadCard(BuildContext context, String? licenseUrl) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (licenseUrl != null && licenseUrl.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'License uploaded',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      // Open the license file in browser
                      if (await canLaunchUrl(Uri.parse(licenseUrl))) {
                        await launchUrl(
                          Uri.parse(licenseUrl),
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
                      'No license uploaded',
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
                licenseUrl == null ? 'Upload License' : 'Re-upload License',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _pickAndUploadLicense(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadLicense(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
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
        'doctor_licenses/$userId/$fileName',
      );
      final uploadTask = storageRef.putData(fileBytes);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'licenseUrl': downloadUrl,
        'licenseUploadedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          doctorData['licenseUrl'] = downloadUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('License uploaded successfully.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload license: $e')));
    }
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(value),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class EditDoctorProfileScreen extends StatefulWidget {
  const EditDoctorProfileScreen({super.key});

  @override
  State<EditDoctorProfileScreen> createState() =>
      _EditDoctorProfileScreenState();
}

class _EditDoctorProfileScreenState extends State<EditDoctorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool isLoading = true;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadDoctorProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _licenseController.dispose();
    _hospitalController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? data['fullName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _specialtyController.text = data['specialty'] ?? '';
          _licenseController.text = data['licenseNumber'] ?? '';
          _hospitalController.text = data['hospitalAffiliation'] ?? '';
          _experienceController.text =
              data['yearsOfExperience']?.toString() ?? '';
          _bioController.text = data['bio'] ?? '';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isUpdating = true);

    try {
      final profileData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialty': _specialtyController.text.trim(),
        'licenseNumber': _licenseController.text.trim(),
        'hospitalAffiliation': _hospitalController.text.trim(),
        'yearsOfExperience': _experienceController.text.trim().isNotEmpty
            ? int.tryParse(_experienceController.text.trim()) ?? 0
            : 0,
        'bio': _bioController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update(profileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error updating profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (!isLoading)
            TextButton.icon(
              onPressed: isUpdating ? null : _saveProfile,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Personal Information'),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (value) => value?.trim().isEmpty ?? true
                          ? 'Name is required'
                          : null,
                    ),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader('Professional Information'),
                    _buildTextField(
                      controller: _specialtyController,
                      label: 'Medical Specialty',
                      icon: Icons.medical_services,
                      validator: (value) => value?.trim().isEmpty ?? true
                          ? 'Specialty is required'
                          : null,
                    ),
                    _buildTextField(
                      controller: _licenseController,
                      label: 'Medical License Number',
                      icon: Icons.badge,
                    ),
                    _buildTextField(
                      controller: _hospitalController,
                      label: 'Hospital/Clinic Affiliation',
                      icon: Icons.local_hospital,
                    ),
                    _buildTextField(
                      controller: _experienceController,
                      label: 'Years of Experience',
                      icon: Icons.work,
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader('About'),
                    _buildTextField(
                      controller: _bioController,
                      label: 'Professional Bio',
                      icon: Icons.description,
                      maxLines: 4,
                      hint:
                          'Tell patients about your background, experience, and approach to healthcare...',
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isUpdating ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isUpdating
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
                                'Save Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.indigo),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
        ),
      ),
    );
  }
}
