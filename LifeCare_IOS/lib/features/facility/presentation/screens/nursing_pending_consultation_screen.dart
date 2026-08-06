import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NursingPendingConsultationScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const NursingPendingConsultationScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<NursingPendingConsultationScreen> createState() =>
      _NursingPendingConsultationScreenState();
}

class _NursingPendingConsultationScreenState
    extends State<NursingPendingConsultationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Consultation'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vital Signs Completed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These patients have had their vital signs recorded and are ready for doctor/specialist consultation.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Patients with Vital Signs Pending Consultation
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('health_records')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('type', isEqualTo: 'VITAL_SIGNS')
                  .where('recordedByRole', isEqualTo: 'nursing')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, vitalSignsSnapshot) {
                if (vitalSignsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (vitalSignsSnapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${vitalSignsSnapshot.error}'),
                      ],
                    ),
                  );
                }

                final vitalSignsRecords = vitalSignsSnapshot.data?.docs ?? [];

                if (vitalSignsRecords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monitor_heart_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No patients with vital signs recorded',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patients will appear here after you record their vital signs.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Get unique patient IDs that have vital signs but no consultation notes yet
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('health_records')
                      .where('facilityId', isEqualTo: widget.facilityId)
                      .where('type', isEqualTo: 'CONSULTATION_NOTE')
                      .snapshots(),
                  builder: (context, consultationSnapshot) {
                    if (consultationSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final consultationRecords =
                        consultationSnapshot.data?.docs ?? [];

                    // Filter patients who have vital signs but no consultation notes
                    final pendingPatients = <String, Map<String, dynamic>>{};

                    for (final vitalRecord in vitalSignsRecords) {
                      final data = vitalRecord.data() as Map<String, dynamic>;
                      final patientId = data['patientId'] as String?;
                      final appointmentId = data['appointmentId'] as String?;

                      if (patientId != null && appointmentId != null) {
                        // Check if this specific appointment has no consultation note
                        final hasConsultationForAppointment =
                            consultationRecords.any((doc) {
                              final consultData =
                                  doc.data() as Map<String, dynamic>;
                              return consultData['patientId'] == patientId &&
                                  consultData['appointmentId'] == appointmentId;
                            });

                        if (!hasConsultationForAppointment) {
                          final key = '$patientId-$appointmentId';
                          if (!pendingPatients.containsKey(key)) {
                            pendingPatients[key] = data;
                          }
                        }
                      }
                    }

                    // Filter by search query
                    final filteredPatients = pendingPatients.values.where((
                      data,
                    ) {
                      final patientName =
                          data['patientName']?.toString().toLowerCase() ?? '';
                      return _searchQuery.isEmpty ||
                          patientName.contains(_searchQuery);
                    }).toList();

                    if (filteredPatients.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medical_information_outlined,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No patients found matching "$_searchQuery"'
                                  : 'No patients pending consultation',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All patients may have completed their consultations.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredPatients.length,
                      itemBuilder: (context, index) {
                        final patientData = filteredPatients[index];
                        final timestamp =
                            patientData['timestamp'] as Timestamp?;
                        final formattedTime = timestamp != null
                            ? DateFormat(
                                'MMM dd, yyyy • hh:mm a',
                              ).format(timestamp.toDate())
                            : 'N/A';

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
                                    CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Icon(
                                        Icons.monitor_heart,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            patientData['patientName'] ??
                                                'Unknown Patient',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Vital signs recorded: $formattedTime',
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
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'PENDING',
                                        style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Appointment and Vital Signs Details
                                if (patientData['appointmentId'] != null)
                                  _buildInfoRow(
                                    'Appointment ID',
                                    patientData['appointmentId'],
                                  ),

                                if (patientData['recordedBy'] != null)
                                  _buildInfoRow(
                                    'Recorded by',
                                    patientData['recordedBy'],
                                  ),

                                // Show vital signs summary if available
                                if (patientData['data'] != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Vital Signs Summary:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatVitalSigns(
                                            patientData['data'],
                                          ),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // Status Info
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.amber.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        color: Colors.amber.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Awaiting doctor/specialist consultation. Patient will move to Medical Records after consultation completion.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.amber.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatVitalSigns(Map<String, dynamic>? data) {
    if (data == null) return 'No details available';

    final List<String> vitals = [];

    if (data['bloodPressure'] != null) {
      vitals.add('BP: ${data['bloodPressure']}');
    }
    if (data['heartRate'] != null) {
      vitals.add('HR: ${data['heartRate']} bpm');
    }
    if (data['temperature'] != null) {
      vitals.add('Temp: ${data['temperature']}°C');
    }
    if (data['respiratoryRate'] != null) {
      vitals.add('RR: ${data['respiratoryRate']} /min');
    }
    if (data['oxygenSaturation'] != null) {
      vitals.add('SpO2: ${data['oxygenSaturation']}%');
    }

    return vitals.isNotEmpty ? vitals.join(', ') : 'Vital signs recorded';
  }
}
