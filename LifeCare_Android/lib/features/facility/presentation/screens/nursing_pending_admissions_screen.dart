import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NursingPendingAdmissionsScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const NursingPendingAdmissionsScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<NursingPendingAdmissionsScreen> createState() =>
      _NursingPendingAdmissionsScreenState();
}

class _NursingPendingAdmissionsScreenState
    extends State<NursingPendingAdmissionsScreen> {
  Stream<QuerySnapshot> _getPendingAdmissionsStream() {
    return FirebaseFirestore.instance
        .collection('admissions')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('status', isEqualTo: 'pending_acceptance')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _acceptAdmission(DocumentSnapshot admission) async {
    try {
      final admissionData = admission.data() as Map<String, dynamic>;
      final bedId = admissionData['bedId'];
      final patientId = admissionData['patientId'];
      final wardId = admissionData['wardId'];

      final batch = FirebaseFirestore.instance.batch();

      // Update admission status to admitted
      final admissionRef = FirebaseFirestore.instance
          .collection('admissions')
          .doc(admission.id);
      batch.update(admissionRef, {
        'status': 'admitted',
        'acceptedBy': widget.staffId,
        'acceptedByName': widget.staffName,
        'acceptedAt': FieldValue.serverTimestamp(),
        'admittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update bed status to occupied
      final bedRef = FirebaseFirestore.instance.collection('beds').doc(bedId);
      batch.update(bedRef, {
        'status': 'occupied',
        'patientId': patientId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update patient admission flag
      final patientRef = FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId);
      batch.set(patientRef, {
        'isAdmitted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // **CRITICAL: Create inpatients record for automatic ward billing**
      // Get ward details for pricing
      final wardDoc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.facilityId)
          .collection('wards')
          .doc(wardId)
          .get();

      final wardData = wardDoc.data();
      final chargePerNight =
          (wardData?['chargePerNight'] as num?)?.toDouble() ?? 5000.0;
      final wardName = wardData?['wardName'] ?? 'General Ward';

      // Create inpatients record for automatic billing system
      final inpatientRef = FirebaseFirestore.instance
          .collection('inpatients')
          .doc(admission.id); // Use same ID as admission for easy tracking

      batch.set(inpatientRef, {
        'admissionId': admission.id,
        'facilityId': widget.facilityId,
        'patientId': patientId,
        'patientName': admissionData['patientName'] ?? 'Unknown',
        'department':
            'In-Patient', // Required field for Firestore security rules
        'wardId': wardId,
        'wardName': wardName,
        'bedId': bedId,
        'bedNumber': admissionData['bedNumber'] ?? 'N/A',
        'roomNumber': admissionData['roomNumber'] ?? 'N/A',
        'diagnosis': admissionData['diagnosis'] ?? '',
        'reasonForAdmission': admissionData['reasonForAdmission'] ?? '',
        'condition': admissionData['condition'] ?? 'stable',
        'doctorId': admissionData['admittedBy'] ?? '',
        'doctorName': admissionData['admittedByName'] ?? 'Unknown',
        'status': 'admitted',
        'isActive': true, // Track active admissions
        'billingCycle': 'daily', // Enable daily automatic billing
        'chargePerNight': chargePerNight,
        'wardServiceId': 'ward_accommodation',
        'wardServiceName': '$wardName Accommodation',
        'wardServiceCategory': 'Accommodation',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': widget.staffId,
        'acceptedByName': widget.staffName,
        'admittedAt': FieldValue.serverTimestamp(),
        'totalChargedAmount': 0.0,
        'chargeCount': 0,
        'lastBillingDate': null,
        'lastChargeAmount': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🔍 [Accept Admission] About to commit batch write...');
      debugPrint('🔍 [Accept Admission] Admission ID: ${admission.id}');
      debugPrint('🔍 [Accept Admission] Facility ID: ${widget.facilityId}');
      debugPrint('🔍 [Accept Admission] Staff ID: ${widget.staffId}');

      await batch.commit();

      debugPrint('✅ [Accept Admission] Batch committed successfully!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Admission accepted successfully. Daily ward billing activated.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [Accept Admission] Error: $e');
      debugPrint('❌ [Accept Admission] Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting admission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectAdmission(DocumentSnapshot admission) async {
    try {
      final admissionData = admission.data() as Map<String, dynamic>;
      final bedId = admissionData['bedId'];
      final wardId = admissionData['wardId'];

      final batch = FirebaseFirestore.instance.batch();

      // Update admission status to rejected
      final admissionRef = FirebaseFirestore.instance
          .collection('admissions')
          .doc(admission.id);
      batch.update(admissionRef, {
        'status': 'rejected',
        'rejectedBy': widget.staffId,
        'rejectedByName': widget.staffName,
        'rejectedAt': FieldValue.serverTimestamp(),
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Free up the reserved bed
      final bedRef = FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.facilityId)
          .collection('wards')
          .doc(wardId)
          .collection('beds')
          .doc(bedId);
      batch.update(bedRef, {
        'status': 'available',
        'patientId': null,
        'reservedFor': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admission rejected successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting admission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAdmissionDetails(DocumentSnapshot admission) {
    final data = admission.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admission Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Patient', data['patientName'] ?? 'N/A'),
              _buildDetailRow('Ward', data['wardName'] ?? 'N/A'),
              _buildDetailRow('Bed', data['bedNumber'] ?? 'N/A'),
              _buildDetailRow('Reason', data['reasonForAdmission'] ?? 'N/A'),
              _buildDetailRow('Diagnosis', data['diagnosis'] ?? 'N/A'),
              _buildDetailRow('Admitted By', data['admittedBy'] ?? 'N/A'),
              if (data['createdAt'] != null)
                _buildDetailRow(
                  'Requested At',
                  DateFormat(
                    'MMM dd, yyyy hh:mm a',
                  ).format((data['createdAt'] as Timestamp).toDate()),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmReject(admission);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmAccept(admission);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmAccept(DocumentSnapshot admission) {
    final data = admission.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Admission'),
        content: Text(
          'Are you sure you want to accept the admission for ${data['patientName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptAdmission(admission);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _confirmReject(DocumentSnapshot admission) {
    final data = admission.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Admission'),
        content: Text(
          'Are you sure you want to reject the admission for ${data['patientName']}? This will free up the reserved bed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectAdmission(admission);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Admissions'),
        backgroundColor: Colors.pink.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPendingAdmissionsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final admissions = snapshot.data?.docs ?? [];

          if (admissions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending admissions',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All admission requests have been processed',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: admissions.length,
            itemBuilder: (context, index) {
              final admission = admissions[index];
              final data = admission.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.pending_actions,
                              color: Colors.orange.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['patientName'] ?? 'Unknown Patient',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${data['wardName'] ?? 'N/A'} - Bed ${data['bedNumber'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Reason: ${data['reasonForAdmission'] ?? 'Not specified'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (data['createdAt'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Requested: ${DateFormat('MMM dd, yyyy hh:mm a').format((data['createdAt'] as Timestamp).toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showAdmissionDetails(admission),
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('Details'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _confirmReject(admission),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reject'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _confirmAccept(admission),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
