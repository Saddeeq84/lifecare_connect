// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consultation.dart';
import '../models/appointment.dart';

class ConsultationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new consultation (now saves to health_records)
  static Future<String> createConsultation({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    String? facilityId,
    String? facilityName,
    required String type,
    String? reason,
    String? chiefComplaint,
    required DateTime scheduledDateTime,
    required int estimatedDurationMinutes,
    required String priority,
    String? referralId,
    String? appointmentId,
    String? notes,
    required String createdBy,
  }) async {
    try {
      final consultationData = {
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'facilityId': facilityId,
        'facilityName': facilityName,
        'type': type,
        'status': 'scheduled',
        'reason': reason,
        'chiefComplaint': chiefComplaint,
        'scheduledDateTime': Timestamp.fromDate(scheduledDateTime),
        'estimatedDurationMinutes': estimatedDurationMinutes,
        'priority': priority,
        'referralId': referralId,
        'appointmentId': appointmentId,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };

      // Save to health_records instead of consultations
      final docRef = await _firestore.collection('health_records').add({
        'type': 'DOCTOR_CONSULTATION',
        'patientUid': patientId,
        'providerId': doctorId,
        'doctorUid': doctorId,
        'providerName': doctorName,
        'providerType': 'DOCTOR',
        'date': FieldValue.serverTimestamp(),
        'data': consultationData,
        'accessibleBy': ['patient', 'doctor', 'chw'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isEditable': false,
        'isDeletable': false,
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create consultation: $e');
    }
  }

  /// Update consultation status and details
  static Future<void> updateConsultation({
    required String consultationId,
    String? status,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    String? diagnosis,
    List<String>? prescriptions,
    List<String>? recommendations,
    String? followUpInstructions,
    DateTime? nextAppointmentDate,
    Map<String, dynamic>? vitals,
    String? notes,
    String? cancelledBy,
    String? cancellationReason,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status != null) updateData['status'] = status;
      if (actualStartTime != null) {
        updateData['actualStartTime'] = Timestamp.fromDate(actualStartTime);
      }
      if (actualEndTime != null) {
        updateData['actualEndTime'] = Timestamp.fromDate(actualEndTime);
      }
      if (diagnosis != null) updateData['diagnosis'] = diagnosis;
      if (prescriptions != null) updateData['prescriptions'] = prescriptions;
      if (recommendations != null) {
        updateData['recommendations'] = recommendations;
      }
      if (followUpInstructions != null) {
        updateData['followUpInstructions'] = followUpInstructions;
      }
      if (nextAppointmentDate != null) {
        updateData['nextAppointmentDate'] = Timestamp.fromDate(
          nextAppointmentDate,
        );
      }
      if (vitals != null) updateData['vitals'] = vitals;
      if (notes != null) updateData['notes'] = notes;
      if (cancelledBy != null) updateData['cancelledBy'] = cancelledBy;
      if (cancellationReason != null) {
        updateData['cancellationReason'] = cancellationReason;
      }

      // Update in health_records instead of consultations
      await _firestore.collection('health_records').doc(consultationId).update({
        'data': updateData,
      });
    } catch (e) {
      throw Exception('Failed to update consultation: $e');
    }
  }

  /// Start a consultation (set status to in-progress)
  static Future<void> startConsultation(String consultationId) async {
    await updateConsultation(
      consultationId: consultationId,
      status: 'in-progress',
      actualStartTime: DateTime.now(),
    );
  }

  /// Complete a consultation
  static Future<void> completeConsultation({
    required String consultationId,
    String? diagnosis,
    List<String>? prescriptions,
    List<String>? recommendations,
    String? followUpInstructions,
    DateTime? nextAppointmentDate,
    Map<String, dynamic>? vitals,
    String? notes,
  }) async {
    await updateConsultation(
      consultationId: consultationId,
      status: 'completed',
      actualEndTime: DateTime.now(),
      diagnosis: diagnosis,
      prescriptions: prescriptions,
      recommendations: recommendations,
      followUpInstructions: followUpInstructions,
      nextAppointmentDate: nextAppointmentDate,
      vitals: vitals,
      notes: notes,
    );
  }

  /// Cancel a consultation
  static Future<void> cancelConsultation({
    required String consultationId,
    required String cancelledBy,
    required String cancellationReason,
  }) async {
    await updateConsultation(
      consultationId: consultationId,
      status: 'cancelled',
      cancelledBy: cancelledBy,
      cancellationReason: cancellationReason,
    );
  }

  /// Mark consultation as no-show
  static Future<void> markNoShow(String consultationId) async {
    await updateConsultation(consultationId: consultationId, status: 'no-show');
  }

  /// Get consultations for a specific doctor
  static Stream<QuerySnapshot> getDoctorConsultations({
    required String doctorId,
    String? status,
    List<String>? statusList,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore
        .collection('health_records')
        .where('providerId', isEqualTo: doctorId)
        .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
        .orderBy('date', descending: false);

    // Filtering by status if needed
    if (status != null) {
      query = query.where('data.status', isEqualTo: status);
    } else if (statusList != null && statusList.isNotEmpty) {
      query = query.where('data.status', whereIn: statusList);
    }

    return query.snapshots();
  }

  /// Get consultations for a specific patient
  static Stream<QuerySnapshot> getPatientConsultations({
    required String patientId,
    String? status,
    List<String>? statusList,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore
        .collection('health_records')
        .where('patientUid', isEqualTo: patientId)
        .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
        .orderBy('date', descending: true);

    if (status != null) {
      query = query.where('data.status', isEqualTo: status);
    } else if (statusList != null && statusList.isNotEmpty) {
      query = query.where('data.status', whereIn: statusList);
    }

    return query.snapshots();
  }

  /// Get today's consultations for a doctor
  static Stream<QuerySnapshot> getTodayConsultations({
    required String doctorId,
  }) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('consultations')
        .where('doctorId', isEqualTo: doctorId)
        .where(
          'scheduledDateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'scheduledDateTime',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
        )
        .orderBy('scheduledDateTime', descending: false)
        .snapshots();
  }

  /// Get consultations created by or involving a CHW
  static Stream<QuerySnapshot> getCHWConsultations({required String chwId}) {
    return _firestore
        .collection('consultations')
        .where('chwId', isEqualTo: chwId)
        .orderBy('scheduledDateTime', descending: false)
        .snapshots();
  }

  /// Get upcoming consultations for a patient
  static Stream<QuerySnapshot> getUpcomingPatientConsultations({
    required String patientId,
    int? limitCount,
  }) {
    Query query = _firestore
        .collection('consultations')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'scheduled')
        .where(
          'scheduledDateTime',
          isGreaterThan: Timestamp.fromDate(DateTime.now()),
        )
        .orderBy('scheduledDateTime', descending: false);

    if (limitCount != null) {
      query = query.limit(limitCount);
    }

    return query.snapshots();
  }

  /// Get consultations by referral ID
  static Stream<QuerySnapshot> getConsultationsByReferral({
    required String referralId,
  }) {
    return _firestore
        .collection('consultations')
        .where('referralId', isEqualTo: referralId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Search consultations by patient name or doctor name
  static Future<List<Consultation>> searchConsultations({
    required String searchTerm,
    String? doctorId,
    String? patientId,
    int? limitCount,
  }) async {
    try {
      Query query = _firestore.collection('consultations');

      if (doctorId != null) {
        query = query.where('doctorId', isEqualTo: doctorId);
      }
      if (patientId != null) {
        query = query.where('patientId', isEqualTo: patientId);
      }

      final snapshot = await query.get();

      final consultations = snapshot.docs
          .map((doc) => Consultation.fromFirestore(doc))
          .where(
            (consultation) =>
                consultation.patientName.toLowerCase().contains(
                  searchTerm.toLowerCase(),
                ) ||
                consultation.doctorName.toLowerCase().contains(
                  searchTerm.toLowerCase(),
                ) ||
                (consultation.diagnosis?.toLowerCase().contains(
                      searchTerm.toLowerCase(),
                    ) ??
                    false) ||
                (consultation.reason?.toLowerCase().contains(
                      searchTerm.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();

      consultations.sort(
        (a, b) => b.scheduledDateTime.compareTo(a.scheduledDateTime),
      );

      if (limitCount != null && consultations.length > limitCount) {
        return consultations.take(limitCount).toList();
      }

      return consultations;
    } catch (e) {
      throw Exception('Failed to search consultations: $e');
    }
  }

  /// Get consultation statistics for a doctor
  static Future<Map<String, int>> getDoctorConsultationStats({
    required String doctorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('consultations')
          .where('doctorId', isEqualTo: doctorId);

      if (startDate != null) {
        query = query.where(
          'scheduledDateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }
      if (endDate != null) {
        query = query.where(
          'scheduledDateTime',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();
      final consultations = snapshot.docs
          .map((doc) => Consultation.fromFirestore(doc))
          .toList();

      return {
        'total': consultations.length,
        'scheduled': consultations.where((c) => c.status == 'scheduled').length,
        'completed': consultations.where((c) => c.status == 'completed').length,
        'cancelled': consultations.where((c) => c.status == 'cancelled').length,
        'no_show': consultations.where((c) => c.status == 'no-show').length,
        'in_progress': consultations
            .where((c) => c.status == 'in-progress')
            .length,
      };
    } catch (e) {
      throw Exception('Failed to get consultation statistics: $e');
    }
  }

  /// Check for consultation conflicts
  static Future<bool> hasConflictingConsultation({
    required String doctorId,
    required DateTime scheduledDateTime,
    required int durationMinutes,
    String? excludeConsultationId,
  }) async {
    try {
      final startTime = scheduledDateTime;
      final endTime = scheduledDateTime.add(Duration(minutes: durationMinutes));

      Query query = _firestore
          .collection('consultations')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', whereIn: ['scheduled', 'in-progress'])
          .where(
            'scheduledDateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              startTime.subtract(Duration(hours: 2)),
            ),
          )
          .where(
            'scheduledDateTime',
            isLessThanOrEqualTo: Timestamp.fromDate(
              endTime.add(Duration(hours: 2)),
            ),
          );

      final snapshot = await query.get();
      final consultations = snapshot.docs
          .map((doc) => Consultation.fromFirestore(doc))
          .toList();

      for (final consultation in consultations) {
        if (excludeConsultationId != null &&
            consultation.id == excludeConsultationId) {
          continue;
        }

        final existingStart = consultation.scheduledDateTime;
        final existingEnd = consultation.scheduledDateTime.add(
          Duration(minutes: consultation.estimatedDurationMinutes),
        );

        // Check for overlap
        if (startTime.isBefore(existingEnd) && endTime.isAfter(existingStart)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      throw Exception('Failed to check for conflicts: $e');
    }
  }

  /// Get single consultation by ID
  static Future<Consultation?> getConsultationById(
    String consultationId,
  ) async {
    try {
      final doc = await _firestore
          .collection('consultations')
          .doc(consultationId)
          .get();

      if (doc.exists) {
        return Consultation.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get consultation: $e');
    }
  }

  /// Delete consultation
  static Future<void> deleteConsultation(String consultationId) async {
    try {
      await _firestore.collection('consultations').doc(consultationId).delete();
    } catch (e) {
      throw Exception('Failed to delete consultation: $e');
    }
  }

  /// Create consultation from approved appointment
  static Future<Consultation?> createConsultationFromAppointment(
    Appointment appointment,
    String createdBy,
  ) async {
    try {
      final consultationData = {
        'patientId': appointment.patientId,
        'patientName': appointment.patientName,
        'doctorId': appointment
            .providerId, // The provider becomes the doctor in consultation
        'doctorName': appointment.providerName,
        'facilityId': appointment.facilityId,
        'facilityName': appointment.facilityName,
        'type': appointment.appointmentType,
        'consultationType': appointment.appointmentType,
        'status': 'scheduled',
        'reason': appointment.reason,
        'chiefComplaint': appointment.reason,
        'scheduledDateTime': Timestamp.fromDate(appointment.appointmentDate),
        'estimatedDurationMinutes': 60, // Default duration
        'priority': 'normal',
        'referralId': null,
        'appointmentId': appointment.id, // Link back to appointment
        'notes': appointment.notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'chwId': appointment.providerType == 'CHW'
            ? appointment.providerId
            : null,
        'providerId': appointment.providerId,
        'providerName': appointment.providerName,
        'providerType': appointment.providerType,
      };

      final docRef = await _firestore
          .collection('consultations')
          .add(consultationData);

      // Get the created consultation
      final doc = await docRef.get();
      return Consultation.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to create consultation from appointment: $e');
    }
  }
}
