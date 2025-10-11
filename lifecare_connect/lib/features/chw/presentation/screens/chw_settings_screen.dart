// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/screens/privacy_screen.dart';

class CHWSettingsScreen extends StatefulWidget {
  const CHWSettingsScreen({super.key});

  @override
  State<CHWSettingsScreen> createState() => _CHWSettingsScreenState();
}

class _CHWSettingsScreenState extends State<CHWSettingsScreen> {
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool notificationsEnabled = true;
  bool emailNotifications = true;
  bool smsNotifications = false;
  String language = 'English';
  String theme = 'System';

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          notificationsEnabled = data['notificationsEnabled'] ?? true;
          emailNotifications = data['emailNotifications'] ?? true;
          smsNotifications = data['smsNotifications'] ?? false;
          language = data['language'] ?? 'English';
          theme = data['theme'] ?? 'System';
        });
      }
    } catch (e) {
      // Handle error silently or show snackbar
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({key: value});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update setting: $e')));
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

  Future<void> _changePassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔐 Password reset link sent to your email'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout(context);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHW Settings'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            icon: Icons.person,
            title: 'Profile Information',
            subtitle: 'Update your personal details',
            onTap: () => context.push('/profile'),
          ),
          _buildSettingsTile(
            icon: Icons.security,
            title: 'Security',
            subtitle: 'Change password and security settings',
            onTap: () => _showSecurityDialog(),
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            icon: Icons.notifications,
            title: 'Push Notifications',
            subtitle: 'Receive notifications on this device',
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() => notificationsEnabled = value);
              _updateSetting('notificationsEnabled', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.email,
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: emailNotifications,
            onChanged: (value) {
              setState(() => emailNotifications = value);
              _updateSetting('emailNotifications', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.sms,
            title: 'SMS Notifications',
            subtitle: 'Receive notifications via SMS',
            value: smsNotifications,
            onChanged: (value) {
              setState(() => smsNotifications = value);
              _updateSetting('smsNotifications', value);
            },
          ),

          const SizedBox(height: 24),

          // Privacy Policy
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PrivacyScreen()),
            ),
          ),

          // Help & Support (harmonized with patient)
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
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
                        Text('• Booking issues: Ensure all fields are filled'),
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

          // Delete Account
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
              title: Text(
                'Delete Account',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Permanently delete your account'),
              onTap: _showDeleteAccountDialog,
            ),
          ),
          const SizedBox(height: 32),

          // Logout Button
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red.shade700),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Sign out of your account'),
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    // Duplicate/invalid code removed. Only one implementation of _showDeleteAccountDialog remains above.
    // Removed orphaned/duplicate widget and function code
    showDialog(
      context: context,
      builder: (context) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'Are you sure you want to permanently delete your account? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setState(() => isDeleting = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user!.uid)
                              .delete();
                          await user.delete();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop();
                            context.go('/login');
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to delete account: \\${e.toString()}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          setState(() => isDeleting = false);
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.pop(context);
                _changePassword(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Two-Factor Authentication'),
              subtitle: const Text('Coming soon'),
              enabled: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ...existing code...
}
