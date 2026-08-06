import 'package:lifecare_connect/features/auth/presentation/screens/privacy_screen.dart';
import 'package:lifecare_connect/features/shared/presentation/screens/service_agreement_screen.dart';
import 'package:lifecare_connect/features/shared/data/services/account_deletion_service.dart';
import 'package:lifecare_connect/features/shared/presentation/widgets/shareable_profile_widget.dart';
import 'package:lifecare_connect/features/shared/presentation/screens/language_selector_screen.dart';
import 'package:lifecare_connect/core/providers/language_provider.dart';
import 'package:lifecare_connect/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

class DoctorSettingsScreen extends StatefulWidget {
  const DoctorSettingsScreen({super.key});

  @override
  State<DoctorSettingsScreen> createState() => _DoctorSettingsScreenState();
}

class _DoctorSettingsScreenState extends State<DoctorSettingsScreen> {
  bool emailNotifications = true;
  bool smsNotifications = false;
  String theme = 'system';
  String userName = '';
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          userName = data?['name'] ?? 'Doctor';
          // Normalize theme value to lowercase constants
          final dbTheme = data?['theme']?.toString().toLowerCase() ?? 'system';
          theme = ['light', 'dark', 'system'].contains(dbTheme)
              ? dbTheme
              : 'system';
        });
      }
    } catch (e) {
      // Handle silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
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
          _buildSectionHeader(localizations.shareYourProfile),
          ShareableProfileWidget(userId: currentUserId, userName: userName),
          const SizedBox(height: 24),
          _buildSectionHeader(localizations.notifications),
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
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.palette, color: Colors.indigo),
              title: Text(localizations.theme),
              subtitle: Text(localizations.choosePreferredTheme),
              trailing: DropdownButton<String>(
                value: theme,
                underline: Container(),
                items: [
                  DropdownMenuItem(
                    value: 'light',
                    child: Text(localizations.light),
                  ),
                  DropdownMenuItem(
                    value: 'dark',
                    child: Text(localizations.dark),
                  ),
                  DropdownMenuItem(
                    value: 'system',
                    child: Text(localizations.system),
                  ),
                ],
                onChanged: (value) {
                  setState(() => theme = value!);
                  _updateSetting('theme', value);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(localizations.legalAndPrivacy),
          _buildSettingsTile(
            icon: Icons.description,
            title: localizations.serviceAgreement,
            subtitle: localizations.viewTermsOfService,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const ServiceAgreementScreen(userRole: 'doctor'),
              ),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: localizations.privacyPolicy,
            subtitle: localizations.viewPrivacyPolicy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PrivacyScreen()),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(localizations.helpAndSupport),
          _buildSettingsTile(
            icon: Icons.help,
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '📧 ${localizations.email}: contact@lifecare.rhemn.org.ng',
                        ),
                        const SizedBox(height: 8),
                        Text('📞 ${localizations.phone}: +2347072127123'),
                        const SizedBox(height: 8),
                        Text(
                          '🕒 ${localizations.hours}: ${localizations.mondayToFriday}',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${localizations.commonIssues}:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('• ${localizations.loginProblems}'),
                        Text('• ${localizations.bookingIssues}'),
                        Text('• ${localizations.emergencyServices}'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(localizations.close),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader(localizations.accountActions),
          _buildSettingsTile(
            icon: Icons.lock,
            title: localizations.changePassword,
            subtitle: localizations.updateAccountPassword,
            onTap: () {
              // TODO: Implement change password
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.changePasswordComingSoon)),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.logout,
            title: localizations.signOut,
            subtitle: localizations.signOut,
            onTap: () {
              // TODO: Implement sign out with confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.signOutComingSoon)),
              );
            },
          ),
          // Delete Account - Danger Zone
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
              color: Colors.red.withOpacity(0.05),
            ),
            child: Card(
              margin: EdgeInsets.zero,
              color: Colors.transparent,
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  localizations.deleteAccount,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  localizations.permanentlyDeleteAccount,
                  style: TextStyle(color: Colors.red.withOpacity(0.7)),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.red,
                ),
                onTap: _showDeleteAccountDialog,
              ),
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
        activeColor: Colors.indigo,
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
                Text(
                  localizations.requestAccountDeletion,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
                          localizations.healthcareProviderDeletionNote,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    localizations.whatWillBeDeleted,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  _buildDeletedDataItem(
                    '👤',
                    localizations.doctorProfileAndCredentials,
                  ),
                  _buildDeletedDataItem(
                    '💰',
                    localizations.walletBalanceAndHistory,
                  ),
                  _buildDeletedDataItem('📅', localizations.appointmentHistory),
                  _buildDeletedDataItem(
                    '🩺',
                    localizations.medicalConsultationRecords,
                  ),
                  _buildDeletedDataItem(
                    '📊',
                    localizations.patientReferralsAndReports,
                  ),
                  _buildDeletedDataItem(
                    '💳',
                    localizations.paymentAndWithdrawalHistory,
                  ),
                  _buildDeletedDataItem(
                    '🔔',
                    localizations.notificationsAndMessages,
                  ),
                  _buildDeletedDataItem(
                    '⚙️',
                    localizations.accountSettingsAndPreferences,
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
                          '• ${localizations.pendingWithdrawals}',
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
                            userRole: 'doctor',
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
            Text(
              localizations.pendingDeletionRequest,
              style: TextStyle(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.bold,
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
                    '${localizations.submittedOn}: $formattedDate',
                    style: TextStyle(fontSize: 13),
                  ),
                  if (request['reason'] != null &&
                      (request['reason'] as String).isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      '${localizations.reason}: ${request['reason']}',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                  SizedBox(height: 8),
                  Text(
                    localizations.requestBeingReviewed,
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(localizations.close),
          ),
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(localizations.cancelRequestQuestion),
                  content: Text(localizations.areYouSureCancelRequest),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(localizations.no),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(localizations.yesCancelRequest),
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
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.deletionRequestCancelled),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${localizations.failedToCancelRequest}: $e',
                        ),
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
}
