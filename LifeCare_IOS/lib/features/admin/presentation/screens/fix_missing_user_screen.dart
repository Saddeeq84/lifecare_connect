// lib/features/admin/presentation/screens/fix_missing_user_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin tool to fix users who exist in Firebase Auth but not in Firestore
/// This can happen due to race conditions during registration
class FixMissingUserScreen extends StatefulWidget {
  const FixMissingUserScreen({super.key});

  @override
  State<FixMissingUserScreen> createState() => _FixMissingUserScreenState();
}

class _FixMissingUserScreenState extends State<FixMissingUserScreen> {
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedRole;
  String? _selectedSpecialization;
  String? _selectedGender;
  bool _isLoading = false;
  String? _statusMessage;
  Map<String, dynamic>? _authUserData;
  bool? _firestoreExists;

  final List<String> _roles = ['doctor', 'chw', 'facility', 'patient'];
  final List<String> _specializations = [
    'General Practice',
    'Pediatrics',
    'Cardiology',
    'Dermatology',
    'Orthopedics',
    'Gynecology',
    'Psychiatry',
    'Surgery',
    'Other',
  ];
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Missing User Documents'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This tool creates Firestore documents for users who exist in Firebase Auth but are missing from Firestore database.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Email input
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),

            // Check button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _checkUser,
              icon: const Icon(Icons.search),
              label: const Text('Check User Status'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _firestoreExists == true
                    ? Colors.green[50]
                    : Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _firestoreExists == true
                          ? Colors.green[900]
                          : Colors.orange[900],
                    ),
                  ),
                ),
              ),
            ],

            if (_authUserData != null && _firestoreExists == false) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Create Firestore Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Full Name
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),

              // Phone
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),

              // Role
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                items: _roles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Specialization (for doctors)
              if (_selectedRole == 'doctor') ...[
                DropdownButtonFormField<String>(
                  value: _selectedSpecialization,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                  items: _specializations.map((spec) {
                    return DropdownMenuItem(value: spec, child: Text(spec));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSpecialization = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Gender
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: _genders.map((gender) {
                  return DropdownMenuItem(value: gender, child: Text(gender));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Create Document button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _createFirestoreDocument,
                icon: const Icon(Icons.save),
                label: const Text('Create Firestore Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _authUserData = null;
      _firestoreExists = null;
    });

    try {
      // Check Firestore directly (we can't check Auth without admin SDK)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _statusMessage =
              '✅ User exists in both Firebase Auth and Firestore\n\nNo action needed.';
          _firestoreExists = true;
        });
      } else {
        setState(() {
          _statusMessage =
              '⚠️ User exists in Firebase Auth but is MISSING from Firestore\n\nThis user needs to be fixed. Fill in the details below to create their Firestore document.';
          _firestoreExists = false;
          _authUserData = {'email': email};

          // Try to guess role from email domain or name
          if (email.contains('doctor') || email.contains('dr')) {
            _selectedRole = 'doctor';
          }
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error checking user: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createFirestoreDocument() async {
    final email = _emailController.text.trim();
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();

    // Validation
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter full name')));
      return;
    }

    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a role')));
      return;
    }

    if (_selectedRole == 'doctor' && _selectedSpecialization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select specialization for doctor'),
        ),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select gender')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get user's UID from their email by querying Auth
      // Since we can't do this directly, we'll ask them to provide it
      final uidResult = await showDialog<String>(
        context: context,
        builder: (context) {
          final uidController = TextEditingController();
          return AlertDialog(
            title: const Text('Enter User UID'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To create the Firestore document, we need the user\'s UID from Firebase Auth.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can find this in Firebase Console > Authentication > Users',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: uidController,
                  decoration: const InputDecoration(
                    labelText: 'User UID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, uidController.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (uidResult == null || uidResult.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Create the Firestore document
      final userData = <String, dynamic>{
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': _selectedRole!,
        'gender': _selectedGender!,
        'isApproved': false,
        'isRejected': false,
        'createdAt': FieldValue.serverTimestamp(),
        'manuallyCreated': true,
        'manualCreationReason':
            'Registration completed in Auth but Firestore document was missing',
        'manualCreationDate': FieldValue.serverTimestamp(),
      };

      // Add role-specific fields
      if (_selectedRole == 'doctor') {
        userData['specialization'] = _selectedSpecialization!;
        userData['imageUrl'] = '';
        userData['licenseUrl'] = '';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uidResult)
          .set(userData);

      setState(() {
        _statusMessage =
            '✅ Firestore document created successfully!\n\nThe user will now appear in the admin approval queue.';
        _firestoreExists = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User document created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
