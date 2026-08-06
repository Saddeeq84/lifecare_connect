import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SpecialistReferralsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String specialistId;
  final String specialistName;

  const SpecialistReferralsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.specialistId,
    required this.specialistName,
  });

  @override
  State<SpecialistReferralsScreen> createState() =>
      _SpecialistReferralsScreenState();
}

class _SpecialistReferralsScreenState extends State<SpecialistReferralsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Specialist departments that this screen handles
  final List<String> _specialistDepartments = [
    'Surgery',
    'Medicine',
    'Dental',
    'ENT (Ear, Nose & Throat)',
    'Ophthalmology',
    'Pediatrics',
    'Obstetrics & Gynecology',
    'Radiology',
    'Pathology',
    'Psychiatry',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referrals from OPD'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Rejected'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReferralsTab('pending'),
          _buildReferralsTab('accepted'),
          _buildReferralsTab('rejected'),
          _buildReferralsTab('all'),
        ],
      ),
    );
  }

  Widget _buildReferralsTab(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getReferralsStream(statusFilter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final referrals = snapshot.data?.docs ?? [];

        // Sort by createdAt in memory
        referrals.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending order
        });

        if (referrals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.send_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  statusFilter == 'all'
                      ? 'No referrals yet'
                      : 'No $statusFilter referrals',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Referrals from OPD will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: referrals.length,
          itemBuilder: (context, index) {
            final doc = referrals[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildReferralCard(doc.id, data);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getReferralsStream(String statusFilter) {
    Query query = FirebaseFirestore.instance
        .collection('referrals')
        .where('fromFacilityId', isEqualTo: widget.facilityId)
        .where('specialistDepartment', whereIn: _specialistDepartments);

    if (statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots();
  }

  Widget _buildReferralCard(String referralId, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'pending';
    final patientName = data['patientName'] as String? ?? 'Unknown Patient';
    final fromDoctorName =
        data['fromDoctorName'] as String? ?? 'Unknown Doctor';
    final specialistDepartment =
        data['specialistDepartment'] as String? ?? 'N/A';
    final specialistUnit = data['specialistUnit'] as String? ?? 'N/A';
    final reason = data['reason'] as String? ?? '';
    final notes = data['notes'] as String? ?? '';
    final referralType = data['referralType'] as String? ?? 'facility';
    final createdAt = data['createdAt'] as Timestamp?;
    final rejectionReason = data['rejectionReason'] as String?;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.amber;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          // Header with status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    DateFormat('MMM d, y - h:mm a').format(createdAt.toDate()),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.teal.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.medical_services,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Referred by: $fromDoctorName',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Department & Unit
                _buildInfoRow(
                  Icons.business,
                  'Department',
                  specialistDepartment,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.category, 'Unit', specialistUnit),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.cloud_outlined,
                  'Referral Type',
                  referralType == 'facility'
                      ? 'Facility Doctor'
                      : 'Remote Doctor',
                ),

                const Divider(height: 24),

                // Reason
                _buildInfoSection('Reason for Referral', reason),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoSection('Additional Notes', notes),
                ],

                if (status == 'rejected' && rejectionReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Rejection Reason',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rejectionReason,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons (only for pending)
                if (status == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _acceptReferral(referralId, data),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectReferral(referralId),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(content, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Future<void> _acceptReferral(
    String referralId,
    Map<String, dynamic> referralData,
  ) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Referral'),
        content: const Text(
          'This will accept the referral and automatically create an approved appointment for this patient. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update referral status
      batch.update(
        FirebaseFirestore.instance.collection('referrals').doc(referralId),
        {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'acceptedBy': widget.specialistId,
          'acceptedByName': widget.specialistName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Create approved appointment
      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc();
      batch.set(appointmentRef, {
        'patientId': referralData['patientId'],
        'patientName': referralData['patientName'],
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'doctorId': referralData['toDoctorId'],
        'doctorName': referralData['toDoctorName'],
        'department': referralData['specialistDepartment'],
        'reason': referralData['reason'],
        'notes':
            'Referral from ${referralData['fromDoctorName']}. ${referralData['notes'] ?? ''}',
        'status': 'approved',
        'appointmentType': 'Referral',
        'referralId': referralId,
        'createdAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': widget.specialistId,
        'approvedByName': widget.specialistName,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Referral accepted and appointment created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting referral: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectReferral(String referralId) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Referral'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this referral:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      reasonController.dispose();
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('referrals')
          .doc(referralId)
          .update({
            'status': 'rejected',
            'rejectionReason': reasonController.text.trim(),
            'rejectedAt': FieldValue.serverTimestamp(),
            'rejectedBy': widget.specialistId,
            'rejectedByName': widget.specialistName,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting referral: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }
}
