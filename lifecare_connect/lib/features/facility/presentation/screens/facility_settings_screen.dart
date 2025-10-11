// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifecare_connect/features/auth/presentation/screens/privacy_screen.dart';
import 'package:go_router/go_router.dart';

class FacilitySettingsScreen extends StatefulWidget {
  const FacilitySettingsScreen({super.key});

  @override
  State<FacilitySettingsScreen> createState() => _FacilitySettingsScreenState();
}

class _FacilitySettingsScreenState extends State<FacilitySettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _newRequestAlerts = true;
  bool _appointmentReminders = true;
  bool _autoApproval = false;
  bool _isLoading = true;
  // bool _isSaving = false; // Removed, no longer used

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final settings = data['settings'] as Map<String, dynamic>? ?? {};

        setState(() {
          _notificationsEnabled = settings['notificationsEnabled'] ?? true;
          _emailNotifications = settings['emailNotifications'] ?? true;
          _smsNotifications = settings['smsNotifications'] ?? false;
          _newRequestAlerts = settings['newRequestAlerts'] ?? true;
          _appointmentReminders = settings['appointmentReminders'] ?? true;
          _autoApproval = settings['autoApproval'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading settings: $e')));
      }
    }
  }

  // _saveSettings removed (no longer used)

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Settings'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        // Save button removed for harmonization
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notifications Section
            _buildSectionHeader('Notifications', Icons.notifications),
            const SizedBox(height: 16),

            _buildSwitchTile(
              'Enable Notifications',
              'Receive notifications for new requests and updates',
              _notificationsEnabled,
              (value) => setState(() => _notificationsEnabled = value),
            ),

            if (_notificationsEnabled) ...[
              _buildSwitchTile(
                'Email Notifications',
                'Receive notifications via email',
                _emailNotifications,
                (value) => setState(() => _emailNotifications = value),
              ),

              _buildSwitchTile(
                'SMS Notifications',
                'Receive notifications via SMS',
                _smsNotifications,
                (value) => setState(() => _smsNotifications = value),
              ),

              _buildSwitchTile(
                'New Request Alerts',
                'Get immediate alerts for new service requests',
                _newRequestAlerts,
                (value) => setState(() => _newRequestAlerts = value),
              ),

              _buildSwitchTile(
                'Appointment Reminders',
                'Receive reminders for upcoming appointments',
                _appointmentReminders,
                (value) => setState(() => _appointmentReminders = value),
              ),
            ],

            const SizedBox(height: 32),

            // ...existing code...

            // Removed duplicate 'Account Management' section header
            const SizedBox(height: 16),
            const SizedBox(height: 32),

            // Help & Support Section
            _buildSectionHeader('Help & Support', Icons.help),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.teal),
              title: const Text('Help & Support'),
              subtitle: const Text('Get help and contact support'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Help & Support'),
                    content: const SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Need help with LifeCare Connect?',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 16),
                          Text('📧 Email: contact_lifecare@rhemn.org.ng'),
                          SizedBox(height: 8),
                          Text('📞 Phone: +2347072127123'),
                          SizedBox(height: 8),
                          Text('🕒 Hours: Monday - Friday, 8AM - 6PM'),
                          SizedBox(height: 16),
                          Text(
                            'Common Issues:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text('• Login problems: Check internet connection'),
                          Text(
                            '• Booking issues: Ensure all fields are filled',
                          ),
                          Text(
                            '• Emergency services: Call 199 for immediate help',
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Danger Zone
            _buildSectionHeader(
              'Account Management',
              Icons.warning,
              color: Colors.red,
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.lock, color: Colors.teal),
              title: const Text('Change Password'),
              subtitle: const Text('Update your account password'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showChangePasswordDialog,
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip, color: Colors.teal),
              title: const Text('Privacy Policy'),
              subtitle: const Text('View our privacy policy'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrivacyScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Permanently delete your facility account'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showDeleteAccountDialog,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Sign out of your account'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    GoRouter.of(context).go('/login');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.teal, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.teal,
    );
  }

  // _showOperatingHoursDialog removed (no longer used)

  // _showServiceCategoriesDialog removed (no longer used)

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _changePassword,
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Password updated successfully!')),
        );

        // Clear controllers
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error changing password: $e')));
      }
    }
  }

  // _submitBugReport removed (no longer used)

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your facility account? This action cannot be undone and all your data will be permanently lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show final confirmation dialog
              bool? finalConfirm = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Final Confirmation'),
                    content: const Text(
                      'Are you absolutely sure you want to delete your facility account?\n\n'
                      'This action will:\n'
                      '• Delete all facility data\n'
                      '• Remove all services and items\n'
                      '• Cancel all pending appointments\n'
                      '• Permanently remove your facility from the platform\n\n'
                      'This action cannot be undone!',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Yes, Delete Account'),
                      ),
                    ],
                  );
                },
              );

              if (finalConfirm == true) {
                try {
                  // Show loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const AlertDialog(
                        content: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 20),
                            Text('Deleting account...'),
                          ],
                        ),
                      );
                    },
                  );

                  // Implement actual account deletion with Firebase
                  final user = FirebaseAuth.instance.currentUser;
                  final facilityId = user?.uid;

                  if (user == null || facilityId == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ User not authenticated'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    // Use Firestore batch for atomic operations
                    final batch = FirebaseFirestore.instance.batch();

                    // 1. Delete all facility subcollections (services, items, etc.)
                    final servicesQuery = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(facilityId)
                        .collection('services')
                        .get();

                    for (final doc in servicesQuery.docs) {
                      batch.delete(doc.reference);
                    }

                    final itemsQuery = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(facilityId)
                        .collection('items')
                        .get();

                    for (final doc in itemsQuery.docs) {
                      batch.delete(doc.reference);
                    }

                    // 2. Cancel all related appointments and service requests
                    final serviceRequestsQuery = await FirebaseFirestore
                        .instance
                        .collection('service_requests')
                        .where('facilityId', isEqualTo: facilityId)
                        .get();

                    for (final doc in serviceRequestsQuery.docs) {
                      batch.update(doc.reference, {
                        'status': 'cancelled',
                        'cancellationReason': 'Facility account deleted',
                        'cancelledAt': FieldValue.serverTimestamp(),
                      });
                    }

                    // Cancel appointments
                    final appointmentsQuery = await FirebaseFirestore.instance
                        .collection('appointments')
                        .where('facilityId', isEqualTo: facilityId)
                        .get();

                    for (final doc in appointmentsQuery.docs) {
                      batch.update(doc.reference, {
                        'status': 'cancelled',
                        'cancellationReason': 'Facility account deleted',
                        'cancelledAt': FieldValue.serverTimestamp(),
                      });
                    }

                    // 3. Create audit record before deletion
                    batch.set(
                      FirebaseFirestore.instance
                          .collection('deleted_accounts')
                          .doc(facilityId),
                      {
                        'userId': facilityId,
                        'userType': 'facility',
                        'userEmail': user.email,
                        'deletedAt': FieldValue.serverTimestamp(),
                        'deletionReason': 'User requested account deletion',
                      },
                    );

                    // 4. Delete the main facility document
                    batch.delete(
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(facilityId),
                    );

                    // Commit all Firestore operations
                    await batch.commit();

                    // 5. Delete user authentication (must be last)
                    await user.delete();

                    Navigator.pop(context); // Close loading dialog

                    // Navigate to login screen
                    GoRouter.of(context).go('/login');

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Account deleted successfully'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context); // Close loading dialog

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error deleting account: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );

                    // Log error for debugging
                    try {
                      await FirebaseFirestore.instance
                          .collection('deletion_errors')
                          .add({
                            'userId': facilityId,
                            'error': e.toString(),
                            'timestamp': FieldValue.serverTimestamp(),
                            'userType': 'facility',
                          });
                    } catch (_) {
                      // Ignore logging errors
                    }
                  }
                } catch (outerError) {
                  // Handle any unexpected errors
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Unexpected error: $outerError'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }
}
