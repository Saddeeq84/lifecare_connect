import 'query_snapshot_fake.dart';
// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'consultation_service.dart';

class AppointmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new appointment
  static Future<String> createAppointment({
    required String patientId,
    required String patientName,
    required String providerId,
    required String providerName,
    required String providerType, // 'CHW', 'DOCTOR', 'FACILITY'
    required DateTime appointmentDate,
    required String reason,
    String? notes,
    String? facilityId,
    String? facilityName,
  }) async {
    try {
      final appointmentData = {
        'patientId': patientId,
        'patientName': patientName,
        'providerId': providerId,
        'providerName': providerName,
        'providerType': providerType,
        'appointmentDate': Timestamp.fromDate(appointmentDate),
        'reason': reason,
        'notes': notes,
        'status': 'pending', // pending, approved, denied, completed, cancelled
        'facilityId': facilityId,
        'facilityName': facilityName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // For CHW appointments
        if (providerType == 'CHW') 'chwId': providerId,
        // For doctor appointments
        if (providerType == 'DOCTOR') 'doctorId': providerId,
        // For facility appointments
        if (providerType == 'FACILITY') 'staffId': providerId,
      };

      final docRef = await _firestore
          .collection('appointments')
          .add(appointmentData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create appointment: $e');
    }
  }

  /// Update appointment status
  static Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? notes,
  }) async {
    try {
      // Update the appointment
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (notes != null) 'statusNotes': notes,
      });

      // If appointment is approved and it's with a doctor, automatically create a consultation
      if (status == 'approved') {
        await _createConsultationFromAppointment(appointmentId);
      }
    } catch (e) {
      throw Exception('Failed to update appointment status: $e');
    }
  }

  /// Private method to create consultation from approved appointment
  static Future<void> _createConsultationFromAppointment(
    String appointmentId,
  ) async {
    try {
      // Get the appointment details
      final appointmentDoc = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();

      if (!appointmentDoc.exists) return;

      final appointmentData = appointmentDoc.data() as Map<String, dynamic>;

      // Create consultation for both doctor and CHW appointments
      final providerType =
          appointmentData['providerType']?.toString().toLowerCase() ?? '';

      // Skip if it's not a valid provider type that requires consultations
      if (![
        'doctor',
        'community health worker',
        'chw',
      ].contains(providerType)) {
        print(
          '⚠️ Skipping consultation creation for provider type: ${appointmentData['providerType']}',
        );
        return;
      }

      print(
        '🏥 Creating consultation for approved appointment with provider type: ${appointmentData['providerType']}',
      );

      // Check if consultation already exists for this appointment in health_records
      final existingConsultation = await _firestore
          .collection('health_records')
          .where('appointmentId', isEqualTo: appointmentId)
          .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
          .get();

      if (existingConsultation.docs.isNotEmpty) {
        return; // Consultation already exists
      }

      // Create consultation from appointment data with field name fallback handling
      final patientId =
          appointmentData['patientId'] ?? appointmentData['patientUid'];
      final patientName = appointmentData['patientName'];

      if (patientId == null || patientName == null) {
        print(
          '❌ Missing required patient information: patientId=$patientId, patientName=$patientName',
        );
        return;
      }

      await ConsultationService.createConsultation(
        patientId: patientId,
        patientName: patientName,
        doctorId: appointmentData['providerId'],
        doctorName: appointmentData['providerName'],
        facilityId: appointmentData['facilityId'],
        facilityName: appointmentData['facilityName'],
        type: 'in-person', // Default type, can be updated later
        scheduledDateTime: (appointmentData['appointmentDate'] as Timestamp)
            .toDate(),
        estimatedDurationMinutes: 30, // Default duration
        priority: 'routine', // Default priority
        reason: appointmentData['reason'],
        chiefComplaint: appointmentData['notes'],
        createdBy:
            appointmentData['chwId'] ?? patientId, // CHW or patient who booked
        appointmentId: appointmentId, // Link back to original appointment
      );

      print(
        '✅ Consultation created successfully for appointment $appointmentId',
      );
    } catch (e) {
      print(
        '❌ Error creating consultation from appointment $appointmentId: $e',
      );
      // Don't throw error to avoid breaking the appointment approval process
    }
  }

  /// Create consultations for existing approved appointments that don't have consultations
  static Future<void> createMissingConsultations() async {
    try {
      print('🔍 Checking for approved appointments without consultations...');

      // Get all approved appointments
      final approvedAppointments = await _firestore
          .collection('appointments')
          .where('status', isEqualTo: 'approved')
          .get();

      print(
        '📋 Found ${approvedAppointments.docs.length} approved appointments',
      );

      int created = 0;
      int skipped = 0;

      for (var doc in approvedAppointments.docs) {
        final appointmentId = doc.id;

        // Check if consultation already exists
        final existingConsultation = await _firestore
            .collection('consultations')
            .where('appointmentId', isEqualTo: appointmentId)
            .get();

        if (existingConsultation.docs.isEmpty) {
          // No consultation exists, create one
          try {
            await _createConsultationFromAppointment(appointmentId);
            created++;
            print('✅ Created consultation for appointment $appointmentId');
          } catch (e) {
            print(
              '❌ Failed to create consultation for appointment $appointmentId: $e',
            );
            skipped++;
          }
        } else {
          skipped++;
        }
      }

      print(
        '📊 Migration complete: $created consultations created, $skipped skipped',
      );
    } catch (e) {
      print('❌ Error during consultation migration: $e');
      throw Exception('Failed to create missing consultations: $e');
    }
  }

  /// Reschedule appointment
  static Future<void> rescheduleAppointment({
    required String appointmentId,
    required DateTime newDate,
    String? notes,
  }) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'appointmentDate': Timestamp.fromDate(newDate),
        'status': 'pending', // Reset to pending after rescheduling
        'updatedAt': FieldValue.serverTimestamp(),
        if (notes != null) 'rescheduleNotes': notes,
      });
    } catch (e) {
      throw Exception('Failed to reschedule appointment: $e');
    }
  }

  /// Get appointments for CHW
  static Stream<QuerySnapshot> getCHWAppointments({
    required String chwId,
    String? status,
    List<String>? statusList,
  }) {
    Query query = _firestore
        .collection('appointments')
        .where('chwId', isEqualTo: chwId);

    if (statusList != null && statusList.isNotEmpty) {
      query = query.where('status', whereIn: statusList);
    } else if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.orderBy('appointmentDate', descending: false).snapshots();
  }

  /// Get appointments for patient
  static Stream<QuerySnapshot> getPatientAppointments({
    required String patientId,
    String? status,
  }) {
    Query query = _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.orderBy('appointmentDate', descending: false).snapshots();
  }

  /// Get appointments for doctor
  static Stream<QuerySnapshot> getDoctorAppointments({
    required String doctorId,
    String? status,
  }) {
    final collection = _firestore.collection('appointments');
    Query query = collection.where('doctorId', isEqualTo: doctorId);
    Query altQuery = collection.where('providerId', isEqualTo: doctorId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
      altQuery = altQuery.where('status', isEqualTo: status);
    }

    // Combine both queries using snapshots and merge results
    final doctorStream = query
        .orderBy('appointmentDate', descending: false)
        .snapshots();
    final providerStream = altQuery
        .orderBy('appointmentDate', descending: false)
        .snapshots();

    return doctorStream.asyncMap((doctorSnap) async {
      final providerSnap = await providerStream.first;
      // Merge docs, avoiding duplicates
      final allDocs = <String, QueryDocumentSnapshot>{};
      for (var doc in doctorSnap.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in providerSnap.docs) {
        allDocs[doc.id] = doc;
      }
      // Return a QuerySnapshot-like object
      return QuerySnapshotFake(allDocs.values.toList());
    });
  }

  /// Get appointments for facility
  static Stream<QuerySnapshot> getFacilityAppointments({
    required String facilityId,
    String? status,
  }) {
    Query query = _firestore
        .collection('appointments')
        .where('facilityId', isEqualTo: facilityId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.orderBy('appointmentDate', descending: false).snapshots();
  }

  /// Cancel appointment
  static Future<void> cancelAppointment({
    required String appointmentId,
    String? reason,
  }) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'cancellationReason': reason,
      });
    } catch (e) {
      throw Exception('Failed to cancel appointment: $e');
    }
  }

  /// Complete appointment (mark as done)
  static Future<void> completeAppointment({
    required String appointmentId,
    String? notes,
  }) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (notes != null) 'completionNotes': notes,
      });
    } catch (e) {
      throw Exception('Failed to complete appointment: $e');
    }
  }

  /// Get appointment by ID
  static Future<DocumentSnapshot> getAppointmentById(
    String appointmentId,
  ) async {
    try {
      return await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();
    } catch (e) {
      throw Exception('Failed to get appointment: $e');
    }
  }

  /// Search appointments
  static Stream<QuerySnapshot> searchAppointments({
    required String currentUserId,
    required String userRole,
    String? searchQuery,
    String? status,
  }) {
    Query query;

    // Base query based on user role
    switch (userRole.toLowerCase()) {
      case 'chw':
        query = _firestore
            .collection('appointments')
            .where('chwId', isEqualTo: currentUserId);
        break;
      case 'doctor':
        query = _firestore
            .collection('appointments')
            .where('doctorId', isEqualTo: currentUserId);
        break;
      case 'patient':
        query = _firestore
            .collection('appointments')
            .where('patientId', isEqualTo: currentUserId);
        break;
      case 'facility':
        query = _firestore
            .collection('appointments')
            .where('facilityId', isEqualTo: currentUserId);
        break;
      default:
        query = _firestore.collection('appointments');
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.orderBy('appointmentDate', descending: false).snapshots();
  }
}
