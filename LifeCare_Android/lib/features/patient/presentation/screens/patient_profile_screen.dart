// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'edit_profile_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  bool notificationsEnabled = true;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('patient_profiles')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _profileData = doc.data();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load profile')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final fullName = _profileData?['fullName'] ?? 'Unknown';
    final age = (_profileData?['age'] ?? '').toString();
    final gender = _profileData?['gender'] ?? 'Not set';
    final phone = _profileData?['phone'] ?? 'Not set';
    final location = _profileData?['address'] ?? 'Not set';
    final photoUrl = _profileData?['photoUrl'];
    final patientId = user?.uid.substring(0, 6).toUpperCase() ?? 'LC-00000';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Icon(
                              Icons.person,
                              size: 48,
                              color: Colors.grey.shade600,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 14,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            );
                            if (updated == true) {
                              _fetchProfile(); // Refresh after editing
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Patient ID: $patientId'),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Profile'),
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                    if (updated == true) {
                      _fetchProfile(); // Refresh after editing
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 🔎 Personal Info
          const Text(
            'Personal Info',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _profileTile('Age', age),
          _profileTile('Gender', gender),
          _profileTile('Phone', phone),
          _profileTile('Location', location),

          const SizedBox(height: 30),

          // ⚙️ Settings
          const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SwitchListTile(
            value: notificationsEnabled,
            title: const Text('Enable Notifications'),
            onChanged: (value) {
              setState(() {
                notificationsEnabled = value;
              });
            },
            secondary: const Icon(Icons.notifications_active_outlined),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _profileTile(String title, String value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.grey)),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }
}
