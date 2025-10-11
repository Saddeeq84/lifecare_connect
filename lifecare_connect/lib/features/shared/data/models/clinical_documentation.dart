import 'package:cloud_firestore/cloud_firestore.dart';

class ClinicalDocumentation {
  final String id;
  final String consultationId;
  final String patientId;
  final String patientName;
  final String providerId;
  final String providerName;
  final String providerType; // CHW, DOCTOR, NURSE
  final DateTime consultationDate;

  // Clinical Assessment
  final String chiefComplaint;
  final HistoryOfPresentIllness hpi;
  final MedicalHistory medicalHistory;
  final SymptomEvaluation symptoms;

  // Review of Medical Data
  final List<LabResult> labResults;
  final List<ImagingResult> imagingResults;
  final String? previousEMRNotes;
  final VitalSigns? vitalSigns;

  // Diagnosis & Clinical Decision
  final String provisionalDiagnosis;
  final List<String> differentialDiagnoses;
  final List<String> supportiveToolsUsed;

  // Treatment & Advice
  final List<Medication> medicationsPrescribed;
  final List<String> nonPharmacologicalAdvice;
  final String homeMonitoringPlan;
  final List<Referral> referralsOrdered;

  // Post-consultation Summary
  final FollowUpPlan followUpPlan;
  final List<String> patientEducationProvided;
  final String emergencyAdvice;

  // Feedback & Evaluation
  final String? patientFeedback;
  final int? satisfactionRating; // 1-5 scale

  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status; // draft, completed, submitted
  final List<String> attachments; // File URLs
  final Map<String, dynamic>? additionalNotes;

  const ClinicalDocumentation({
    required this.id,
    required this.consultationId,
    required this.patientId,
    required this.patientName,
    required this.providerId,
    required this.providerName,
    required this.providerType,
    required this.consultationDate,
    required this.chiefComplaint,
    required this.hpi,
    required this.medicalHistory,
    required this.symptoms,
    required this.labResults,
    required this.imagingResults,
    this.previousEMRNotes,
    this.vitalSigns,
    required this.provisionalDiagnosis,
    required this.differentialDiagnoses,
    required this.supportiveToolsUsed,
    required this.medicationsPrescribed,
    required this.nonPharmacologicalAdvice,
    required this.homeMonitoringPlan,
    required this.referralsOrdered,
    required this.followUpPlan,
    required this.patientEducationProvided,
    required this.emergencyAdvice,
    this.patientFeedback,
    this.satisfactionRating,
    required this.createdAt,
    this.updatedAt,
    required this.status,
    required this.attachments,
    this.additionalNotes,
  });

  factory ClinicalDocumentation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ClinicalDocumentation(
      id: doc.id,
      consultationId: data['consultationId'] ?? '',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      providerType: data['providerType'] ?? '',
      consultationDate: (data['consultationDate'] as Timestamp).toDate(),
      chiefComplaint: data['chiefComplaint'] ?? '',
      hpi: HistoryOfPresentIllness.fromMap(data['hpi'] ?? {}),
      medicalHistory: MedicalHistory.fromMap(data['medicalHistory'] ?? {}),
      symptoms: SymptomEvaluation.fromMap(data['symptoms'] ?? {}),
      labResults: (data['labResults'] as List? ?? [])
          .map((e) => LabResult.fromMap(e as Map<String, dynamic>))
          .toList(),
      imagingResults: (data['imagingResults'] as List? ?? [])
          .map((e) => ImagingResult.fromMap(e as Map<String, dynamic>))
          .toList(),
      previousEMRNotes: data['previousEMRNotes'],
      vitalSigns: data['vitalSigns'] != null
          ? VitalSigns.fromMap(data['vitalSigns'] as Map<String, dynamic>)
          : null,
      provisionalDiagnosis: data['provisionalDiagnosis'] ?? '',
      differentialDiagnoses: List<String>.from(
        data['differentialDiagnoses'] ?? [],
      ),
      supportiveToolsUsed: List<String>.from(data['supportiveToolsUsed'] ?? []),
      medicationsPrescribed: (data['medicationsPrescribed'] as List? ?? [])
          .map((e) => Medication.fromMap(e as Map<String, dynamic>))
          .toList(),
      nonPharmacologicalAdvice: List<String>.from(
        data['nonPharmacologicalAdvice'] ?? [],
      ),
      homeMonitoringPlan: data['homeMonitoringPlan'] ?? '',
      referralsOrdered: (data['referralsOrdered'] as List? ?? [])
          .map((e) => Referral.fromMap(e as Map<String, dynamic>))
          .toList(),
      followUpPlan: FollowUpPlan.fromMap(data['followUpPlan'] ?? {}),
      patientEducationProvided: List<String>.from(
        data['patientEducationProvided'] ?? [],
      ),
      emergencyAdvice: data['emergencyAdvice'] ?? '',
      patientFeedback: data['patientFeedback'],
      satisfactionRating: data['satisfactionRating'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'draft',
      attachments: List<String>.from(data['attachments'] ?? []),
      additionalNotes: data['additionalNotes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': status,
      'attachments': attachments,
      'additionalNotes': additionalNotes,
    };
  }

  String get formattedDate {
    return '${consultationDate.day}/${consultationDate.month}/${consultationDate.year}';
  }

  String get formattedTime {
    return '${consultationDate.hour.toString().padLeft(2, '0')}:${consultationDate.minute.toString().padLeft(2, '0')}';
  }

  bool get isCompleted => status == 'completed';
  bool get isSubmitted => status == 'submitted';
  bool get isDraft => status == 'draft';
}

// Supporting classes
class HistoryOfPresentIllness {
  final String onset;
  final String duration;
  final String severity;
  final String progression;
  final String aggravatingFactors;
  final String relievingFactors;
  final String associatedSymptoms;

  const HistoryOfPresentIllness({
    required this.onset,
    required this.duration,
    required this.severity,
    required this.progression,
    required this.aggravatingFactors,
    required this.relievingFactors,
    required this.associatedSymptoms,
  });

  factory HistoryOfPresentIllness.fromMap(Map<String, dynamic> map) {
    return HistoryOfPresentIllness(
      onset: map['onset'] ?? '',
      duration: map['duration'] ?? '',
      severity: map['severity'] ?? '',
      progression: map['progression'] ?? '',
      aggravatingFactors: map['aggravatingFactors'] ?? '',
      relievingFactors: map['relievingFactors'] ?? '',
      associatedSymptoms: map['associatedSymptoms'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'onset': onset,
      'duration': duration,
      'severity': severity,
      'progression': progression,
      'aggravatingFactors': aggravatingFactors,
      'relievingFactors': relievingFactors,
      'associatedSymptoms': associatedSymptoms,
    };
  }
}

class MedicalHistory {
  final List<String> chronicIllnesses;
  final List<String> pastSurgeries;
  final List<String> currentMedications;
  final List<String> allergies;
  final String familyHistory;
  final String socialHistory;

  const MedicalHistory({
    required this.chronicIllnesses,
    required this.pastSurgeries,
    required this.currentMedications,
    required this.allergies,
    required this.familyHistory,
    required this.socialHistory,
  });

  factory MedicalHistory.fromMap(Map<String, dynamic> map) {
    return MedicalHistory(
      chronicIllnesses: List<String>.from(map['chronicIllnesses'] ?? []),
      pastSurgeries: List<String>.from(map['pastSurgeries'] ?? []),
      currentMedications: List<String>.from(map['currentMedications'] ?? []),
      allergies: List<String>.from(map['allergies'] ?? []),
      familyHistory: map['familyHistory'] ?? '',
      socialHistory: map['socialHistory'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chronicIllnesses': chronicIllnesses,
      'pastSurgeries': pastSurgeries,
      'currentMedications': currentMedications,
      'allergies': allergies,
      'familyHistory': familyHistory,
      'socialHistory': socialHistory,
    };
  }
}

class SymptomEvaluation {
  final List<SymptomItem> symptoms;
  final String reviewOfSystems;

  const SymptomEvaluation({
    required this.symptoms,
    required this.reviewOfSystems,
  });

  factory SymptomEvaluation.fromMap(Map<String, dynamic> map) {
    return SymptomEvaluation(
      symptoms: (map['symptoms'] as List? ?? [])
          .map((e) => SymptomItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      reviewOfSystems: map['reviewOfSystems'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'symptoms': symptoms.map((e) => e.toMap()).toList(),
      'reviewOfSystems': reviewOfSystems,
    };
  }
}

class SymptomItem {
  final String type;
  final String duration;
  final String severity; // mild, moderate, severe
  final String description;

  const SymptomItem({
    required this.type,
    required this.duration,
    required this.severity,
    required this.description,
  });

  factory SymptomItem.fromMap(Map<String, dynamic> map) {
    return SymptomItem(
      type: map['type'] ?? '',
      duration: map['duration'] ?? '',
      severity: map['severity'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'duration': duration,
      'severity': severity,
      'description': description,
    };
  }
}

class LabResult {
  final String testName;
  final String result;
  final String normalRange;
  final DateTime datePerformed;
  final String? fileUrl;

  const LabResult({
    required this.testName,
    required this.result,
    required this.normalRange,
    required this.datePerformed,
    this.fileUrl,
  });

  factory LabResult.fromMap(Map<String, dynamic> map) {
    return LabResult(
      testName: map['testName'] ?? '',
      result: map['result'] ?? '',
      normalRange: map['normalRange'] ?? '',
      datePerformed: (map['datePerformed'] as Timestamp).toDate(),
      fileUrl: map['fileUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'testName': testName,
      'result': result,
      'normalRange': normalRange,
      'datePerformed': Timestamp.fromDate(datePerformed),
      'fileUrl': fileUrl,
    };
  }
}

class ImagingResult {
  final String type; // X-ray, CT, MRI, etc.
  final String findings;
  final DateTime datePerformed;
  final String? fileUrl;

  const ImagingResult({
    required this.type,
    required this.findings,
    required this.datePerformed,
    this.fileUrl,
  });

  factory ImagingResult.fromMap(Map<String, dynamic> map) {
    return ImagingResult(
      type: map['type'] ?? '',
      findings: map['findings'] ?? '',
      datePerformed: (map['datePerformed'] as Timestamp).toDate(),
      fileUrl: map['fileUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'findings': findings,
      'datePerformed': Timestamp.fromDate(datePerformed),
      'fileUrl': fileUrl,
    };
  }
}

class VitalSigns {
  final double? heartRate;
  final double? temperature;
  final String? bloodPressure; // e.g., "120/80"
  final double? respiratoryRate;
  final double? oxygenSaturation;
  final double? weight;
  final double? height;
  final DateTime dateRecorded;

  const VitalSigns({
    this.heartRate,
    this.temperature,
    this.bloodPressure,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.weight,
    this.height,
    required this.dateRecorded,
  });

  factory VitalSigns.fromMap(Map<String, dynamic> map) {
    return VitalSigns(
      heartRate: map['heartRate']?.toDouble(),
      temperature: map['temperature']?.toDouble(),
      bloodPressure: map['bloodPressure'],
      respiratoryRate: map['respiratoryRate']?.toDouble(),
      oxygenSaturation: map['oxygenSaturation']?.toDouble(),
      weight: map['weight']?.toDouble(),
      height: map['height']?.toDouble(),
      dateRecorded: (map['dateRecorded'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'heartRate': heartRate,
      'temperature': temperature,
      'bloodPressure': bloodPressure,
      'respiratoryRate': respiratoryRate,
      'oxygenSaturation': oxygenSaturation,
      'weight': weight,
      'height': height,
      'dateRecorded': Timestamp.fromDate(dateRecorded),
    };
  }
}

class Medication {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String instructions;

  const Medication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      duration: map['duration'] ?? '',
      instructions: map['instructions'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
    };
  }

  String get displayText => '$name $dosage $frequency × $duration';
}

class Referral {
  final String type; // lab, specialist, facility
  final String destination;
  final String reason;
  final String urgency; // routine, urgent, emergency
  final DateTime? scheduledDate;

  const Referral({
    required this.type,
    required this.destination,
    required this.reason,
    required this.urgency,
    this.scheduledDate,
  });

  factory Referral.fromMap(Map<String, dynamic> map) {
    return Referral(
      type: map['type'] ?? '',
      destination: map['destination'] ?? '',
      reason: map['reason'] ?? '',
      urgency: map['urgency'] ?? '',
      scheduledDate: map['scheduledDate'] != null
          ? (map['scheduledDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'destination': destination,
      'reason': reason,
      'urgency': urgency,
      'scheduledDate': scheduledDate != null
          ? Timestamp.fromDate(scheduledDate!)
          : null,
    };
  }
}

class FollowUpPlan {
  final String nextVisit; // e.g., "Virtual follow-up in 3 days"
  final DateTime? nextVisitDate;
  final String communicationMethod; // SMS, call, video, in-person
  final String summaryProvided; // where summary was sent

  const FollowUpPlan({
    required this.nextVisit,
    this.nextVisitDate,
    required this.communicationMethod,
    required this.summaryProvided,
  });

  factory FollowUpPlan.fromMap(Map<String, dynamic> map) {
    return FollowUpPlan(
      nextVisit: map['nextVisit'] ?? '',
      nextVisitDate: map['nextVisitDate'] != null
          ? (map['nextVisitDate'] as Timestamp).toDate()
          : null,
      communicationMethod: map['communicationMethod'] ?? '',
      summaryProvided: map['summaryProvided'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nextVisit': nextVisit,
      'nextVisitDate': nextVisitDate != null
          ? Timestamp.fromDate(nextVisitDate!)
          : null,
      'communicationMethod': communicationMethod,
      'summaryProvided': summaryProvided,
    };
  }
}
