// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../shared/presentation/screens/service_agreement_screen.dart';
import '../../../shared/presentation/screens/language_selector_screen.dart';
import 'package:lifecare_connect/features/shared/presentation/widgets/shareable_profile_widget.dart';
import '../../../../core/localization/app_localizations.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool darkMode = false;
  bool notificationsEnabled = true;
  String userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            userName = doc.data()?['name'] ?? '';
          });
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  void _saveSettings() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Settings saved (UI only)")));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            localizations.shareYourProfile,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ShareableProfileWidget(
            userId: FirebaseAuth.instance.currentUser?.uid ?? '',
            userName: userName,
          ),
          const SizedBox(height: 30),

          Text(
            localizations.preferences,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SwitchListTile(
            title: Text(localizations.darkMode),
            value: darkMode,
            onChanged: (val) {
              setState(() {
                darkMode = val;
              });
            },
          ),
          SwitchListTile(
            title: Text(localizations.enableNotifications),
            value: notificationsEnabled,
            onChanged: (val) {
              setState(() {
                notificationsEnabled = val;
              });
            },
          ),
          const SizedBox(height: 20),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.language, color: Colors.deepPurple),
                  title: Text(
                    localizations.preferredLanguage,
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
                ),
              );
            },
          ),
          const SizedBox(height: 30),

          Text(
            localizations.legalAndSupport,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.teal),
            title: Text(localizations.serviceAgreement),
            subtitle: Text(localizations.viewTermsOfService),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceAgreementScreen(userRole: 'admin'),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.red),
            title: const Text('Report a Bug'),
            subtitle: const Text('Report issues or technical problems'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _showBugReportDialog,
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: Text(localizations.save),
          ),
        ],
      ),
    );
  }

  void _showBugReportDialog() {
    final bugController = TextEditingController();
    String selectedCategory = 'General';
    String selectedPriority = 'Medium';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report a Bug'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please describe the issue you encountered:'),
                const SizedBox(height: 16),
                TextField(
                  controller: bugController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Describe the bug in detail...',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                const Text('Category:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'General',
                            'UI/UX',
                            'Performance',
                            'Crash',
                            'Feature Request',
                          ]
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Priority:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: ['Low', 'Medium', 'High', 'Critical']
                      .map(
                        (priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPriority = value!;
                    });
                  },
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
                      if (bugController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please describe the issue'),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        isSubmitting = true;
                      });

                      await _submitBugReport(
                        bugController.text.trim(),
                        selectedCategory,
                        selectedPriority,
                      );

                      Navigator.of(context).pop();
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitBugReport(
    String description,
    String category,
    String priority,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get admin details
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final adminData = adminDoc.data();

      // Generate ticket ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ticketId =
          'BUG-${timestamp.toString().substring(timestamp.toString().length - 8)}';

      // Collect device info (simplified for web compatibility)
      final deviceInfo = {
        'platform': 'Flutter',
        'timestamp': DateTime.now().toIso8601String(),
        'userAgent': 'LifeCare Connect App',
      };

      await FirebaseFirestore.instance.collection('bug_reports').add({
        'ticketId': ticketId,
        'description': description,
        'category': category,
        'priority': priority,
        'status': 'Open',
        'reportedBy': user.uid,
        'reporterEmail': user.email ?? '',
        'reporterRole': 'admin',
        'reporterName': adminData?['fullName'] ?? 'System Admin',
        'deviceInfo': deviceInfo,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bug report submitted successfully! Ticket ID: $ticketId',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit bug report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// This file defines the Admin Settings screen for the app.
// It allows admins to configure app preferences like dark mode, notifications, and language.
