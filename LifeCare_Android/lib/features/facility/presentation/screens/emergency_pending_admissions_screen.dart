import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EmergencyPendingAdmissionsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const EmergencyPendingAdmissionsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<EmergencyPendingAdmissionsScreen> createState() =>
      _EmergencyPendingAdmissionsScreenState();
}

class _EmergencyPendingAdmissionsScreenState
    extends State<EmergencyPendingAdmissionsScreen> {
  List<Map<String, dynamic>> _wards = [];
  bool _loadingWards = true;

  @override
  void initState() {
    super.initState();
    _loadWards();
  }

  Future<void> _loadWards() async {
    try {
      final wardsSnapshot = await FirebaseFirestore.instance
          .collection('wards')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('isActive', isEqualTo: true)
          .get();

      print(
        'Found ${wardsSnapshot.docs.length} wards for facility ${widget.facilityId}',
      );

      if (mounted) {
        setState(() {
          _wards = wardsSnapshot.docs.map((doc) {
            final data = doc.data();
            print(
              'Ward: ${doc.id}, Name: ${data['wardName']}, Type: ${data['wardType']}',
            );
            return {'id': doc.id, ...data};
          }).toList();
          _loadingWards = false;
        });
      }
    } catch (e) {
      print('Error loading wards: $e');
      if (mounted) {
        setState(() => _loadingWards = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Emergency Admissions'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admissions')
            .where('facilityId', isEqualTo: widget.facilityId)
            .where('admissionType', isEqualTo: 'emergency')
            .where('status', isEqualTo: 'pending_acceptance')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
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
                    Icons.pending_actions,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Pending Admissions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Emergency admission requests will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: admissions.length,
            itemBuilder: (context, index) {
              final admission =
                  admissions[index].data() as Map<String, dynamic>;
              final admissionId = admissions[index].id;
              return _buildAdmissionCard(admission, admissionId);
            },
          );
        },
      ),
    );
  }

  Widget _buildAdmissionCard(
    Map<String, dynamic> admission,
    String admissionId,
  ) {
    final patientName = admission['patientName'] ?? 'Unknown Patient';
    final diagnosis =
        admission['admissionDiagnosis'] ?? 'No diagnosis provided';
    final admittingDoctor =
        admission['admittingDoctorName'] ?? 'Unknown Doctor';
    final createdAt = admission['createdAt'] as Timestamp?;
    final patientStatus = admission['patientStatus'] ?? 'stable';
    final notes = admission['admissionNotes'] ?? '';

    Color statusColor;
    switch (patientStatus) {
      case 'critical':
        statusColor = Colors.red;
        break;
      case 'serious':
        statusColor = Colors.orange;
        break;
      case 'fair':
        statusColor = Colors.yellow.shade700;
        break;
      default:
        statusColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.emergency,
                    color: Colors.red.shade700,
                    size: 28,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          'Requested: ${DateFormat('MMM d, h:mm a').format(createdAt.toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    patientStatus.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.medical_services,
                  'Admitting Doctor',
                  admittingDoctor,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.sick, 'Diagnosis', diagnosis),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notes,
                              size: 16,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Admission Notes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(notes, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _acceptAdmission(admission, admissionId),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Accept & Assign Bed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectAdmission(admissionId),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _acceptAdmission(
    Map<String, dynamic> admission,
    String admissionId,
  ) async {
    if (_loadingWards) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading wards, please wait...')),
      );
      return;
    }

    if (_wards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No wards available. Please create a ward first.'),
        ),
      );
      return;
    }

    // Simple dialog without stateful widget
    String? selectedWardId;
    String? selectedBedId;
    List<Map<String, dynamic>> availableBeds = [];
    bool loadingBeds = false;

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Assign Bed'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Ward',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedWardId,
                      items: _wards.map((ward) {
                        return DropdownMenuItem(
                          value: ward['id'] as String,
                          child: Text(
                            ward['wardName'] ?? ward['name'] ?? 'Unknown',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value != null && value != selectedWardId) {
                          setState(() {
                            selectedWardId = value;
                            selectedBedId = null;
                            loadingBeds = true;
                            availableBeds = [];
                          });

                          try {
                            final bedsSnapshot = await FirebaseFirestore
                                .instance
                                .collection('beds')
                                .where('wardId', isEqualTo: value)
                                .where('status', isEqualTo: 'available')
                                .get();

                            setState(() {
                              availableBeds = bedsSnapshot.docs.map((doc) {
                                return {'id': doc.id, ...doc.data()};
                              }).toList();
                              loadingBeds = false;
                            });
                          } catch (e) {
                            setState(() {
                              loadingBeds = false;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (loadingBeds)
                      const CircularProgressIndicator()
                    else if (selectedWardId != null && availableBeds.isEmpty)
                      const Text(
                        'No available beds in this ward',
                        style: TextStyle(color: Colors.orange),
                      )
                    else if (availableBeds.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Select Bed',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedBedId,
                        items: availableBeds.map((bed) {
                          return DropdownMenuItem(
                            value: bed['id'] as String,
                            child: Text('Bed ${bed['bedNumber']}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedBedId = value;
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (selectedWardId != null && selectedBedId != null)
                      ? () {
                          final ward = _wards.firstWhere(
                            (w) => w['id'] == selectedWardId,
                          );
                          final bed = availableBeds.firstWhere(
                            (b) => b['id'] == selectedBedId,
                          );
                          Navigator.pop(context, {
                            'wardId': selectedWardId,
                            'bedId': selectedBedId,
                            'wardName': ward['wardName'] ?? ward['name'],
                            'bedNumber': bed['bedNumber'],
                          });
                        }
                      : null,
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final wardId = result['wardId'] as String?;
    final bedId = result['bedId'] as String?;
    final wardName = result['wardName'] as String?;
    final bedNumber = result['bedNumber'];

    try {
      // Update admission status to admitted
      await FirebaseFirestore.instance
          .collection('admissions')
          .doc(admissionId)
          .update({
            'status': 'admitted',
            'wardId': wardId,
            'wardName': wardName,
            'bedId': bedId,
            'bedNumber': bedNumber,
            'acceptedBy': widget.staffId,
            'acceptedByName': widget.staffName,
            'acceptedAt': FieldValue.serverTimestamp(),
            'admittedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update bed status to occupied
      await FirebaseFirestore.instance.collection('beds').doc(bedId).update({
        'status': 'occupied',
        'patientId': admission['patientId'],
        'patientName': admission['patientName'],
        'admissionId': admissionId,
        'facilityId': widget.facilityId,
        'occupiedAt': FieldValue.serverTimestamp(),
      });

      // Update patient admission status
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(admission['patientId'])
          .update({
            'admissionStatus': 'admitted',
            'currentAdmissionId': admissionId,
            'currentWardId': wardId,
            'currentBedId': bedId,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admission accepted and bed assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

  Future<void> _rejectAdmission(String admissionId) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Admission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for rejecting this admission request:',
            ),
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
          .collection('admissions')
          .doc(admissionId)
          .update({
            'status': 'rejected',
            'rejectionReason': reasonController.text.trim(),
            'rejectedBy': widget.staffId,
            'rejectedByName': widget.staffName,
            'rejectedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admission rejected'),
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
    } finally {
      reasonController.dispose();
    }
  }
}
