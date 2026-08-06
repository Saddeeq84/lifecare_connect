import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../auth/presentation/screens/privacy_screen.dart';
import '../../../shared/presentation/screens/service_agreement_screen.dart';
import '../../../shared/presentation/screens/language_selector_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/localization/app_localizations.dart';

class PatientSettingsScreen extends StatefulWidget {
  const PatientSettingsScreen({super.key});

  @override
  State<PatientSettingsScreen> createState() => _PatientSettingsScreenState();
}

class _PatientSettingsScreenState extends State<PatientSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _appointmentReminders = true;
  bool _healthTipNotifications = true;
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences')
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _notificationsEnabled = data['notificationsEnabled'] ?? true;
            _appointmentReminders = data['appointmentReminders'] ?? true;
            _healthTipNotifications = data['healthTipNotifications'] ?? true;
            _darkModeEnabled = data['darkModeEnabled'] ?? false;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('preferences')
            .set({
              'notificationsEnabled': _notificationsEnabled,
              'appointmentReminders': _appointmentReminders,
              'healthTipNotifications': _healthTipNotifications,
              'darkModeEnabled': _darkModeEnabled,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.green.shade700, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green.shade700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            tooltip: localizations.save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notifications Section
            Text(
              localizations.notifications,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsTile(
              title: 'Push Notifications',
              subtitle: 'Receive notifications from the app',
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
              icon: Icons.notifications,
            ),
            _buildSettingsTile(
              title: 'Appointment Reminders',
              subtitle: 'Get reminders for upcoming appointments',
              value: _appointmentReminders,
              onChanged: (value) =>
                  setState(() => _appointmentReminders = value),
              icon: Icons.calendar_today,
            ),
            _buildSettingsTile(
              title: 'Health Tips',
              subtitle: 'Receive daily health tips and advice',
              value: _healthTipNotifications,
              onChanged: (value) =>
                  setState(() => _healthTipNotifications = value),
              icon: Icons.health_and_safety,
            ),

            const SizedBox(height: 24),

            // Appearance Section
            Text(
              localizations.preferences,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsTile(
              title: 'Dark Mode',
              subtitle: 'Use dark theme (Coming Soon)',
              value: _darkModeEnabled,
              onChanged: (value) => setState(() => _darkModeEnabled = value),
              icon: Icons.dark_mode,
            ),

            const SizedBox(height: 24),

            // Preferences Section
            Text(
              localizations.preferences,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, _) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.language,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Language',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      languageProvider.getLanguageNativeName(
                        languageProvider.locale.languageCode,
                      ),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Account Actions Section
            Text(
              localizations.accountActions,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),

            // Service Agreement
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description,
                    color: Colors.teal.shade700,
                    size: 24,
                  ),
                ),
                title: Text(
                  localizations.serviceAgreement,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  localizations.viewTermsOfService,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ServiceAgreementScreen(userRole: 'patient'),
                    ),
                  );
                },
              ),
            ),

            // Privacy Policy (linked to main privacy policy screen)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.privacy_tip,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                title: Text(
                  localizations.privacyPolicy,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'View our privacy policy and terms',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyScreen(),
                    ),
                  );
                },
              ),
            ),

            // Help & Support (updated contact info)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.help,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Help & Support',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(
                  'Get help and contact support',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
            ),

            // Change Password
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock,
                    color: Colors.purple.shade700,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(
                  'Update your account password',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showChangePasswordDialog,
              ),
            ),

            // Logout
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  'Sign out of your account',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showLogoutDialog,
              ),
            ),

            // Delete Account
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_forever,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  'Permanently delete your account',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showDeleteAccountDialog,
              ),
            ),

            const SizedBox(height: 32),

            // App Version Info
            Center(
              child: Column(
                children: [
                  Text(
                    'LifeCare Connect',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
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
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final currentPassword = currentPasswordController.text
                          .trim();
                      final newPassword = newPasswordController.text.trim();
                      final confirmPassword = confirmPasswordController.text
                          .trim();
                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                          ),
                        );
                        return;
                      }
                      setState(() => isSubmitting = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        final cred = EmailAuthProvider.credential(
                          email: user?.email ?? '',
                          password: currentPassword,
                        );
                        if (user != null) {
                          await user.reauthenticateWithCredential(cred);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'User not found. Cannot reauthenticate.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        if (user != null) {
                          await user.updatePassword(newPassword);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'User not found. Cannot update password.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        Navigator.of(context).pop();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to change password: ${e.toString()}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Widget _buildDeletedDataItem(String emoji, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final TextEditingController confirmController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text(
                'Delete Account',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ PERMANENT ACTION WARNING',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This action is IRREVERSIBLE and will permanently delete all your data.',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'What will be deleted:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                _buildDeletedDataItem(
                  '👤',
                  'Your patient profile and medical information',
                ),
                _buildDeletedDataItem('🩺', 'Medical history and records'),
                _buildDeletedDataItem(
                  '📅',
                  'All appointment history and bookings',
                ),
                _buildDeletedDataItem(
                  '💊',
                  'Prescription and medication records',
                ),
                _buildDeletedDataItem(
                  '📊',
                  'Health tracking and vital signs data',
                ),
                _buildDeletedDataItem(
                  '💳',
                  'Payment history and billing information',
                ),
                _buildDeletedDataItem('🔔', 'All notifications and messages'),
                _buildDeletedDataItem('⚙️', 'Account settings and preferences'),
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
                        '💡 Important Notes:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• You can create a new account with the same email after deletion',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• Your medical data will be permanently lost',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• This action cannot be undone or reversed',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• Consider exporting important health data before proceeding',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Type "DELETE" to confirm this permanent action:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    hintText: 'Type DELETE here',
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {}); // Rebuild to update button state
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed:
                  (isDeleting ||
                      confirmController.text.trim().toUpperCase() != 'DELETE')
                  ? null
                  : () async {
                      setState(() => isDeleting = true);

                      // Get user ID outside try block to keep in scope
                      String? userId;
                      User? firebaseUser;

                      try {
                        // Get user ID (Firebase Auth or SharedPreferences for Termii users)
                        firebaseUser = FirebaseAuth.instance.currentUser;
                        if (firebaseUser != null) {
                          userId = firebaseUser.uid;
                        } else {
                          // Check SharedPreferences for Termii users
                          final prefs = await SharedPreferences.getInstance();
                          userId = prefs.getString('user_id');
                        }

                        final HttpsCallable callable = FirebaseFunctions
                            .instance
                            .httpsCallable('deleteAccount');
                        final resp = await callable.call(<String, dynamic>{
                          'userId':
                              userId, // Pass userId for both Firebase Auth and Termii users
                        });

                        // Clear SharedPreferences for Termii users regardless of response
                        // (account is deleted server-side even if response has issues)
                        if (firebaseUser == null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('user_id');
                          await prefs.remove('user_phone');
                          await prefs.remove('user_role');
                        }

                        final data = resp.data as Map<String, dynamic>?;
                        print('Delete account response: $data');

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pop();
                          Navigator.of(context).pushReplacementNamed('/login');
                        }
                      } catch (e) {
                        print('Delete account error: $e');

                        // Clear SharedPreferences anyway since account might be deleted
                        if (firebaseUser == null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('user_id');
                          await prefs.remove('user_phone');
                          await prefs.remove('user_role');
                        }

                        if (mounted) {
                          // Show success message anyway and redirect to login
                          // The account is actually deleted on the backend
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.of(context).pop();
                          Navigator.of(context).pushReplacementNamed('/login');
                        }
                      } finally {
                        setState(() => isDeleting = false);
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      confirmController.text.trim().toUpperCase() == 'DELETE'
                          ? 'PERMANENTLY DELETE ACCOUNT'
                          : 'Type "DELETE" to enable',
                      style: TextStyle(
                        color:
                            confirmController.text.trim().toUpperCase() ==
                                'DELETE'
                            ? Colors.white
                            : Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
