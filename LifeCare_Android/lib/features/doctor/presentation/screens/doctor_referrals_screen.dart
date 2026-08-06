// import '../../../shared/presentation/widgets/make_referral_form.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/data/services/referral_service.dart';

class DoctorReferralsScreen extends StatefulWidget {
  const DoctorReferralsScreen({super.key});

  @override
  State<DoctorReferralsScreen> createState() => _DoctorReferralsScreenState();
}

class _DoctorReferralsScreenState extends State<DoctorReferralsScreen>
    with SingleTickerProviderStateMixin {
  Widget _buildReferralList({required bool isReviewed}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Not logged in.'));
    }
    // For reviewed, show both 'approved' and 'rejected'. For pending, show 'pending'.
    final statusValues = isReviewed ? ['approved', 'rejected'] : ['pending'];
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('referrals')
          .where('toProviderId', isEqualTo: currentUser.uid)
          .where('status', whereIn: statusValues)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              isReviewed
                  ? "No reviewed referrals yet."
                  : "No pending referrals.",
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildReferralCard(
              context,
              data,
              doc,
              isReviewed: isReviewed,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Referrals"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Referral',
            onPressed: _openCreateReferralForm,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Reviewed"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReferralList(isReviewed: false),
          _buildReferralList(isReviewed: true),
        ],
      ),
    );
  }

  // In-memory cache for patient names to avoid repeated Firestore calls
  final Map<String, String> _patientNameCache = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreateReferralForm() {
    // Use GoRouter for navigation to ensure consistent routing
    // The route should be defined in app_router.dart as '/doctor_dashboard/create_referral'
    if (mounted) {
      // ignore: use_build_context_synchronously
      GoRouter.of(context).pushNamed('doctor-create-referral');
    }
  }

  void _showReferralDetailsDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Referral Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patient: ${data['patient'] ?? data['patientName'] ?? 'Not provided'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Reason: ${data['reason'] ?? 'Not provided'}'),
              Text('Urgency: ${data['urgency'] ?? 'Not provided'}'),
              if (data['notes'] != null &&
                  (data['notes'] as String).trim().isNotEmpty)
                Text('Notes: ${data['notes']}'),
              Text('Status: ${data['status'] ?? 'Not provided'}'),
              if (data['createdAt'] != null)
                Text('Created At: ${data['createdAt'].toDate().toString()}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(
    BuildContext context,
    Map<String, dynamic> data,
    DocumentSnapshot doc, {
    bool isReviewed = false,
  }) {
    String? patientId = data['patientId'];
    String? patientName = data['patient'];
    if (patientName == null || patientName.trim().isEmpty) {
      if (patientId != null && _patientNameCache.containsKey(patientId)) {
        patientName = _patientNameCache[patientId];
      }
    }
    return FutureBuilder<String>(
      future: (patientName != null && patientName.trim().isNotEmpty)
          ? Future.value(patientName)
          : _getPatientNameWithCache(data),
      builder: (context, snapshot) {
        final displayName =
            snapshot.data ?? data['patient'] ?? 'Unknown Patient';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Condition: " + (data['condition'] ?? 'N/A')),
                Text(
                  "Referred by: " +
                      (data['fromProviderName'] ??
                          data['chw'] ??
                          data['referringProviderName'] ??
                          'Unknown') +
                      (data['fromProviderType'] != null
                          ? ' (${data['fromProviderType'].toString().toUpperCase()})'
                          : ''),
                ),
                if (isReviewed) Text("Status: " + (data['status'] ?? '')),
              ],
            ),
            trailing: isReviewed
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_red_eye,
                          color: Colors.blue,
                        ),
                        tooltip: "Review Referral",
                        onPressed: () =>
                            _showReferralDetailsDialog(context, data),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        tooltip: "Approve",
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Approval'),
                              content: const Text(
                                'Are you sure you want to approve this referral?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Approve'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            _handleReferralDecision(context, doc, 'Accepted');
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        tooltip: "Deny",
                        onPressed: () =>
                            _handleReferralDecision(context, doc, 'Rejected'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<String> _getPatientNameWithCache(Map<String, dynamic> data) async {
    final patientId = data['patientId'];
    if (patientId == null) return 'Unknown Patient';
    if (_patientNameCache.containsKey(patientId)) {
      return _patientNameCache[patientId]!;
    }

    try {
      // First, try to find patient in 'users' collection (regular patients with accounts)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final name =
            userData['fullName'] ??
            userData['name'] ??
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                .trim();
        if (name.isNotEmpty) {
          _patientNameCache[patientId] = name;
          return name;
        }
      }

      // If not found in users, try 'chw_patients' collection (CHW registered patients without accounts)
      final chwPatientDoc = await FirebaseFirestore.instance
          .collection('chw_patients')
          .doc(patientId)
          .get();

      if (chwPatientDoc.exists) {
        final patientData = chwPatientDoc.data() as Map<String, dynamic>;
        final name =
            patientData['fullName'] ?? patientData['name'] ?? 'Unknown Patient';
        _patientNameCache[patientId] = name;
        return name;
      }
    } catch (_) {}

    return 'Unknown Patient';
  }

  Future<void> _handleReferralDecision(
    BuildContext context,
    DocumentSnapshot referralDoc,
    String decision,
  ) async {
    String? rejectionReason;
    if (decision == 'Rejected') {
      rejectionReason = await _showRejectionReasonDialog(context);
      if (rejectionReason == null || rejectionReason.isEmpty) {
        return;
      }
    }
    try {
      // Always use 'approved' for acceptance to match patient UI and messaging logic
      final isApproved = decision == 'Accepted';
      final statusToSet = isApproved
          ? 'approved'
          : (decision == 'Rejected' ? 'rejected' : decision.toLowerCase());
      final referralId = referralDoc.id;
      final actionBy = FirebaseAuth.instance.currentUser?.uid;
      // Use ReferralService.updateReferralStatus for unified logic and messaging
      await ReferralService.updateReferralStatus(
        referralId: referralId,
        status: statusToSet,
        actionBy: actionBy ?? '',
        actionNotes: rejectionReason,
      );
      // Optionally, show a snackbar or dialog to confirm action
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApproved
                  ? 'Referral approved and patient notified.'
                  : 'Referral rejected.',
            ),
            backgroundColor: isApproved ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update referral: $e')));
    }
  }

  Future<String?> _showRejectionReasonDialog(BuildContext context) async {
    String rejectionReason = '';
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reason for Rejection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please provide a reason for rejecting this referral:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => rejectionReason = value,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (rejectionReason.trim().isNotEmpty) {
                  Navigator.of(dialogContext).pop(rejectionReason.trim());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a reason for rejection'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Reject Referral',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // (All duplicate methods removed. Only the first set of each method remains.)
}
