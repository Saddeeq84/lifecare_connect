import 'package:lifecare_connect/features/auth/presentation/screens/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorSettingsScreen extends StatefulWidget {
  const DoctorSettingsScreen({super.key});

  @override
  State<DoctorSettingsScreen> createState() => _DoctorSettingsScreenState();
}

class _DoctorSettingsScreenState extends State<DoctorSettingsScreen> {
  bool emailNotifications = true;
  bool smsNotifications = false;
  String language = 'English';
  String theme = 'System';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Notifications'),
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
          _buildSectionHeader('Preferences'),
          _buildDropdownTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'Choose your preferred language',
            value: language,
            items: ['English', 'Hausa', 'French'],
            onChanged: (value) {
              setState(() => language = value!);
              _updateSetting('language', value);
            },
          ),
          _buildDropdownTile(
            icon: Icons.palette,
            title: 'Theme',
            subtitle: 'Choose your preferred theme',
            value: theme,
            items: ['Light', 'Dark', 'System'],
            onChanged: (value) {
              setState(() => theme = value!);
              _updateSetting('theme', value);
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Privacy Policy'),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PrivacyScreen()),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Help & Support'),
          _buildSettingsTile(
            icon: Icons.help,
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
              onTap: _showLogoutDialog,
            ),
          ),
        ],
      ),
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
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.indigo),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.indigo,
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: DropdownButton<String>(
          value: value,
          underline: Container(),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _updateSetting(String key, dynamic value) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({key: value});
    } catch (e) {
      // Handle error
    }
  }

  void _showDeleteAccountDialog() {
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
                              const SnackBar(
                                content: Text(
                                  'Failed to delete account: e.toString()}',
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pop();
                  context.go('/login');
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
