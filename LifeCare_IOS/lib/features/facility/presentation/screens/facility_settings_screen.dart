// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/language_provider.dart';
import 'package:lifecare_connect/features/auth/presentation/screens/privacy_screen.dart';
import 'package:lifecare_connect/features/shared/presentation/screens/service_agreement_screen.dart';
import 'package:lifecare_connect/features/shared/presentation/screens/language_selector_screen.dart';
import 'package:lifecare_connect/features/shared/data/services/account_deletion_service.dart';
import 'package:lifecare_connect/features/shared/presentation/widgets/shareable_profile_widget.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';

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
      // Check if user is staff (no Firebase Auth)
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      if (userRole == 'service_provider_staff') {
        // For staff, we don't load facility-level settings
        // Just mark as loaded
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // For facility owner, load from Firebase
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
    final localizations = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.settings),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        // Save button removed for harmonization
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Share Profile Section
            _buildSectionHeader(localizations.shareYourProfile, Icons.share),
            ShareableProfileWidget(
              userId: FirebaseAuth.instance.currentUser?.uid ?? '',
              userName: 'Facility',
            ),
            const SizedBox(height: 32),

            // Notifications Section
            _buildSectionHeader(
              localizations.notifications,
              Icons.notifications,
            ),
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

            // Preferences Section
            _buildSectionHeader('Preferences', Icons.settings),
            const SizedBox(height: 16),
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, _) {
                return ListTile(
                  leading: const Icon(Icons.language, color: Colors.teal),
                  title: const Text(
                    'Language',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    languageProvider.getLanguageNativeName(
                      languageProvider.locale.languageCode,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LanguageSelectorScreen(),
                      ),
                    );
                  },
                );
              },
            ),

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
                          Text('📧 Email: contact@lifecare.rhemn.org.ng'),
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

            // System & Debug Section
            _buildSectionHeader(
              'System & Diagnostics',
              Icons.build,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 32),

            // Account Management Section
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
              leading: const Icon(Icons.description, color: Colors.teal),
              title: const Text('Service Agreement'),
              subtitle: const Text('View terms of service and user agreement'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ServiceAgreementScreen(userRole: 'facility'),
                ),
              ),
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
                  await _handleLogout();
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
      activeColor: Colors.teal,
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
    // Validation
    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your current password')),
      );
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a new password')),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    try {
      // Check if user is service provider staff (no Firebase Auth)
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      if (userRole == 'service_provider_staff') {
        // Handle staff password change without Firebase Auth
        await _changeStaffPassword();
        return;
      }

      // For facility owner/admin with Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get user document to check if they're a staff member
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User data not found')));
        }
        return;
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;

      // For facility staff, update both Firebase Auth and Firestore password
      if (role == 'staff') {
        final facilityName = userData['facilityName'] as String?;
        final staffId = userData['staffId'] as String?;

        if (facilityName == null || staffId == null) {
          if (mounted) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Staff information not found')),
            );
          }
          return;
        }

        // Get staff collection name
        final staffCollection =
            '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';

        // Find staff document and verify current password
        final staffQuery = await FirebaseFirestore.instance
            .collection(staffCollection)
            .where('staffId', isEqualTo: staffId)
            .limit(1)
            .get();

        if (staffQuery.docs.isEmpty) {
          if (mounted) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Staff record not found')),
            );
          }
          return;
        }

        final staffDoc = staffQuery.docs.first;
        final staffData = staffDoc.data();
        final storedPassword = staffData['password'] as String?;

        // Verify current password matches Firestore password
        if (storedPassword != _currentPasswordController.text) {
          if (mounted) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Current password is incorrect'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Update Firebase Auth password (try but don't fail if it doesn't work)
        try {
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: _currentPasswordController.text,
          );
          await user.reauthenticateWithCredential(credential);
          await user.updatePassword(_newPasswordController.text);
        } catch (authError) {
          print('Firebase Auth password update failed: $authError');
          // Continue anyway, Firestore update is more important for staff login
        }

        // Update Firestore password (this is what staff login uses)
        await staffDoc.reference.update({
          'password': _newPasswordController.text,
          'passwordSetAt': FieldValue.serverTimestamp(),
          'passwordUpdatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context); // Close loading
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Password updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Clear controllers
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        }
      } else {
        // For facility admin, update Firebase Auth password only
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPasswordController.text);

        if (mounted) {
          Navigator.pop(context); // Close loading
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Password updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Clear controllers
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        // Close loading if still open
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Change password for service provider staff (no Firebase Auth)
  Future<void> _changeStaffPassword() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final prefs = await SharedPreferences.getInstance();
      final facilityId = prefs.getString('facility_id');
      final facilityName = prefs.getString('facility_name');
      final staffId = prefs.getString('staff_id');

      if (facilityId == null || facilityName == null || staffId == null) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff information not found. Please login again.'),
            ),
          );
        }
        return;
      }

      // Get staff collection name
      final staffCollection =
          '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';

      // Find staff document and verify current password
      final staffQuery = await FirebaseFirestore.instance
          .collection(staffCollection)
          .where('staffId', isEqualTo: staffId)
          .limit(1)
          .get();

      if (staffQuery.docs.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff record not found')),
          );
        }
        return;
      }

      final staffDoc = staffQuery.docs.first;
      final staffData = staffDoc.data();
      final storedPassword = staffData['password'] as String?;

      // Verify current password
      if (storedPassword != _currentPasswordController.text) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current password is incorrect'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Update password in Firestore
      await FirebaseFirestore.instance
          .collection(staffCollection)
          .doc(staffDoc.id)
          .update({
            'password': _newPasswordController.text,
            'passwordChangedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context); // Close loading

        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle logout for both staff and owners
  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      if (userRole == 'service_provider_staff') {
        // Staff logout - clear SharedPreferences only
        await prefs.clear();
        if (mounted) {
          GoRouter.of(context).go('/service_provider_login');
        }
      } else {
        // Regular facility owner/admin logout - Firebase Auth signout only
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          GoRouter.of(context).go('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // _submitBugReport removed (no longer used)

  void _showDeleteAccountDialog() async {
    // Check if there's already a pending deletion request
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pendingRequest = await AccountDeletionService.getPendingRequest(
      user.uid,
    );

    if (pendingRequest != null) {
      _showPendingRequestDialog(pendingRequest);
      return;
    }

    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Request Account Deletion',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      'ℹ️ ADMIN APPROVAL REQUIRED\n\nAs a healthcare facility, your account deletion requires administrator approval to ensure proper handling of patient records and facility data.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Important Notes:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Admin will review within 48 hours',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Cannot be undone once approved',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Reason (optional):',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Reason for account deletion',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        try {
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .get();

                          final userData = userDoc.data();
                          final userName = userData?['name'] ?? 'Unknown';
                          final userEmail =
                              userData?['email'] ?? user.email ?? '';

                          await AccountDeletionService.submitDeletionRequest(
                            userId: user.uid,
                            userRole: 'facility',
                            userName: userName,
                            userEmail: userEmail,
                            reason: reasonController.text.trim(),
                          );

                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Deletion request submitted! Admin will review it shortly.',
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to submit request: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'SUBMIT REQUEST',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPendingRequestDialog(Map<String, dynamic> request) {
    final requestedAt = (request['requestedAt'] as Timestamp?)?.toDate();
    final formattedDate = requestedAt != null
        ? '${requestedAt.day}/${requestedAt.month}/${requestedAt.year}'
        : 'Unknown';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pending Deletion Request',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⏳ Status: PENDING',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Submitted: $formattedDate',
                    style: TextStyle(fontSize: 13),
                  ),
                  if (request['reason'] != null &&
                      (request['reason'] as String).isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      'Reason: ${request['reason']}',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                  SizedBox(height: 8),
                  Text(
                    'Your request is being reviewed by an administrator.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Cancel Request?'),
                  content: Text('Cancel your deletion request?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('No'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Yes, Cancel'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await AccountDeletionService.cancelDeletionRequest(
                    request['id'],
                  );
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Request cancelled'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to cancel: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: Text('Cancel Request', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
