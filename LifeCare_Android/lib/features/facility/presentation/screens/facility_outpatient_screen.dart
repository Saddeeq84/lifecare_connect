// Out-Patient Screen
// Shows patients currently receiving treatment at the facility today
// These are patients who have approved appointments and are going through the treatment process
// Once all services are complete (consultation, vitals, labs, medication), they move to medical records

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'admission_screen.dart';
import 'patient_medical_records_viewer.dart';
import 'vitals_recording_screen.dart';
import 'facility_consultation_screen.dart';
import 'patient_procedure_recording_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FacilityOutpatientScreen extends StatefulWidget {
  final String? facilityId;
  final String? facilityName;
  final bool isNursingView; // True when accessed from nursing dashboard
  final bool
  filterBySpecialistDepartments; // True to show only specialist appointments
  final bool
  filterByEmergencyDepartment; // True to show only emergency appointments

  const FacilityOutpatientScreen({
    super.key,
    this.facilityId,
    this.facilityName,
    this.isNursingView = false, // Default to false for OPD access
    this.filterBySpecialistDepartments =
        false, // Default to false for general access
    this.filterByEmergencyDepartment =
        false, // Default to false for general access
  });

  @override
  State<FacilityOutpatientScreen> createState() =>
      _FacilityOutpatientScreenState();
}

class _FacilityOutpatientScreenState extends State<FacilityOutpatientScreen> {
  String facilityId = '';
  String facilityName = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  int _rebuildKey = 0; // Add rebuild counter to force FutureBuilder refresh

  @override
  void initState() {
    super.initState();
    _loadFacilityData();
  }

  Future<void> _loadFacilityData() async {
    if (widget.facilityId != null && widget.facilityName != null) {
      setState(() {
        facilityId = widget.facilityId!;
        facilityName = widget.facilityName!;
        _isLoading = false;
      });
    } else {
      // Fallback to Firebase Auth for direct facility login
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        setState(() {
          facilityId = firebaseUser.uid;
          _isLoading = false;
        });

        // Get facility name
        try {
          final facilityDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .get();
          if (facilityDoc.exists) {
            setState(() {
              facilityName = facilityDoc.data()?['name'] ?? '';
            });
          }
        } catch (e) {}
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Check if patient has completed all ORDERED services
  Future<Map<String, dynamic>> _getPatientServiceStatus(
    String patientId,
    String appointmentId,
  ) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // First, check if patient was manually marked as completed
      final completionQuery = await FirebaseFirestore.instance
          .collection('health_records')
          .where('patientId', isEqualTo: patientId)
          .where('facilityId', isEqualTo: facilityId)
          .where('recordType', isEqualTo: 'completion')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      bool manuallyCompleted = completionQuery.docs.isNotEmpty;

      if (manuallyCompleted) {
        // Patient was manually completed, so they should not appear in out-patient list
        return {
          'isComplete': true,
          'manuallyCompleted': true,
          'hasConsultation': true,
          'consultationComplete': true,
          'hasVitals': true,
          'hasLabResults': true,
          'labResultsComplete': true,
          'hasMedication': true,
          'medicationDispensed': true,
          'hasProcedures': true,
          'proceduresComplete': true,
          'pendingServices': <String>[],
          'requiredServices': <String>[],
          'orderedLabTests': <String>[],
          'orderedPrescriptions': <String>[],
          'orderedProcedures': <String>[],
          'completionPercentage': 100,
        };
      }

      // Then, check consultation status and get what was ordered
      // Check in facility_patients/{patientId}/consultations subcollection
      final consultationQuery = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .collection('consultations')
          .where(
            'consultedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'consultedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .get();

      bool hasConsultation = consultationQuery.docs.isNotEmpty;
      bool consultationComplete = consultationQuery.docs.any(
        (doc) => (doc.data())['status'] == 'completed',
      );

      // Get what services were ordered from the consultation record
      Map<String, dynamic>? consultationData;
      if (consultationQuery.docs.isNotEmpty) {
        consultationData = consultationQuery.docs.first.data();
      }

      // Extract ordered services from consultation
      // IMPORTANT: Only services that were actually ordered will be checked for completion
      // If doctor doesn't order lab tests, patient won't be held up waiting for lab results
      List<String> orderedLabTests = [];
      List<String> orderedPrescriptions = [];
      bool vitalsRequired =
          true; // Vitals are typically always required for consultations

      if (consultationData != null) {
        // Check if lab tests were ordered
        if (consultationData['labTests'] != null) {
          orderedLabTests = List<String>.from(
            consultationData['labTests'] ?? [],
          );
        }

        // Check if prescriptions were given
        if (consultationData['prescriptions'] != null) {
          orderedPrescriptions = List<String>.from(
            consultationData['prescriptions'] ?? [],
          );
        }
      }

      // Only check services that were actually ordered
      List<String> pendingServices = [];
      List<String> requiredServices = [
        'Consultation',
      ]; // Consultation is always required

      // Check consultation completion
      if (!hasConsultation || !consultationComplete) {
        pendingServices.add('Consultation');
      }

      // Check vital signs (usually required for all consultations)
      bool hasVitals = false;
      if (vitalsRequired) {
        requiredServices.add('Vital Signs');

        final vitalsQuery = await FirebaseFirestore.instance
            .collection('vitals_records')
            .where('patientId', isEqualTo: patientId)
            .where('facilityId', isEqualTo: facilityId)
            .where('appointmentId', isEqualTo: appointmentId)
            .where(
              'recordedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'recordedAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
            )
            .get();

        hasVitals = vitalsQuery.docs.isNotEmpty;
        if (!hasVitals) {
          pendingServices.add('Vital Signs');
        }
      }

      // Check lab results ONLY if lab tests were ordered
      bool hasLabResults = false;
      bool labResultsComplete = false;
      if (orderedLabTests.isNotEmpty) {
        requiredServices.add('Lab Results');

        final labQuery = await FirebaseFirestore.instance
            .collection('health_records')
            .where('patientId', isEqualTo: patientId)
            .where('facilityId', isEqualTo: facilityId)
            .where('appointmentId', isEqualTo: appointmentId)
            .where('recordType', isEqualTo: 'laboratory')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
            )
            .get();

        hasLabResults = labQuery.docs.isNotEmpty;
        labResultsComplete = labQuery.docs.any(
          (doc) => (doc.data())['status'] == 'completed',
        );

        if (!hasLabResults || !labResultsComplete) {
          pendingServices.add('Lab Results');
        }
      }

      // Check medication dispensing ONLY if prescriptions were given
      bool hasMedication = false;
      bool medicationDispensed = false;
      if (orderedPrescriptions.isNotEmpty) {
        requiredServices.add('Medication');

        final medicationQuery = await FirebaseFirestore.instance
            .collection('health_records')
            .where('patientId', isEqualTo: patientId)
            .where('facilityId', isEqualTo: facilityId)
            .where('appointmentId', isEqualTo: appointmentId)
            .where('recordType', isEqualTo: 'medication')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
            )
            .get();

        hasMedication = medicationQuery.docs.isNotEmpty;
        medicationDispensed = medicationQuery.docs.any(
          (doc) => (doc.data())['status'] == 'dispensed',
        );

        if (!hasMedication || !medicationDispensed) {
          pendingServices.add('Medication');
        }
      }

      // Check if procedures were performed (procedures can be done at any time during treatment)
      // Unlike lab tests and medications which must be ordered in consultation,
      // procedures are often performed as needed by nursing staff
      List<String> orderedProcedures = [];
      if (consultationData != null && consultationData['procedures'] != null) {
        orderedProcedures = List<String>.from(
          consultationData['procedures'] ?? [],
        );
      }

      // Check if ANY procedures were performed for this appointment today
      // Try with appointmentId first (new records), then fall back to patientId + date (old records)
      var proceduresQuery = await FirebaseFirestore.instance
          .collection('nursing_procedures')
          .where('patientId', isEqualTo: patientId)
          .where('facilityId', isEqualTo: facilityId)
          .where('appointmentId', isEqualTo: appointmentId)
          .where(
            'performedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'performedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
          )
          .get();

      // If no procedures found with appointmentId, try without (for backward compatibility with old records)
      if (proceduresQuery.docs.isEmpty) {
        proceduresQuery = await FirebaseFirestore.instance
            .collection('nursing_procedures')
            .where('patientId', isEqualTo: patientId)
            .where('facilityId', isEqualTo: facilityId)
            .where(
              'performedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'performedAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
            )
            .get();
      }

      bool hasProcedures = proceduresQuery.docs.isNotEmpty;
      bool proceduresComplete = proceduresQuery.docs.isNotEmpty;

      // If procedures were either ordered OR performed, count them in completion
      if (orderedProcedures.isNotEmpty || hasProcedures) {
        requiredServices.add('Procedures');

        // If procedures were ordered but not yet performed, mark as pending
        if (orderedProcedures.isNotEmpty && !hasProcedures) {
          pendingServices.add('Procedures');
        }
      }

      // Check if patient has been admitted for THIS appointment
      bool isAdmitted = false;
      final admissionQuery = await FirebaseFirestore.instance
          .collection('admissions')
          .where('patientId', isEqualTo: patientId)
          .where('facilityId', isEqualTo: facilityId)
          .where('appointmentId', isEqualTo: appointmentId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      isAdmitted = admissionQuery.docs.isNotEmpty;

      // Patient is complete when all ORDERED services are done
      bool isComplete = pendingServices.isEmpty;
      int totalRequiredServices = requiredServices.length;
      int completedServices = totalRequiredServices - pendingServices.length;

      // Debug logging
      print('=== Progress Calculation Debug ===');
      print('Patient ID: $patientId');
      print('Appointment ID: $appointmentId');
      print(
        'Required Services: $requiredServices (${requiredServices.length})',
      );
      print('Pending Services: $pendingServices (${pendingServices.length})');
      print('Completed Services: $completedServices');
      print('Has Vitals: $hasVitals');
      print(
        'Has Consultation: $hasConsultation, Complete: $consultationComplete',
      );
      print('Has Lab Results: $hasLabResults, Complete: $labResultsComplete');
      print('Has Medication: $hasMedication, Dispensed: $medicationDispensed');
      print('Has Procedures: $hasProcedures, Complete: $proceduresComplete');
      print(
        'Completion %: ${totalRequiredServices == 0 ? 100 : ((completedServices / totalRequiredServices) * 100).round()}',
      );
      print('================================');

      return {
        'isComplete': isComplete,
        'hasConsultation': hasConsultation,
        'consultationComplete': consultationComplete,
        'hasVitals': hasVitals,
        'hasLabResults': hasLabResults,
        'labResultsComplete': labResultsComplete,
        'hasMedication': hasMedication,
        'medicationDispensed': medicationDispensed,
        'hasProcedures': hasProcedures,
        'proceduresComplete': proceduresComplete,
        'isAdmitted': isAdmitted,
        'pendingServices': pendingServices,
        'requiredServices': requiredServices,
        'orderedLabTests': orderedLabTests,
        'orderedPrescriptions': orderedPrescriptions,
        'orderedProcedures': orderedProcedures,
        'completionPercentage': totalRequiredServices == 0
            ? 100
            : ((completedServices / totalRequiredServices) * 100).round(),
      };
    } catch (e) {
      return {
        'isComplete': false,
        'manuallyCompleted': false,
        'hasConsultation': false,
        'consultationComplete': false,
        'hasVitals': false,
        'hasLabResults': false,
        'labResultsComplete': false,
        'hasMedication': false,
        'medicationDispensed': false,
        'hasProcedures': false,
        'proceduresComplete': false,
        'isAdmitted': false,
        'pendingServices': ['Error loading'],
        'requiredServices': [],
        'orderedLabTests': [],
        'orderedPrescriptions': [],
        'orderedProcedures': [],
        'completionPercentage': 0,
      };
    }
  }

  Color _getStatusColor(List<String> pendingServices) {
    if (pendingServices.isEmpty) return Colors.green;
    if (pendingServices.length <= 1) return Colors.orange;
    if (pendingServices.length <= 2) return Colors.blue;
    return Colors.red;
  }

  String _getStatusText(List<String> pendingServices) {
    if (pendingServices.isEmpty) return 'COMPLETED';
    return 'IN PROGRESS';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || facilityId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Out-Patients'),
          backgroundColor: Colors.cyan,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Out-Patients'),
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search by patient name...',
                    hintStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.search, color: Colors.black54),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.black54,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Get approved appointments for this facility
        // If filterBySpecialistDepartments is true, only show specialist appointments
        // If filterByEmergencyDepartment is true, only show emergency appointments
        stream: widget.filterByEmergencyDepartment
            ? FirebaseFirestore.instance
                  .collection('appointments')
                  .where('facilityId', isEqualTo: facilityId)
                  .where('status', isEqualTo: 'approved')
                  .where('department', isEqualTo: 'Emergency Department')
                  .orderBy('appointmentDate', descending: true)
                  .snapshots()
            : widget.filterBySpecialistDepartments
            ? FirebaseFirestore.instance
                  .collection('appointments')
                  .where('facilityId', isEqualTo: facilityId)
                  .where('status', isEqualTo: 'approved')
                  .where(
                    'department',
                    whereIn: [
                      'Pediatrics',
                      'Obstetrics & Gynecology',
                      'Cardiology',
                      'Neurology',
                      'Surgery Department',
                      'Orthopedics',
                      'Dermatology',
                      'Ophthalmology Department',
                      'ENT Department',
                      'Dental Department',
                      'Physiotherapy',
                      'Mental Health',
                      'Specialist Department',
                    ],
                  )
                  .orderBy('appointmentDate', descending: true)
                  .snapshots()
            : FirebaseFirestore.instance
                  .collection('appointments')
                  .where('facilityId', isEqualTo: facilityId)
                  .where('status', isEqualTo: 'approved')
                  .orderBy('appointmentDate', descending: true)
                  .snapshots(),
        builder: (context, appointmentSnapshot) {
          if (appointmentSnapshot.connectionState == ConnectionState.waiting) {
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!appointmentSnapshot.hasData ||
              appointmentSnapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Out-Patients',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Patients with approved appointments will appear here',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This includes appointments approved from:\n• OPD Department\n• Specialist Departments\n• Any other facility location',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final allAppointments = appointmentSnapshot.data!.docs;

          return FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey(_rebuildKey), // Force rebuild when key changes
            future: _processOutpatients(allAppointments),
            builder: (context, processedSnapshot) {
              if (processedSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (processedSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error processing data: ${processedSnapshot.error}',
                  ),
                );
              }

              var outpatients = processedSnapshot.data ?? [];

              // Store original index for each patient before filtering
              List<Map<String, dynamic>> outpatientsWithIndex = [];
              for (int i = 0; i < outpatients.length; i++) {
                final patient = outpatients[i];
                final pendingServices =
                    patient['pendingServices'] as List<String>;

                // Only include patients who haven't completed all services
                if (pendingServices.isNotEmpty) {
                  outpatientsWithIndex.add({
                    ...patient,
                    'originalIndex': i + 1, // Store 1-based index
                  });
                }
              }

              // Apply filters (only search filter now)
              final filteredOutpatients = outpatientsWithIndex.where((patient) {
                // Search filter
                if (_searchQuery.isNotEmpty) {
                  final patientName = (patient['patientName'] ?? '')
                      .toString()
                      .toLowerCase();
                  if (!patientName.contains(_searchQuery)) return false;
                }

                return true;
              }).toList();

              if (filteredOutpatients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No results found for "$_searchQuery"'
                            : 'No patients in progress',
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        child: const Text('Clear Search'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredOutpatients.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final patient = filteredOutpatients[index];
                  final originalIndex = patient['originalIndex'] as int;
                  return _buildPatientCard(patient, originalIndex);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _processOutpatients(
    List<QueryDocumentSnapshot> appointments,
  ) async {
    List<Map<String, dynamic>> outpatients = [];

    // Get all active admissions to filter out admitted patients
    final admissionsSnapshot = await FirebaseFirestore.instance
        .collection('admissions')
        .where('facilityId', isEqualTo: facilityId)
        .where('status', whereIn: ['admitted', 'pending_acceptance'])
        .where('isActive', isEqualTo: true)
        .get();

    // Create a set of admitted patient IDs for quick lookup
    final admittedPatientIds = admissionsSnapshot.docs
        .map((doc) => doc.data()['patientId'] as String?)
        .where((id) => id != null)
        .toSet();

    for (var doc in appointments) {
      final appointment = doc.data() as Map<String, dynamic>;
      final patientId = appointment['patientId'];
      final appointmentId = doc.id;

      // Skip if patient is currently admitted to the ward
      if (admittedPatientIds.contains(patientId)) {
        continue;
      }

      // Get service status for this patient
      final serviceStatus = await _getPatientServiceStatus(
        patientId,
        appointmentId,
      );

      outpatients.add({
        ...appointment,
        'appointmentId': appointmentId,
        ...serviceStatus,
      });
    }

    return outpatients;
  }

  Widget _buildPatientCard(Map<String, dynamic> patient, int index) {
    final pendingServices =
        (patient['pendingServices'] as List?)?.cast<String>() ?? [];
    final completionPercentage = (patient['completionPercentage'] as int?) ?? 0;
    final statusColor = _getStatusColor(pendingServices);
    final statusText = _getStatusText(pendingServices);
    final consultationComplete = patient['consultationComplete'] == true;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _showPatientDetails(patient),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Patient Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        patient['patientName'] != null &&
                                patient['patientName'].isNotEmpty
                            ? patient['patientName'][0].toUpperCase()
                            : 'P',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Patient Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                patient['patientName'] ?? 'Unknown Patient',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '#$index',
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
                                patient['department'] ?? 'General',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Dr. ${patient['providerName'] ?? 'Unknown'}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Progress Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Treatment Progress',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '$completionPercentage%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: completionPercentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),

              // Consultation Complete Notice
              if (consultationComplete) ...[
                const SizedBox(height: 16),
                Container(
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
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Consultation Completed',
                          style: TextStyle(
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Primary Action Buttons Section (Treatment Actions)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Treatment Actions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Row 1: Vitals and Consultation
                    Row(
                      children: [
                        // Vitals Button/Indicator
                        Expanded(
                          child: !(patient['hasVitals'] == true)
                              ? OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.monitor_heart,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Vitals',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue.shade700,
                                    side: BorderSide(
                                      color: Colors.blue.shade300,
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _recordVitals(patient),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade700,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Vitals',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green.shade900,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),

                        // Consultation Button/Indicator
                        Expanded(
                          child: !consultationComplete
                              ? OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.medical_services,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Consult',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: widget.isNursingView
                                        ? Colors.grey
                                        : Colors.purple.shade700,
                                    side: BorderSide(
                                      color: widget.isNursingView
                                          ? Colors.grey.shade300
                                          : Colors.purple.shade300,
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: widget.isNursingView
                                      ? () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'This action is restricted to OPD department only',
                                              ),
                                              backgroundColor: Colors.orange,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      : () => _startConsultation(patient),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade700,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Consult',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green.shade900,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Row 2: Procedure and Admit
                    Row(
                      children: [
                        // Procedure Button
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.healing, size: 16),
                            label: const Text(
                              'Procedure',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.indigo.shade700,
                              side: BorderSide(
                                color: Colors.indigo.shade300,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _recordProcedure(patient),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Admit Button/Indicator
                        Expanded(
                          child: !(patient['isAdmitted'] == true)
                              ? ElevatedButton.icon(
                                  icon: const Icon(Icons.hotel, size: 16),
                                  label: const Text(
                                    'Admit',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.isNursingView
                                        ? Colors.grey.shade400
                                        : Colors.orange.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: widget.isNursingView
                                      ? () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'This action is restricted to OPD department only',
                                              ),
                                              backgroundColor: Colors.orange,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      : () => _admitPatient(patient),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade700,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Admitted',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green.shade900,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Secondary Action Buttons Section (Administrative Actions)
              Row(
                children: [
                  // View Records Button
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text(
                        'Records',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal.shade700,
                        side: BorderSide(
                          color: Colors.teal.shade300,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _viewPatientRecords(patient),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Mark Complete Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text(
                        'Mark Complete',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                        shadowColor: Colors.green.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _markPatientCompleted(patient),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markPatientCompleted(Map<String, dynamic> patient) async {
    // Show confirmation dialog
    bool? shouldComplete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Mark Completed'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to mark this patient as completed?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient: ${patient['patientName'] ?? 'Unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Department: ${patient['department'] ?? 'General'}'),
                    Text('Doctor: ${patient['providerName'] ?? 'Unknown'}'),
                    const SizedBox(height: 8),
                    Text(
                      'Completion: ${patient['completionPercentage']}%',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // Show pending services if any
              if (patient['pendingServices'] != null &&
                  (patient['pendingServices'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending Services:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...((patient['pendingServices'] as List).map(
                        (service) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• $service',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Text(
                'This will remove the patient from the out-patient list and make their records available in the medical records section.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Mark Completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldComplete == true) {
      try {
        // Update the appointment status to completed
        final appointmentId = patient['appointmentId'];
        if (appointmentId != null) {
          await FirebaseFirestore.instance
              .collection('appointments')
              .doc(appointmentId)
              .update({
                'status': 'completed',
                'completedAt': FieldValue.serverTimestamp(),
                'completedBy': FirebaseAuth.instance.currentUser?.uid,
                'manuallyCompleted': true, // Flag to indicate manual completion
                'updatedAt': FieldValue.serverTimestamp(),
              });

          // Create a completion record in health_records if it doesn't exist
          final today = DateTime.now();
          final startOfDay = DateTime(today.year, today.month, today.day);
          final endOfDay = DateTime(
            today.year,
            today.month,
            today.day,
            23,
            59,
            59,
          );

          final existingCompletionQuery = await FirebaseFirestore.instance
              .collection('health_records')
              .where('patientId', isEqualTo: patient['patientId'])
              .where('facilityId', isEqualTo: facilityId)
              .where('appointmentId', isEqualTo: appointmentId)
              .where('recordType', isEqualTo: 'completion')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where(
                'createdAt',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
              )
              .get();

          if (existingCompletionQuery.docs.isEmpty) {
            await FirebaseFirestore.instance.collection('health_records').add({
              'patientId': patient['patientId'],
              'patientName': patient['patientName'],
              'facilityId': facilityId,
              'appointmentId': appointmentId,
              'recordType': 'completion',
              'status': 'completed',
              'completionType': 'manual',
              'completedBy': FirebaseAuth.instance.currentUser?.uid,
              'createdAt': FieldValue.serverTimestamp(),
              'notes': 'Patient manually marked as completed by facility staff',
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Patient "${patient['patientName']}" marked as completed successfully!',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error completing patient: $e')),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Patient Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Patient Name',
                  patient['patientName'] ?? 'Unknown',
                ),
                _buildInfoRow('Doctor', patient['providerName'] ?? 'Unknown'),
                _buildInfoRow('Department', patient['department'] ?? 'General'),
                _buildInfoRow(
                  'Appointment Date',
                  patient['appointmentDate'] != null
                      ? DateFormat('MMM dd, yyyy HH:mm').format(
                          (patient['appointmentDate'] as Timestamp).toDate(),
                        )
                      : 'Not specified',
                ),
                if (patient['reason'] != null)
                  _buildInfoRow('Reason', patient['reason']),
                _buildInfoRow(
                  'Completion',
                  '${patient['completionPercentage']}%',
                ),

                const SizedBox(height: 12),
                const Text(
                  'Service Status:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Only show services that are actually required for this patient
                ..._buildRequiredServicesList(patient),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRequiredServicesList(Map<String, dynamic> patient) {
    List<Widget> serviceWidgets = [];
    List<String> requiredServices = List<String>.from(
      patient['requiredServices'] ?? [],
    );

    for (String service in requiredServices) {
      bool isCompleted = false;

      switch (service) {
        case 'Consultation':
          isCompleted =
              patient['hasConsultation'] == true &&
              patient['consultationComplete'] == true;
          break;
        case 'Vital Signs':
          isCompleted = patient['hasVitals'] == true;
          break;
        case 'Lab Results':
          isCompleted =
              patient['hasLabResults'] == true &&
              patient['labResultsComplete'] == true;
          break;
        case 'Medication':
          isCompleted =
              patient['hasMedication'] == true &&
              patient['medicationDispensed'] == true;
          break;
      }

      serviceWidgets.add(_buildServiceStatusRow(service, isCompleted));
    }

    return serviceWidgets;
  }

  Widget _buildServiceStatusRow(String service, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            service,
            style: TextStyle(
              color: isCompleted ? Colors.green : Colors.grey,
              fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _recordVitals(Map<String, dynamic> patient) {
    // Navigate to vitals recording screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VitalsRecordingScreen(
          patientId: patient['patientId'] ?? '',
          patientName: patient['patientName'] ?? 'Unknown Patient',
          facilityId: facilityId,
        ),
      ),
    ).then((_) {
      // Refresh the screen when returning from vitals recording
      setState(() {
        _rebuildKey++; // Force refresh to update progress
      });
    });
  }

  void _startConsultation(Map<String, dynamic> patient) async {
    // Get staff information from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final staffId =
        prefs.getString('staffId') ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    final staffName = prefs.getString('staffName') ?? 'Staff';

    // Navigate to consultation screen
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityConsultationScreen(
          patientId: patient['patientId'] ?? '',
          patientName: patient['patientName'] ?? 'Unknown Patient',
          facilityId: facilityId,
          clinicianId: staffId,
          clinicianName: staffName,
        ),
      ),
    ).then((_) {
      // Refresh the screen when returning from consultation
      setState(() {
        _rebuildKey++; // Force refresh to update progress
      });
    });
  }

  void _admitPatient(Map<String, dynamic> patient) async {
    // Get staff information from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final staffId =
        prefs.getString('staffId') ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    final staffName = prefs.getString('staffName') ?? 'Staff';

    // Navigate to admission screen with patient pre-selected
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdmissionScreen(
          facilityId: facilityId,
          facilityName: facilityName,
          staffId: staffId,
          staffName: staffName,
          patientId: patient['patientId'] ?? '',
          patientName: patient['patientName'] ?? 'Unknown Patient',
          admittingDepartment:
              patient['department']
                  as String?, // Pass the department from appointment
        ),
      ),
    );
  }

  void _viewPatientRecords(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientMedicalRecordsViewer(
          patientId: patient['patientId'] ?? '',
          patientName: patient['patientName'] ?? 'Unknown Patient',
          facilityId: facilityId,
          appointmentId: patient['appointmentId'],
        ),
      ),
    );
  }

  Future<void> _recordProcedure(Map<String, dynamic> patient) async {
    // Get staff information from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final staffId =
        prefs.getString('staffId') ??
        FirebaseAuth.instance.currentUser?.uid ??
        '';
    final staffName = prefs.getString('staffName') ?? 'Staff';

    // Navigate to procedure recording screen
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientProcedureRecordingScreen(
          facilityId: facilityId,
          facilityName: facilityName,
          staffId: staffId,
          staffName: staffName,
          preSelectedPatientId: patient['patientId'] ?? '',
          preSelectedPatientName: patient['patientName'] ?? 'Unknown Patient',
          appointmentId:
              patient['appointmentId'] ??
              '', // Pass appointmentId for progress tracking
        ),
      ),
    ).then((_) {
      // Refresh the screen when returning from procedure recording
      setState(() {
        _rebuildKey++; // Increment to force FutureBuilder to recalculate progress
      });
    });
  }
}
