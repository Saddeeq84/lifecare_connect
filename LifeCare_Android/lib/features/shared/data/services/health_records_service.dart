// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'package:cloud_firestore/cloud_firestore.dart';

class HealthRecordsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save ANC checklist data to patient's health records
  static Future<String> saveANCRecord({
    required String patientUid,
    required String chwUid,
    required String chwName,
    required Map<String, dynamic> ancData,
  }) async {
    try {
      final recordData = {
        'type': 'ANC_VISIT',
        'patientUid': patientUid,
        'providerId': chwUid,
        'chwUid': chwUid, // Added for Firestore rules compatibility
        'providerName': chwName,
        'providerType': 'CHW',
        'date': FieldValue.serverTimestamp(),
        'data': ancData,
        'accessibleBy': [
          'patient',
          'chw',
          'doctor',
        ], // Who can access this record
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEditable': false, // Cannot be edited after submission
        'isDeletable': false, // Cannot be deleted after submission
      };

      final docRef = await _firestore
          .collection('health_records')
          .add(recordData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save ANC record: $e');
    }
  }

  /// Save doctor consultation to patient's health records
  static Future<String> saveDoctorConsultation({
    required String patientUid,
    required String doctorUid,
    required String doctorName,
    required Map<String, dynamic> consultationData,
  }) async {
    try {
      final recordData = {
        'type': 'DOCTOR_CONSULTATION',
        'patientUid': patientUid,
        'providerId': doctorUid,
        'doctorUid': doctorUid,
        'providerName': doctorName,
        'providerType': 'DOCTOR',
        'date': FieldValue.serverTimestamp(),
        'data': consultationData,
        'accessibleBy': ['patient', 'doctor', 'chw'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEditable': false, // Cannot be edited after submission
        'isDeletable': false, // Cannot be deleted after submission
      };

      final docRef = await _firestore
          .collection('health_records')
          .add(recordData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save doctor consultation: $e');
    }
  }

  /// Save CHW consultation to patient's health records
  static Future<String> saveCHWConsultation({
    required String patientUid,
    required String chwUid,
    required String chwName,
    required Map<String, dynamic> consultationData,
  }) async {
    try {
      final recordData = {
        'type': 'CHW_CONSULTATION',
        'patientUid': patientUid,
        'patientId': patientUid,
        'providerId': chwUid,
        'chwUid': chwUid,
        'chwId': chwUid,
        'providerName': chwName,
        'providerType': 'CHW',
        'date': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'data': consultationData,
        'accessibleBy': ['patient', 'chw', 'doctor'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEditable': false, // Cannot be edited after submission
        'isDeletable': false, // Cannot be deleted after submission
        'statusFlag': 'completed',
      };
      final docRef = await _firestore
          .collection('health_records')
          .add(recordData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save CHW consultation: $e');
    }
  }

  /// Save patient self-reported vital signs
  static Future<String> saveSelfReportedVitals({
    required String patientUid,
    required String patientName,
    required Map<String, dynamic> vitalsData,
  }) async {
    try {
      final recordData = {
        'type': 'SELF_REPORTED_VITALS',
        'patientUid': patientUid,
        'providerId': patientUid,
        'providerName': patientName,
        'providerType': 'PATIENT',
        'date': FieldValue.serverTimestamp(),
        'data': vitalsData,
        'accessibleBy': ['patient', 'doctor', 'chw'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEditable': false, // Cannot be edited after submission
        'isDeletable': false, // Cannot be deleted after submission
      };

      final docRef = await _firestore
          .collection('health_records')
          .add(recordData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save self-reported vitals: $e');
    }
  }

  /// Save patient lab results
  static Future<String> saveLabResults({
    required String patientUid,
    required String patientName,
    required Map<String, dynamic> labData,
    List<String>? fileUrls,
  }) async {
    try {
      final recordData = {
        'type': 'LAB_RESULTS',
        'patientUid': patientUid,
        'providerId': patientUid,
        'providerName': patientName,
        'providerType': 'PATIENT',
        'date': FieldValue.serverTimestamp(),
        'data': labData,
        'fileUrls': fileUrls ?? [],
        'accessibleBy': ['patient', 'doctor', 'chw'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEditable': false, // Cannot be edited after submission
        'isDeletable': false, // Cannot be deleted after submission
      };

      final docRef = await _firestore
          .collection('health_records')
          .add(recordData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save lab results: $e');
    }
  }

  /// Save patient pre-consultation checklist
  static Future<String> savePreConsultationChecklist({
    required String patientUid,
    required String patientName,
    required Map<String, dynamic> checklistData,
  }) async {
    try {
      final recordData = {
        'userId': patientUid,
        'patientId': patientUid, // Keep for backward compatibility
        'type': 'pre_consultation',
        'recordType': 'Pre-Consultation Checklist',
        'consultationType': 'Pre-Consultation Assessment',
        'patientUid': patientUid,
        'providerId': patientUid,
        'providerName': patientName,
        'providerType': 'PATIENT',
        'date': FieldValue.serverTimestamp(),
        'consultationDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'data': checklistData,
        'symptoms': checklistData['symptoms'] ?? '',
        'currentMedications': checklistData['currentMedications'] ?? '',
        'allergies': checklistData['allergies'] ?? '',
        'medicalHistory': checklistData['medicalHistory'] ?? '',
        'reason': checklistData['reason'] ?? '',
        'accessibleBy': ['patient', 'doctor', 'chw'],
        'isEditable': false, // Cannot be edited after submission
        'isDeletable': false, // Cannot be deleted after submission
        'requiresReview':
            true, // Needs CHW/Doctor review before appointment approval
      };

      final docRef = await _firestore
          .collection('health_records')
          .add(recordData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save pre-consultation checklist: $e');
    }
  }

  /// Save facility test results
  static Future<String> saveFacilityResults({
    required String patientUid,
    required String facilityId,
    required String facilityName,
    required Map<String, dynamic> resultsData,
    List<String>? fileUrls,
  }) async {
    try {
      final recordData = {
        'type': 'FACILITY_RESULTS',
        'patientUid': patientUid,
        'providerId': facilityId,
        'facilityId': facilityId,
        'providerName': facilityName,
        'providerType': 'FACILITY',
        'date': FieldValue.serverTimestamp(),
        'data': resultsData,
        'fileUrls': fileUrls ?? [],
        'accessibleBy': ['patient', 'doctor', 'chw'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEditable': false, // Cannot be edited after submission
        'isDeletable': false, // Cannot be deleted after submission
      };

      final docRef = await _firestore
          .collection('health_records')
          .add(recordData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save facility results: $e');
    }
  }

  /// Get health records for a patient with role-based filtering
  static Stream<QuerySnapshot> getPatientHealthRecords({
    required String patientUid,
    required String currentUserRole,
    String? currentUserId,
  }) {
    Query query = _firestore
        .collection('health_records')
        .where('patientUid', isEqualTo: patientUid)
        .orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  /// Get specific health record by ID
  static Future<DocumentSnapshot> getHealthRecord(String recordId) async {
    try {
      return await _firestore.collection('health_records').doc(recordId).get();
    } catch (e) {
      throw Exception('Failed to get health record: $e');
    }
  }

  /// Check if a record can be edited (always false for audit trail)
  static bool canEditRecord(Map<String, dynamic> recordData) {
    return false; // No records can be edited after submission
  }

  /// Check if a record can be deleted (always false for audit trail)
  static bool canDeleteRecord(Map<String, dynamic> recordData) {
    return false; // No records can be deleted after submission
  }

  /// Get records by type for a patient
  static Stream<QuerySnapshot> getRecordsByType({
    required String patientUid,
    required String recordType,
    String? currentUserRole,
    String? currentUserId,
  }) {
    Query query = _firestore
        .collection('health_records')
        .where('patientUid', isEqualTo: patientUid)
        .where('type', isEqualTo: recordType)
        .orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  /// Get display-friendly type name
  static String getDisplayType(String type) {
    switch (type) {
      case 'ANC_VISIT':
        return 'ANC Visit';
      case 'DOCTOR_CONSULTATION':
        return 'Doctor Consultation';
      case 'CHW_CONSULTATION':
        return 'CHW Consultation';
      case 'SELF_REPORTED_VITALS':
        return 'Self-Reported Vitals';
      case 'LAB_RESULTS':
        return 'Lab Results';
      case 'PRE_CONSULTATION_CHECKLIST':
        return 'Pre-Consultation Checklist';
      case 'FACILITY_RESULTS':
        return 'Facility Results';
      default:
        return 'Health Record';
    }
  }

  /// Get icon for record type
  static String getRecordIcon(String type) {
    switch (type) {
      case 'ANC_VISIT':
        return '🤱';
      case 'DOCTOR_CONSULTATION':
        return '👩‍⚕️';
      case 'CHW_CONSULTATION':
        return '🏥';
      case 'SELF_REPORTED_VITALS':
        return '📊';
      case 'LAB_RESULTS':
        return '🧪';
      case 'PRE_CONSULTATION_CHECKLIST':
        return '📋';
      case 'FACILITY_RESULTS':
        return '🏢';
      default:
        return '📄';
    }
  }
}
