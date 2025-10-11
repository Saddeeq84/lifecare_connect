// ignore_for_file: prefer_const_constructors, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/clinical_documentation.dart';
import '../models/consultation.dart';
import 'health_records_service.dart';

class ClinicalDocumentationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new clinical documentation
  static Future<String> createClinicalDocumentation({
    required String consultationId,
    required String patientId,
    required String patientName,
    required String providerId,
    required String providerName,
    required String providerType,
    required DateTime consultationDate,
    required String chiefComplaint,
    required HistoryOfPresentIllness hpi,
    required MedicalHistory medicalHistory,
    required SymptomEvaluation symptoms,
    required List<LabResult> labResults,
    required List<ImagingResult> imagingResults,
    String? previousEMRNotes,
    VitalSigns? vitalSigns,
    required String provisionalDiagnosis,
    required List<String> differentialDiagnoses,
    required List<String> supportiveToolsUsed,
    required List<Medication> medicationsPrescribed,
    required List<String> nonPharmacologicalAdvice,
    required String homeMonitoringPlan,
    required List<Referral> referralsOrdered,
    required FollowUpPlan followUpPlan,
    required List<String> patientEducationProvided,
    required String emergencyAdvice,
    String? patientFeedback,
    int? satisfactionRating,
    List<String>? attachments,
    Map<String, dynamic>? additionalNotes,
  }) async {
    try {
      final documentationData = {
        'consultationId': consultationId,
        'patientId': patientId,
        'patientName': patientName,
        'providerId': providerId,
        'providerName': providerName,
        'providerType': providerType,
        'consultationDate': Timestamp.fromDate(consultationDate),
        'chiefComplaint': chiefComplaint,
        'hpi': hpi.toMap(),
        'medicalHistory': medicalHistory.toMap(),
        'symptoms': symptoms.toMap(),
        'labResults': labResults.map((e) => e.toMap()).toList(),
        'imagingResults': imagingResults.map((e) => e.toMap()).toList(),
        'previousEMRNotes': previousEMRNotes,
        'vitalSigns': vitalSigns?.toMap(),
        'provisionalDiagnosis': provisionalDiagnosis,
        'differentialDiagnoses': differentialDiagnoses,
        'supportiveToolsUsed': supportiveToolsUsed,
        'medicationsPrescribed': medicationsPrescribed
            .map((e) => e.toMap())
            .toList(),
        'nonPharmacologicalAdvice': nonPharmacologicalAdvice,
        'homeMonitoringPlan': homeMonitoringPlan,
        'referralsOrdered': referralsOrdered.map((e) => e.toMap()).toList(),
        'followUpPlan': followUpPlan.toMap(),
        'patientEducationProvided': patientEducationProvided,
        'emergencyAdvice': emergencyAdvice,
        'patientFeedback': patientFeedback,
        'satisfactionRating': satisfactionRating,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'draft',
        'attachments': attachments ?? [],
        'additionalNotes': additionalNotes,
      };

      final docRef = await _firestore
          .collection('clinical_documentation')
          .add(documentationData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create clinical documentation: $e');
    }
  }

  /// Update clinical documentation
  static Future<void> updateClinicalDocumentation({
    required String documentationId,
    String? chiefComplaint,
    HistoryOfPresentIllness? hpi,
    MedicalHistory? medicalHistory,
    SymptomEvaluation? symptoms,
    List<LabResult>? labResults,
    List<ImagingResult>? imagingResults,
    String? previousEMRNotes,
    VitalSigns? vitalSigns,
    String? provisionalDiagnosis,
    List<String>? differentialDiagnoses,
    List<String>? supportiveToolsUsed,
    List<Medication>? medicationsPrescribed,
    List<String>? nonPharmacologicalAdvice,
    String? homeMonitoringPlan,
    List<Referral>? referralsOrdered,
    FollowUpPlan? followUpPlan,
    List<String>? patientEducationProvided,
    String? emergencyAdvice,
    String? patientFeedback,
    int? satisfactionRating,
    String? status,
    List<String>? attachments,
    Map<String, dynamic>? additionalNotes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (chiefComplaint != null) updateData['chiefComplaint'] = chiefComplaint;
      if (hpi != null) updateData['hpi'] = hpi.toMap();
      if (medicalHistory != null) {
        updateData['medicalHistory'] = medicalHistory.toMap();
      }
      if (symptoms != null) updateData['symptoms'] = symptoms.toMap();
      if (labResults != null) {
        updateData['labResults'] = labResults.map((e) => e.toMap()).toList();
      }
      if (imagingResults != null) {
        updateData['imagingResults'] = imagingResults
            .map((e) => e.toMap())
            .toList();
      }
      if (previousEMRNotes != null) {
        updateData['previousEMRNotes'] = previousEMRNotes;
      }
      if (vitalSigns != null) updateData['vitalSigns'] = vitalSigns.toMap();
      if (provisionalDiagnosis != null) {
        updateData['provisionalDiagnosis'] = provisionalDiagnosis;
      }
      if (differentialDiagnoses != null) {
        updateData['differentialDiagnoses'] = differentialDiagnoses;
      }
      if (supportiveToolsUsed != null) {
        updateData['supportiveToolsUsed'] = supportiveToolsUsed;
      }
      if (medicationsPrescribed != null) {
        updateData['medicationsPrescribed'] = medicationsPrescribed
            .map((e) => e.toMap())
            .toList();
      }
      if (nonPharmacologicalAdvice != null) {
        updateData['nonPharmacologicalAdvice'] = nonPharmacologicalAdvice;
      }
      if (homeMonitoringPlan != null) {
        updateData['homeMonitoringPlan'] = homeMonitoringPlan;
      }
      if (referralsOrdered != null) {
        updateData['referralsOrdered'] = referralsOrdered
            .map((e) => e.toMap())
            .toList();
      }
      if (followUpPlan != null) {
        updateData['followUpPlan'] = followUpPlan.toMap();
      }
      if (patientEducationProvided != null) {
        updateData['patientEducationProvided'] = patientEducationProvided;
      }
      if (emergencyAdvice != null) {
        updateData['emergencyAdvice'] = emergencyAdvice;
      }
      if (patientFeedback != null) {
        updateData['patientFeedback'] = patientFeedback;
      }
      if (satisfactionRating != null) {
        updateData['satisfactionRating'] = satisfactionRating;
      }
      if (status != null) updateData['status'] = status;
      if (attachments != null) updateData['attachments'] = attachments;
      if (additionalNotes != null) {
        updateData['additionalNotes'] = additionalNotes;
      }

      await _firestore
          .collection('clinical_documentation')
          .doc(documentationId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update clinical documentation: $e');
    }
  }

  /// Complete and submit clinical documentation to health records
  static Future<void> submitClinicalDocumentation({
    required String documentationId,
    required String patientId,
  }) async {
    try {
      // Get the documentation
      final doc = await _firestore
          .collection('clinical_documentation')
          .doc(documentationId)
          .get();

      if (!doc.exists) {
        throw Exception('Clinical documentation not found');
      }

      final documentation = ClinicalDocumentation.fromFirestore(doc);

      // Debug logging for tracing
      print('[DEBUG] Submitting CHW documentation to health_records:');
      print('  patientUid: $patientId');
      print('  chwUid: ${documentation.providerId}');
      print('  chwName: ${documentation.providerName}');
      print('  type: CHW_CONSULTATION');
      print('  consultationData: ${_formatForHealthRecord(documentation)}');

      // Create health record entry
      await HealthRecordsService.saveCHWConsultation(
        patientUid: patientId,
        chwUid: documentation.providerId,
        chwName: documentation.providerName,
        consultationData: _formatForHealthRecord(documentation),
      );

      // Update status to submitted
      await updateClinicalDocumentation(
        documentationId: documentationId,
        status: 'submitted',
      );
    } catch (e) {
      print('[ERROR] Failed to submit clinical documentation: $e');
      throw Exception('Failed to submit clinical documentation: $e');
    }
  }

  /// Get clinical documentation by consultation ID
  static Future<ClinicalDocumentation?> getByConsultationId(
    String consultationId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('clinical_documentation')
          .where('consultationId', isEqualTo: consultationId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ClinicalDocumentation.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get clinical documentation: $e');
    }
  }

  /// Get clinical documentation by ID
  static Future<ClinicalDocumentation?> getById(String documentationId) async {
    try {
      final doc = await _firestore
          .collection('clinical_documentation')
          .doc(documentationId)
          .get();

      if (doc.exists) {
        return ClinicalDocumentation.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get clinical documentation: $e');
    }
  }

  /// Get clinical documentation for a provider
  static Stream<QuerySnapshot> getByProviderId(String providerId) {
    return _firestore
        .collection('clinical_documentation')
        .where('providerId', isEqualTo: providerId)
        .orderBy('consultationDate', descending: true)
        .snapshots();
  }

  /// Get clinical documentation for a patient
  static Stream<QuerySnapshot> getByPatientId(String patientId) {
    return _firestore
        .collection('clinical_documentation')
        .where('patientId', isEqualTo: patientId)
        .orderBy('consultationDate', descending: true)
        .snapshots();
  }

  /// Create draft documentation from consultation
  static Future<String> createDraftFromConsultation(
    Consultation consultation,
  ) async {
    try {
      // Create basic draft with consultation info
      return await createClinicalDocumentation(
        consultationId: consultation.id,
        patientId: consultation.patientId,
        patientName: consultation.patientName,
        providerId: consultation.doctorId,
        providerName: consultation.doctorName,
        providerType: 'CHW', // Assuming CHW for now
        consultationDate: consultation.scheduledDateTime,
        chiefComplaint: consultation.reason ?? '',
        hpi: HistoryOfPresentIllness(
          onset: '',
          duration: '',
          severity: '',
          progression: '',
          aggravatingFactors: '',
          relievingFactors: '',
          associatedSymptoms: '',
        ),
        medicalHistory: MedicalHistory(
          chronicIllnesses: [],
          pastSurgeries: [],
          currentMedications: [],
          allergies: [],
          familyHistory: '',
          socialHistory: '',
        ),
        symptoms: SymptomEvaluation(symptoms: [], reviewOfSystems: ''),
        labResults: [],
        imagingResults: [],
        provisionalDiagnosis: '',
        differentialDiagnoses: [],
        supportiveToolsUsed: [],
        medicationsPrescribed: [],
        nonPharmacologicalAdvice: [],
        homeMonitoringPlan: '',
        referralsOrdered: [],
        followUpPlan: FollowUpPlan(
          nextVisit: '',
          communicationMethod: '',
          summaryProvided: '',
        ),
        patientEducationProvided: [],
        emergencyAdvice: '',
      );
    } catch (e) {
      throw Exception('Failed to create draft documentation: $e');
    }
  }

  /// Delete clinical documentation
  static Future<void> deleteClinicalDocumentation(
    String documentationId,
  ) async {
    try {
      await _firestore
          .collection('clinical_documentation')
          .doc(documentationId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete clinical documentation: $e');
    }
  }

  /// Format documentation for health record storage
  static Map<String, dynamic> _formatForHealthRecord(
    ClinicalDocumentation doc,
  ) {
    return {
      'consultationId': doc.consultationId,
      'chiefComplaint': doc.chiefComplaint,
      'provisionalDiagnosis': doc.provisionalDiagnosis,
      'differentialDiagnoses': doc.differentialDiagnoses,
      'medicationsPrescribed': doc.medicationsPrescribed
          .map(
            (m) => {
              'name': m.name,
              'dosage': m.dosage,
              'frequency': m.frequency,
              'duration': m.duration,
              'instructions': m.instructions,
            },
          )
          .toList(),
      'vitalSigns': doc.vitalSigns?.toMap(),
      'followUpPlan': doc.followUpPlan.toMap(),
      'emergencyAdvice': doc.emergencyAdvice,
      'patientEducationProvided': doc.patientEducationProvided,
      'homeMonitoringPlan': doc.homeMonitoringPlan,
      'nonPharmacologicalAdvice': doc.nonPharmacologicalAdvice,
      'referralsOrdered': doc.referralsOrdered.map((r) => r.toMap()).toList(),
      'symptoms': doc.symptoms.toMap(),
      'medicalHistory': doc.medicalHistory.toMap(),
      'hpi': doc.hpi.toMap(),
      'labResults': doc.labResults.map((l) => l.toMap()).toList(),
      'imagingResults': doc.imagingResults.map((i) => i.toMap()).toList(),
      'supportiveToolsUsed': doc.supportiveToolsUsed,
      'patientFeedback': doc.patientFeedback,
      'satisfactionRating': doc.satisfactionRating,
      'attachments': doc.attachments,
      'additionalNotes': doc.additionalNotes,
    };
  }

  /// Generate consultation summary for patient
  static String generateConsultationSummary(ClinicalDocumentation doc) {
    final summary = StringBuffer();

    summary.writeln('CONSULTATION SUMMARY');
    summary.writeln('Date: ${doc.formattedDate} at ${doc.formattedTime}');
    summary.writeln('Provider: ${doc.providerName} (${doc.providerType})');
    summary.writeln('Patient: ${doc.patientName}');
    summary.writeln('');

    summary.writeln('CHIEF COMPLAINT:');
    summary.writeln(doc.chiefComplaint);
    summary.writeln('');

    if (doc.provisionalDiagnosis.isNotEmpty) {
      summary.writeln('DIAGNOSIS:');
      summary.writeln(doc.provisionalDiagnosis);
      summary.writeln('');
    }

    if (doc.medicationsPrescribed.isNotEmpty) {
      summary.writeln('MEDICATIONS PRESCRIBED:');
      for (final med in doc.medicationsPrescribed) {
        summary.writeln('- ${med.displayText}');
        if (med.instructions.isNotEmpty) {
          summary.writeln('  Instructions: ${med.instructions}');
        }
      }
      summary.writeln('');
    }

    if (doc.nonPharmacologicalAdvice.isNotEmpty) {
      summary.writeln('ADVICE:');
      for (final advice in doc.nonPharmacologicalAdvice) {
        summary.writeln('- $advice');
      }
      summary.writeln('');
    }

    if (doc.homeMonitoringPlan.isNotEmpty) {
      summary.writeln('HOME MONITORING:');
      summary.writeln(doc.homeMonitoringPlan);
      summary.writeln('');
    }

    if (doc.followUpPlan.nextVisit.isNotEmpty) {
      summary.writeln('FOLLOW-UP:');
      summary.writeln(doc.followUpPlan.nextVisit);
      summary.writeln('');
    }

    if (doc.emergencyAdvice.isNotEmpty) {
      summary.writeln('EMERGENCY ADVICE:');
      summary.writeln(doc.emergencyAdvice);
      summary.writeln('');
    }

    return summary.toString();
  }
}
