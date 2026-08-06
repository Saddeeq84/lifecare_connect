// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/screens/privacy_screen.dart';
import '../../../shared/presentation/screens/service_agreement_screen.dart';
import '../../../shared/data/services/account_deletion_service.dart';
import '../../../shared/presentation/widgets/shareable_profile_widget.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../shared/presentation/screens/language_selector_screen.dart';
import '../../../../core/localization/app_localizations.dart';

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
  String userName = '';

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
          userName = data['name'] ?? 'CHW';
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
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(localizations.signOut),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout(context);
            },
            child: Text(
              localizations.signOut,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
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
          _buildSectionHeader(localizations.accountActions),
          _buildSettingsTile(
            icon: Icons.person,
            title: localizations.profile,
            subtitle: localizations.updateAccountPassword,
            onTap: () => context.push('/chw_dashboard/profile'),
          ),
          _buildSettingsTile(
            icon: Icons.security,
            title: 'Security',
            subtitle: localizations.changePassword,
            onTap: () => _showSecurityDialog(),
          ),

          const SizedBox(height: 24),

          // Shareable Profile Section
          _buildSectionHeader(localizations.shareYourProfile),
          ShareableProfileWidget(userId: currentUserId, userName: userName),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader(localizations.notifications),
          _buildSwitchTile(
            icon: Icons.notifications,
            title: localizations.pushNotifications,
            subtitle: localizations.enableNotifications,
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() => notificationsEnabled = value);
              _updateSetting('notificationsEnabled', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.email,
            title: localizations.emailNotifications,
            subtitle: localizations.receiveNotificationsViaEmail,
            value: emailNotifications,
            onChanged: (value) {
              setState(() => emailNotifications = value);
              _updateSetting('emailNotifications', value);
            },
          ),
          _buildSwitchTile(
            icon: Icons.sms,
            title: localizations.smsNotifications,
            subtitle: localizations.receiveNotificationsViaSMS,
            value: smsNotifications,
            onChanged: (value) {
              setState(() => smsNotifications = value);
              _updateSetting('smsNotifications', value);
            },
          ),

          const SizedBox(height: 24),

          // Preferences Section
          _buildSectionHeader(localizations.preferences),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) {
              return _buildSettingsTile(
                icon: Icons.language,
                title: localizations.language,
                subtitle: languageProvider.getLanguageNativeName(
                  languageProvider.locale.languageCode,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LanguageSelectorScreen(),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Service Agreement
          _buildSettingsTile(
            icon: Icons.description,
            title: localizations.serviceAgreement,
            subtitle: localizations.viewTermsOfService,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceAgreementScreen(userRole: 'chw'),
              ),
            ),
          ),

          // Privacy Policy
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: localizations.privacyPolicy,
            subtitle: localizations.viewPrivacyPolicy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PrivacyScreen()),
            ),
          ),

          // Help & Support (harmonized with patient)
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: localizations.helpAndSupport,
            subtitle: localizations.getHelpAndSupport,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(localizations.helpAndSupport),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          localizations.needHelpWithLifeCare,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '📧 ${localizations.email}: contact@lifecare.rhemn.org.ng',
                        ),
                        SizedBox(height: 8),
                        Text('📞 ${localizations.phone}: +2347072127123'),
                        SizedBox(height: 8),
                        Text(
                          '🕒 ${localizations.hours}: ${localizations.mondayToFriday}',
                        ),
                        SizedBox(height: 16),
                        Text(
                          '${localizations.commonIssues}:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('• ${localizations.loginProblems}'),
                        Text('• ${localizations.bookingIssues}'),
                        Text('• ${localizations.emergencyServices}'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(localizations.close),
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
                localizations.deleteAccount,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(localizations.permanentlyDeleteAccount),
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
                localizations.signOut,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text('Sign out of your account'),
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() async {
    final localizations = AppLocalizations.of(context)!;

    // Check if there's already a pending deletion request
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pendingRequest = await AccountDeletionService.getPendingRequest(
      user.uid,
    );

    if (pendingRequest != null) {
      // Show existing request dialog
      _showPendingRequestDialog(pendingRequest);
      return;
    }

    // Show deletion request dialog
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
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
                    localizations.requestAccountDeletion,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ℹ️ ${localizations.adminApprovalRequired}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'As a community health worker, your account deletion requires administrator approval to ensure proper handling of patient data.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
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
                          '⚠️ ${localizations.importantNotes}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• ${localizations.adminWillReview}',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• ${localizations.youWillBeNotified}',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• ${localizations.actionCannotBeUndone}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    localizations.reasonForDeletion,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: localizations.provideDeletionReason,
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
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: Text(localizations.cancel),
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
                          final userName =
                              userData?['fullName'] ??
                              userData?['name'] ??
                              'Unknown';
                          final userEmail =
                              userData?['email'] ?? user.email ?? '';

                          await AccountDeletionService.submitDeletionRequest(
                            userId: user.uid,
                            userRole: 'chw',
                            userName: userName,
                            userEmail: userEmail,
                            reason: reasonController.text.trim(),
                          );

                          if (mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  localizations.deletionRequestSubmitted,
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
                                content: Text(
                                  '${localizations.failedToSubmitRequest}: $e',
                                ),
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
                        localizations.submitDeletionRequest,
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
    final localizations = AppLocalizations.of(context)!;
    final requestedAt = (request['requestedAt'] as Timestamp?)?.toDate();
    final formattedDate = requestedAt != null
        ? '${requestedAt.day}/${requestedAt.month}/${requestedAt.year}'
        : 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                localizations.pendingDeletionRequest,
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
                    '⏳ ${localizations.requestStatus}: ${localizations.pending}',
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
            child: Text(
              localizations.cancelRequest,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showSecurityDialog() {
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Security Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock),
              title: Text(localizations.changePassword),
              onTap: () {
                Navigator.pop(ctx);
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
            onPressed: () => Navigator.pop(ctx),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  // ...existing code...
}
