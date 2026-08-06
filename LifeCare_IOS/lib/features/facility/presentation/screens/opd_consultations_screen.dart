import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lifecare_connect/features/doctor/presentation/screens/doctor_consultation_screen.dart';
import 'package:lifecare_connect/features/doctor/presentation/screens/doctor_vital_signs_screen.dart';

class OPDConsultationsScreen extends StatelessWidget {
  final String facilityId;
  final String facilityName;

  const OPDConsultationsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OPD Consultations'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('facilityId', isEqualTo: facilityId)
            .where('department', isEqualTo: 'Out-Patient Department (OPD)')
            .where('status', isEqualTo: 'approved')
            .snapshots(), // Removed orderBy to avoid index requirement
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading consultations',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Sort consultations in-memory by appointmentDate
          final allConsultations = snapshot.data?.docs ?? [];
          final consultations = List<QueryDocumentSnapshot>.from(
            allConsultations,
          );
          consultations.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aDate = aData['appointmentDate'];
            final bDate = bData['appointmentDate'];

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            // Handle both Timestamp and String formats
            DateTime? aDateTime;
            DateTime? bDateTime;

            if (aDate is Timestamp) {
              aDateTime = aDate.toDate();
            } else if (aDate is String) {
              try {
                aDateTime = DateTime.parse(aDate);
              } catch (e) {
                return 1;
              }
            }

            if (bDate is Timestamp) {
              bDateTime = bDate.toDate();
            } else if (bDate is String) {
              try {
                bDateTime = DateTime.parse(bDate);
              } catch (e) {
                return -1;
              }
            }

            if (aDateTime == null && bDateTime == null) return 0;
            if (aDateTime == null) return 1;
            if (bDateTime == null) return -1;

            return bDateTime.compareTo(
              aDateTime,
            ); // Descending order (newest first)
          });

          if (consultations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Pending Consultations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Approved appointments will appear here for consultation',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // The StreamBuilder will automatically refresh
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: consultations.length,
              itemBuilder: (context, index) {
                final doc = consultations[index];
                final data = doc.data() as Map<String, dynamic>;

                return _buildConsultationCard(context, doc.id, data, index + 1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildConsultationCard(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
    int displayIndex,
  ) {
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final doctorName = data['doctorName'] ?? 'Unknown Doctor';
    final appointmentDate = data['appointmentDate'];
    final appointmentTime = data['appointmentTime'] ?? '';
    final reasonForVisit =
        data['reasonForVisit'] ?? data['reason'] ?? 'No reason specified';

    // Format date
    String dateStr = 'Not specified';
    if (appointmentDate != null) {
      if (appointmentDate is Timestamp) {
        dateStr = DateFormat('MMM dd, yyyy').format(appointmentDate.toDate());
      } else if (appointmentDate is String) {
        try {
          final parsedDate = DateTime.parse(appointmentDate);
          dateStr = DateFormat('MMM dd, yyyy').format(parsedDate);
        } catch (e) {
          dateStr = appointmentDate;
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Name Header
            Row(
              children: [
                // Index Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$displayIndex',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: Icon(
                    Icons.person,
                    color: Colors.indigo.shade700,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Dr. $doctorName',
                        style: TextStyle(
                          fontSize: 14,
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
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'APPROVED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Appointment Info
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Appointment',
              value:
                  '$dateStr ${appointmentTime.isNotEmpty ? '($appointmentTime)' : ''}',
            ),
            const SizedBox(height: 12),

            // Reason for Visit
            _buildInfoRow(
              icon: Icons.medical_information,
              label: 'Chief Complaint',
              value: reasonForVisit,
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            // Check if consultation note exists
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('health_records')
                  .where('appointmentId', isEqualTo: appointmentId)
                  .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
                  .limit(1)
                  .snapshots(),
              builder: (context, recordSnapshot) {
                final hasConsultationNote =
                    recordSnapshot.hasData &&
                    recordSnapshot.data!.docs.isNotEmpty;

                if (hasConsultationNote) {
                  // Show view-only status
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Consultation completed',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final record = recordSnapshot.data!.docs.first;
                            final recordData =
                                record.data() as Map<String, dynamic>;
                            _viewConsultationDetails(
                              context,
                              appointmentId,
                              data,
                              recordData,
                            );
                          },
                          child: const Text('View Details'),
                        ),
                      ],
                    ),
                  );
                }

                // Show action buttons for pending consultations
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ready for consultation',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.note_add, size: 18),
                            label: const Text('Add Note'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DoctorConsultationDetailScreen(
                                        appointment: {
                                          ...data,
                                          'appointmentId': appointmentId,
                                        },
                                        readOnly: false,
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.hotel, size: 18),
                            label: const Text('Admit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              _showAdmitPatientDialog(
                                context,
                                appointmentId,
                                data,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.monitor_heart, size: 18),
                            label: const Text('Vital Signs'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DoctorVitalSignsScreen(
                                    appointment: {
                                      ...data,
                                      'appointmentId': appointmentId,
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _viewConsultationDetails(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> appointmentData,
    Map<String, dynamic> recordData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorConsultationDetailScreen(
          appointment: {
            ...appointmentData,
            'appointmentId': appointmentId,
            ...recordData['data'] ?? {},
          },
          readOnly: true,
        ),
      ),
    );
  }

  void _showAdmitPatientDialog(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    final reasonController = TextEditingController();
    String? selectedWardId;
    String? selectedWardName;
    String? selectedBedId;
    String? selectedBedNumber;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.hotel, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text('Admit Patient'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient: ${data['patientName'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Reason for Admission *',
                          hintText: 'Enter diagnosis or reason',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.medical_information),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Ward Dropdown
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('wards')
                            .where('facilityId', isEqualTo: facilityId)
                            .where('isActive', isEqualTo: true)
                            .snapshots(),
                        builder: (context, wardSnapshot) {
                          if (wardSnapshot.hasError) {
                            return Text('Error: ${wardSnapshot.error}');
                          }

                          if (!wardSnapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          final wards = wardSnapshot.data!.docs;

                          if (wards.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.orange.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No wards configured. Please create wards in Ward Setup first.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Select Ward *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.domain),
                            ),
                            value: selectedWardId,
                            items: wards.map((ward) {
                              final wardData =
                                  ward.data() as Map<String, dynamic>;
                              return DropdownMenuItem(
                                value: ward.id,
                                child: Text(
                                  '${wardData['wardName']} (${wardData['wardType']})',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedWardId = value;
                                selectedBedId = null; // Reset bed selection
                                selectedBedNumber = null;

                                final selectedWard = wards.firstWhere(
                                  (w) => w.id == value,
                                );
                                final wardData =
                                    selectedWard.data() as Map<String, dynamic>;
                                selectedWardName = wardData['wardName'];
                              });
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Bed Dropdown (only shows when ward is selected)
                      if (selectedWardId != null)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('facilities')
                              .doc(facilityId)
                              .collection('wards')
                              .doc(selectedWardId)
                              .collection('beds')
                              .where('status', isEqualTo: 'available')
                              .snapshots(),
                          builder: (context, bedSnapshot) {
                            if (bedSnapshot.hasError) {
                              return Text('Error: ${bedSnapshot.error}');
                            }

                            if (!bedSnapshot.hasData) {
                              return const CircularProgressIndicator();
                            }

                            final availableBeds = bedSnapshot.data!.docs;

                            if (availableBeds.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error,
                                      color: Colors.red.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No available beds in this ward. All beds are occupied.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade900,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Select Bed *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.bed),
                              ),
                              value: selectedBedId,
                              items: availableBeds.map((bed) {
                                final bedData =
                                    bed.data() as Map<String, dynamic>;
                                return DropdownMenuItem(
                                  value: bed.id,
                                  child: Text(
                                    'Bed ${bedData['bedNumber']} (${bedData['bedType']})',
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedBedId = value;

                                  final selectedBed = availableBeds.firstWhere(
                                    (b) => b.id == value,
                                  );
                                  final bedData =
                                      selectedBed.data()
                                          as Map<String, dynamic>;
                                  selectedBedNumber = bedData['bedNumber'];
                                });
                              },
                            );
                          },
                        ),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Patient will be moved to In-Patient department. Selected bed will be marked as occupied.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter reason for admission'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (selectedWardId == null || selectedWardName == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a ward'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (selectedBedId == null || selectedBedNumber == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select an available bed'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _admitPatient(
                      context,
                      appointmentId,
                      data,
                      reason,
                      selectedWardId!,
                      selectedWardName!,
                      selectedBedId!,
                      selectedBedNumber!,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Admit Patient'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _admitPatient(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
    String reason,
    String wardId,
    String wardName,
    String bedId,
    String bedNumber,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Create admission record (required for discharge workflow)
      final admissionRef = FirebaseFirestore.instance
          .collection('admissions')
          .doc();
      batch.set(admissionRef, {
        'admissionId': admissionRef.id,
        'appointmentId':
            appointmentId, // CRITICAL: Store appointmentId for discharge
        'patientId': data['patientId'] ?? data['patientUid'],
        'patientName': data['patientName'],
        'facilityId': facilityId,
        'facilityName': facilityName,
        'wardId': wardId,
        'bedId': bedId,
        'admissionDiagnosis': reason,
        'admissionNotes': 'Admitted from OPD',
        'admissionType': 'emergency',
        'patientStatus': 'stable',
        'admittingDoctorId': data['doctorId'] ?? data['doctorUid'],
        'admittingDoctorName': data['doctorName'],
        'department': 'Out-Patient Department (OPD)',
        'admittedBy': data['doctorName'],
        'admissionDate': FieldValue.serverTimestamp(),
        'admittedAt': FieldValue.serverTimestamp(),
        'status': 'admitted', // Already admitted (not pending acceptance)
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create in-patient record for billing
      final inpatientRef = FirebaseFirestore.instance
          .collection('inpatients')
          .doc(admissionRef.id);
      batch.set(inpatientRef, {
        'inpatientId': inpatientRef.id,
        'appointmentId':
            appointmentId, // Store appointmentId in inpatient record too
        'admissionId': admissionRef.id, // Link to admission record
        'facilityId': facilityId,
        'facilityName': facilityName,
        'patientId': data['patientId'] ?? data['patientUid'],
        'patientName': data['patientName'],
        'doctorId': data['doctorId'] ?? data['doctorUid'],
        'doctorName': data['doctorName'],
        'admissionReason': reason,
        'wardId': wardId,
        'ward': wardName,
        'bedId': bedId,
        'bedNumber': bedNumber,
        'status': 'admitted', // Already admitted from OPD
        'isActive': true, // Track active admissions
        'department': 'In-Patient',
        'admittedAt': FieldValue.serverTimestamp(),
        'admittedBy': data['doctorId'] ?? 'OPD Staff',
      });

      // Update bed status to occupied
      final bedRef = FirebaseFirestore.instance.collection('beds').doc(bedId);
      batch.update(bedRef, {
        'status': 'occupied',
        'occupiedBy': data['patientId'] ?? data['patientUid'],
        'occupiedByName': data['patientName'],
        'patientId': data['patientId'] ?? data['patientUid'],
        'inpatientId': inpatientRef.id,
        'occupiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update appointment status to 'admitted' - removes from OPD consultation screen
      // Patient is now in ward and will only appear in inpatient dashboard
      // Appointment will be marked 'completed' when patient is discharged
      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc(data['appointmentId']);
      batch.update(appointmentRef, {
        'status': 'admitted',
        'admittedToWard': true,
        'wardId': wardId,
        'wardName': wardName,
        'bedId': bedId,
        'bedNumber': bedNumber,
        'admittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Patient admitted to $wardName, Bed $bedNumber successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to admit patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
