import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/services/referral_service.dart';
import '../../../shared/data/models/referral.dart';

class CHWReferralsScreen extends StatelessWidget {
  const CHWReferralsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Referrals"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/chw_dashboard');
          },
        ),
      ),
      body: const CHWReferralTabs(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.pushNamed('chw-create-referral');
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.send),
        label: const Text('Create Referral'),
      ),
    );
  }
}

class CHWReferralTabs extends StatefulWidget {
  const CHWReferralTabs({super.key});

  @override
  State<CHWReferralTabs> createState() => _CHWReferralTabsState();
}

class _CHWReferralTabsState extends State<CHWReferralTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
  _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        Container(
          color: Colors.teal,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.pending_actions), text: "Pending"),
              Tab(icon: Icon(Icons.check_circle), text: "Approved"),
              Tab(icon: Icon(Icons.cancel), text: "Rejected"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              CHWReferralStatusTab(userId: userId, status: 'pending'),
              CHWReferralStatusTab(userId: userId, status: 'approved'),
              CHWReferralStatusTab(userId: userId, status: 'rejected'),
            ],
          ),
        ),
      ],
    );
  }
}

class CHWReferralStatusTab extends StatelessWidget {
  final String? userId;
  final String status;

  const CHWReferralStatusTab({
    super.key,
    required this.userId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: Text("User not authenticated"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: ReferralService.getCHWReferrals(chwId: userId!, status: status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final referrals = snapshot.data?.docs ?? [];

        if (referrals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getStatusIcon(status), size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  "No $status referrals",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                if (status == 'pending') ...[
                  const SizedBox(height: 8),
                  const Text(
                    "Create a referral to send patients to specialists",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: referrals.length,
          itemBuilder: (context, index) {
            final doc = referrals[index];
            final referral = Referral.fromFirestore(doc);

            return ReferralCard(
              referral: referral,
              onTap: () => _showReferralDetails(context, referral),
            );
          },
        );
      },
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.help;
    }
  }

  void _showReferralDetails(BuildContext context, Referral referral) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReferralDetailsModal(referral: referral),
    );
  }
}

class ReferralCard extends StatelessWidget {
  final Referral referral;
  final VoidCallback onTap;

  const ReferralCard({super.key, required this.referral, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      referral.patientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(referral.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      referral.statusDisplayText.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To: ${referral.toProviderName}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getUrgencyColor(referral.urgency),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      referral.urgencyDisplayText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.medical_services,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      referral.reason,
                      style: const TextStyle(color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${referral.formattedCreatedDate} at ${referral.formattedCreatedTime}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'low':
        return Colors.blue;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class ReferralDetailsModal extends StatelessWidget {
  final Referral referral;

  const ReferralDetailsModal({super.key, required this.referral});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Referral Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Patient Information', [
                    _buildDetailRow('Name', referral.patientName),
                    _buildDetailRow('Patient ID', referral.patientId),
                  ]),
                  const SizedBox(height: 16),
                  _buildDetailSection('Referral Information', [
                    _buildDetailRow('To Provider', referral.toProviderName),
                    _buildDetailRow('Provider Type', referral.toProviderType),
                    _buildDetailRow('Reason', referral.reason),
                    _buildDetailRow('Urgency', referral.urgencyDisplayText),
                    _buildDetailRow('Status', referral.statusDisplayText),
                  ]),
                  if (referral.notes != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Notes', [
                      Text(
                        referral.notes!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ]),
                  ],
                  if (referral.actionNotes != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Action Notes', [
                      Text(
                        referral.actionNotes!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  _buildDetailSection('Timeline', [
                    _buildDetailRow(
                      'Created',
                      '${referral.formattedCreatedDate} at ${referral.formattedCreatedTime}',
                    ),
                    if (referral.actionDate != null)
                      _buildDetailRow(
                        'Action Date',
                        '${referral.actionDate!.day}/${referral.actionDate!.month}/${referral.actionDate!.year}',
                      ),
                    if (referral.actionBy != null)
                      _buildDetailRow('Action By', referral.actionBy!),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
