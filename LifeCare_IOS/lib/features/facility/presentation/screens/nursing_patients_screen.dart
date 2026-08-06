import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'vitals_recording_screen.dart';
import 'patient_procedure_recording_screen.dart';

class NursingPatientsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const NursingPatientsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<NursingPatientsScreen> createState() => _NursingPatientsScreenState();
}

class _NursingPatientsScreenState extends State<NursingPatientsScreen> {
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
        title: const Text('Approved Patients'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
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
                fillColor: Colors.white,
              ),
            ),
          ),

          // Approved Appointments List (without vital signs)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('status', isEqualTo: 'approved')
                  .orderBy('appointmentDate', descending: true)
                  .snapshots(),
              builder: (context, appointmentSnapshot) {
                if (appointmentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (appointmentSnapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${appointmentSnapshot.error}'),
                      ],
                    ),
                  );
                }

                final appointments = appointmentSnapshot.data?.docs ?? [];

                // Get vital signs and procedures to check completion status
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('health_records')
                      .where('facilityId', isEqualTo: widget.facilityId)
                      .where('type', isEqualTo: 'VITAL_SIGNS')
                      .snapshots(),
                  builder: (context, vitalSignsSnapshot) {
                    if (vitalSignsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('nursing_procedures')
                          .where('facilityId', isEqualTo: widget.facilityId)
                          .snapshots(),
                      builder: (context, proceduresSnapshot) {
                        if (proceduresSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final today = DateFormat(
                          'yyyy-MM-dd',
                        ).format(DateTime.now());
                        final vitalSignsRecords =
                            vitalSignsSnapshot.data?.docs ?? [];
                        final proceduresRecords =
                            proceduresSnapshot.data?.docs ?? [];

                        // Map of patientId to vitals recorded today
                        final patientsWithVitalsToday =
                            <String, Map<String, dynamic>>{};
                        for (var doc in vitalSignsRecords) {
                          final data = doc.data() as Map<String, dynamic>;
                          final recordedDate =
                              data['recordedDateOnly'] as String?;
                          final patientId = data['patientId'] as String?;

                          if (recordedDate == today && patientId != null) {
                            patientsWithVitalsToday[patientId] = data;
                          }
                        }

                        // Map of patientId to procedures recorded today
                        final patientsWithProceduresToday = <String, bool>{};
                        for (var doc in proceduresRecords) {
                          final data = doc.data() as Map<String, dynamic>;
                          final patientId = data['patientId'] as String?;
                          final performedAt = data['performedAt'] as Timestamp?;

                          if (patientId != null && performedAt != null) {
                            final performedDate = DateFormat(
                              'yyyy-MM-dd',
                            ).format(performedAt.toDate());
                            if (performedDate == today) {
                              patientsWithProceduresToday[patientId] = true;
                            }
                          }
                        }

                        // Filter appointments by search query
                        final filteredAppointments = appointments.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final patientName =
                              data['patientName']?.toString().toLowerCase() ??
                              '';

                          // Show all appointments matching search
                          final matchesSearch =
                              _searchQuery.isEmpty ||
                              patientName.contains(_searchQuery);

                          return matchesSearch;
                        }).toList();

                        if (filteredAppointments.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 80,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No patients found matching "$_searchQuery"'
                                      : 'No patients found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Patients with approved appointments will appear here.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredAppointments.length,
                          itemBuilder: (context, index) {
                            final appointment =
                                filteredAppointments[index].data()
                                    as Map<String, dynamic>;
                            final appointmentId =
                                filteredAppointments[index].id;
                            final patientId =
                                appointment['patientId'] as String?;

                            // Check if patient has vitals and procedures recorded today
                            final hasVitalsToday =
                                patientId != null &&
                                patientsWithVitalsToday.containsKey(patientId);
                            final hasProcedureToday =
                                patientId != null &&
                                patientsWithProceduresToday.containsKey(
                                  patientId,
                                );
                            final todaysVitals = hasVitalsToday
                                ? patientsWithVitalsToday[patientId]
                                : null;

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
                                          backgroundColor: Colors.teal.shade700,
                                          child: Text(
                                            appointment['patientName']?[0]
                                                    ?.toUpperCase() ??
                                                'P',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                appointment['patientName'] ??
                                                    'Unknown Patient',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Age: ${appointment['patientAge'] ?? 'N/A'} | Gender: ${appointment['patientGender'] ?? 'N/A'}',
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
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            'APPROVED',
                                            style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Patient Details
                                    _buildInfoRow(
                                      'Phone',
                                      appointment['patientPhone'] ?? 'N/A',
                                    ),
                                    _buildInfoRow(
                                      'Appointment Date',
                                      appointment['appointmentDate'] ?? 'N/A',
                                    ),
                                    _buildInfoRow(
                                      'Assigned Doctor',
                                      appointment['assignedStaffName'] ?? 'N/A',
                                    ),
                                    if (appointment['reasonForVisit'] != null)
                                      _buildInfoRow(
                                        'Reason',
                                        appointment['reasonForVisit'],
                                      ),

                                    const SizedBox(height: 16),

                                    // Action Buttons: Only show if not completed today
                                    if (!hasVitalsToday ||
                                        !hasProcedureToday) ...[
                                      Row(
                                        children: [
                                          if (!hasVitalsToday)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _recordVitals(
                                                  appointment,
                                                  appointmentId,
                                                ),
                                                icon: const Icon(
                                                  Icons.monitor_heart,
                                                ),
                                                label: const Text(
                                                  'Record Vitals',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.red.shade600,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (!hasVitalsToday &&
                                              !hasProcedureToday)
                                            const SizedBox(width: 12),
                                          if (!hasProcedureToday)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _recordProcedure(
                                                      appointment,
                                                    ),
                                                icon: const Icon(
                                                  Icons.medical_services,
                                                ),
                                                label: const Text('Procedure'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.purple.shade600,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],

                                    // View Records Button - Always visible
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _viewPatientRecords(
                                          appointment,
                                          appointmentId,
                                        ),
                                        icon: const Icon(Icons.folder_open),
                                        label: const Text('View Records'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Show completion indicators
                                    if (hasVitalsToday ||
                                        hasProcedureToday) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (hasVitalsToday)
                                            InkWell(
                                              onTap: () =>
                                                  _viewVitals(todaysVitals!),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color:
                                                        Colors.green.shade200,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle,
                                                      size: 18,
                                                      color:
                                                          Colors.green.shade700,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Vitals Recorded',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .green
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.visibility,
                                                      size: 14,
                                                      color:
                                                          Colors.green.shade700,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (hasProcedureToday)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.purple.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    size: 18,
                                                    color:
                                                        Colors.purple.shade700,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Procedure Completed',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors
                                                          .purple
                                                          .shade700,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
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

  void _recordVitals(
    Map<String, dynamic> appointment,
    String appointmentId,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.monitor_heart, size: 48, color: Colors.red.shade600),
        title: const Text('Record Vital Signs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to record vital signs for:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment['patientName'] ?? 'Unknown Patient',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You will record:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ...[
              '• Blood Pressure (Systolic/Diastolic)',
              '• Temperature',
              '• Pulse Rate',
              '• Respiratory Rate',
              '• Oxygen Saturation (SpO2)',
              '• Additional observations',
            ].map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  item,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VitalsRecordingScreen(
          facilityId: widget.facilityId,
          patientId: appointment['patientId'] ?? '',
          patientName: appointment['patientName'] ?? 'Unknown Patient',
        ),
      ),
    );
  }

  void _viewVitals(Map<String, dynamic> vitals) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.monitor_heart, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Expanded(child: Text('Vital Signs (Today)')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVitalRow(
                'Blood Pressure',
                '${vitals['bloodPressure']?['systolic'] ?? 'N/A'}/${vitals['bloodPressure']?['diastolic'] ?? 'N/A'} mmHg',
              ),
              _buildVitalRow(
                'Temperature',
                '${vitals['temperature'] ?? 'N/A'} °C',
              ),
              _buildVitalRow('Pulse', '${vitals['pulse'] ?? 'N/A'} bpm'),
              _buildVitalRow(
                'Respiratory Rate',
                '${vitals['respiratoryRate'] ?? 'N/A'} /min',
              ),
              _buildVitalRow('SpO2', '${vitals['spo2'] ?? 'N/A'} %'),
              _buildVitalRow('Weight', '${vitals['weight'] ?? 'N/A'} kg'),
              _buildVitalRow('Height', '${vitals['height'] ?? 'N/A'} cm'),
              if (vitals['bmi'] != null) ...[
                _buildVitalRow(
                  'BMI',
                  '${vitals['bmi']?.toStringAsFixed(1)} - ${vitals['bmiCategory']}',
                ),
              ],
              if (vitals['bloodGlucose'] != null)
                _buildVitalRow(
                  'Blood Glucose',
                  '${vitals['bloodGlucose']} mg/dL',
                ),
              if (vitals['notes'] != null &&
                  vitals['notes'].toString().isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(vitals['notes'].toString()),
              ],
              const Divider(height: 24),
              Text(
                'Recorded by: ${vitals['recordedByRole'] == 'nursing' ? 'Nursing Staff' : 'Doctor'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                'Time: ${vitals['recordedDate'] ?? 'N/A'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _recordProcedure(Map<String, dynamic> appointment) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.medical_services,
          size: 48,
          color: Colors.purple.shade600,
        ),
        title: const Text('Record Nursing Procedure'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to record a nursing procedure for:',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment['patientName'] ?? 'Unknown Patient',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You can select from procedures like:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ...[
              '• Wound Dressing & Care',
              '• Catheterization',
              '• Injections (IM/IV/SC)',
              '• Specimen Collection',
              '• And more...',
            ].map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  item,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Navigate to procedure recording with pre-selected patient
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientProcedureRecordingScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          preSelectedPatientId: appointment['patientId'] ?? '',
          preSelectedPatientName:
              appointment['patientName'] ?? 'Unknown Patient',
        ),
      ),
    );
  }

  // View Patient Records - Shows comprehensive medical records
  void _viewPatientRecords(Map<String, dynamic> patient, String appointmentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_open,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient['patientName'] ?? 'Patient Records',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'View Only - No Editing Allowed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Tabs
              Expanded(
                child: DefaultTabController(
                  length: 5,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        labelColor: Colors.blue.shade700,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.blue.shade700,
                        tabs: const [
                          Tab(icon: Icon(Icons.info), text: 'Overview'),
                          Tab(icon: Icon(Icons.monitor_heart), text: 'Vitals'),
                          Tab(
                            icon: Icon(Icons.medical_services),
                            text: 'Ward Rounds',
                          ),
                          Tab(
                            icon: Icon(Icons.medication),
                            text: 'Medications',
                          ),
                          Tab(icon: Icon(Icons.science), text: 'Lab Tests'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildOverviewTab(patient),
                            _buildVitalsTab(appointmentId),
                            _buildWardRoundsTab(appointmentId),
                            _buildMedicationsTab(appointmentId),
                            _buildLabTestsTab(patient['patientId']),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> patient) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard('Patient Information', Icons.person, Colors.blue, [
            _buildRecordInfoRow('Patient ID', patient['patientId'] ?? 'N/A'),
            _buildRecordInfoRow(
              'Patient Name',
              patient['patientName'] ?? 'N/A',
            ),
            _buildRecordInfoRow(
              'Age',
              patient['patientAge']?.toString() ?? 'N/A',
            ),
            _buildRecordInfoRow('Gender', patient['patientGender'] ?? 'N/A'),
            _buildRecordInfoRow('Phone', patient['patientPhone'] ?? 'N/A'),
          ]),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Appointment Details',
            Icons.calendar_today,
            Colors.green,
            [
              _buildRecordInfoRow(
                'Appointment Date',
                patient['appointmentDate'] ?? 'N/A',
              ),
              _buildRecordInfoRow(
                'Assigned Doctor',
                patient['assignedStaffName'] ?? 'N/A',
              ),
              if (patient['reasonForVisit'] != null)
                _buildRecordInfoRow(
                  'Reason for Visit',
                  patient['reasonForVisit'],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsTab(String appointmentId) {
    // Query vitals by appointmentId
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_records')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('type', isEqualTo: 'VITAL_SIGNS')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final vitals = snapshot.data?.docs ?? [];

        if (vitals.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monitor_heart, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No vital signs recorded yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vitals.length,
          itemBuilder: (context, index) {
            final vital = vitals[index].data() as Map<String, dynamic>;
            final recordedAt = vital['createdAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monitor_heart, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Text(
                          recordedAt != null
                              ? DateFormat(
                                  'MMM dd, yyyy hh:mm a',
                                ).format(recordedAt.toDate())
                              : 'Unknown date',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildVitalRowWithUnit(
                      'Temperature',
                      vital['temperature'],
                      '°C',
                    ),
                    _buildVitalRowWithUnit('Pulse', vital['pulse'], 'bpm'),
                    _buildVitalRowWithUnit(
                      'Blood Pressure',
                      '${vital['systolic'] ?? '--'}/${vital['diastolic'] ?? '--'}',
                      'mmHg',
                    ),
                    _buildVitalRowWithUnit(
                      'Respiratory Rate',
                      vital['respiratoryRate'],
                      '/min',
                    ),
                    _buildVitalRowWithUnit(
                      'Oxygen Saturation',
                      vital['oxygenSaturation'],
                      '%',
                    ),
                    if (vital['notes'] != null &&
                        vital['notes'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Notes: ${vital['notes']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (vital['recordedByName'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Recorded by: ${vital['recordedByName']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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
  }

  Widget _buildWardRoundsTab(String appointmentId) {
    // Query consultation notes by appointmentId
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_records')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('recordType', isEqualTo: 'consultation')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rounds = snapshot.data?.docs ?? [];

        if (rounds.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No consultation notes recorded yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rounds.length,
          itemBuilder: (context, index) {
            final round = rounds[index].data() as Map<String, dynamic>;
            final roundDate = round['createdAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medical_services,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            roundDate != null
                                ? DateFormat(
                                    'MMM dd, yyyy hh:mm a',
                                  ).format(roundDate.toDate())
                                : 'Unknown date',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (round['chiefComplaint'] != null &&
                        round['chiefComplaint'].toString().isNotEmpty)
                      _buildRoundSection(
                        'Chief Complaint',
                        round['chiefComplaint'],
                      ),
                    if (round['presentingHistory'] != null &&
                        round['presentingHistory'].toString().isNotEmpty)
                      _buildRoundSection('History', round['presentingHistory']),
                    if (round['physicalExamination'] != null &&
                        round['physicalExamination'].toString().isNotEmpty)
                      _buildRoundSection(
                        'Physical Examination',
                        round['physicalExamination'],
                      ),
                    if (round['provisionalDiagnosis'] != null &&
                        round['provisionalDiagnosis'].toString().isNotEmpty)
                      _buildRoundSection(
                        'Provisional Diagnosis',
                        round['provisionalDiagnosis'],
                      ),
                    if (round['treatmentPlan'] != null &&
                        round['treatmentPlan'].toString().isNotEmpty)
                      _buildRoundSection(
                        'Treatment Plan',
                        round['treatmentPlan'],
                      ),
                    if (round['doctorName'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'By: Dr. ${round['doctorName']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
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
  }

  Widget _buildMedicationsTab(String appointmentId) {
    // Query prescriptions by appointmentId
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_records')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('recordType', isEqualTo: 'prescription')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final medications = snapshot.data?.docs ?? [];

        if (medications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medication, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No medications prescribed yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: medications.length,
          itemBuilder: (context, index) {
            final med = medications[index].data() as Map<String, dynamic>;
            final prescribedAt = med['createdAt'] as Timestamp?;
            final prescriptions = med['prescriptions'] as List<dynamic>? ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medication, color: Colors.teal.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            prescribedAt != null
                                ? DateFormat(
                                    'MMM dd, yyyy hh:mm a',
                                  ).format(prescribedAt.toDate())
                                : 'Unknown date',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (prescriptions.isNotEmpty)
                      ...prescriptions.map((prescription) {
                        final p = prescription as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['medicationName'] ?? 'Unknown medication',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _buildMedicationRow('Dosage', p['dosage']),
                                _buildMedicationRow(
                                  'Frequency',
                                  p['frequency'],
                                ),
                                _buildMedicationRow('Duration', p['duration']),
                                if (p['instructions'] != null &&
                                    p['instructions'].toString().isNotEmpty)
                                  _buildMedicationRow(
                                    'Instructions',
                                    p['instructions'],
                                  ),
                              ],
                            ),
                          ),
                        );
                      })
                    else
                      const Text('No prescription details available'),
                    if (med['doctorName'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Prescribed by: Dr. ${med['doctorName']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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
  }

  Widget _buildLabTestsTab(String? patientId) {
    if (patientId == null) {
      return const Center(child: Text('Patient ID not available'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_records')
          .where('patientId', isEqualTo: patientId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('recordType', isEqualTo: 'lab_test')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final labTests = snapshot.data?.docs ?? [];

        if (labTests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.science, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No lab tests recorded yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: labTests.length,
          itemBuilder: (context, index) {
            final test = labTests[index].data() as Map<String, dynamic>;
            final createdAt = test['createdAt'] as Timestamp?;
            final status = test['status'] ?? 'pending';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, color: Colors.purple.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            test['testName'] ?? 'Unknown test',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'completed'
                                ? Colors.green.shade100
                                : status == 'processing'
                                ? Colors.orange.shade100
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: status == 'completed'
                                  ? Colors.green.shade700
                                  : status == 'processing'
                                  ? Colors.orange.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (createdAt != null)
                      _buildLabTestRow(
                        'Requested',
                        DateFormat(
                          'MMM dd, yyyy hh:mm a',
                        ).format(createdAt.toDate()),
                      ),
                    if (test['results'] != null &&
                        test['results'].toString().isNotEmpty)
                      _buildLabTestRow('Results', test['results']),
                    if (test['notes'] != null &&
                        test['notes'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Notes: ${test['notes']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
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
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRecordInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalRowWithUnit(String label, dynamic value, String unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Text(
            value != null && value.toString().isNotEmpty
                ? '$value $unit'
                : '--',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
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
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMedicationRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '--',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabTestRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
