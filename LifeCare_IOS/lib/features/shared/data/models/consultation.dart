import 'package:cloud_firestore/cloud_firestore.dart';

class Consultation {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String? facilityId;
  final String? facilityName;
  final String type; // 'in-person', 'telemedicine', 'follow-up'
  final String
  status; // 'scheduled', 'in-progress', 'completed', 'cancelled', 'no-show'
  final String? reason;
  final String? chiefComplaint;
  final DateTime scheduledDateTime;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;
  final int estimatedDurationMinutes;
  final String priority; // 'routine', 'urgent', 'emergency'
  final String? referralId; // If this consultation is from a referral
  final String? appointmentId; // If this consultation is from an appointment
  final String? notes;
  final String? diagnosis;
  final List<String>? prescriptions;
  final List<String>? recommendations;
  final String? followUpInstructions;
  final DateTime? nextAppointmentDate;
  final Map<String, dynamic>? vitals;
  final List<String>? attachments;
  final String? cancelledBy;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  const Consultation({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    this.facilityId,
    this.facilityName,
    required this.type,
    required this.status,
    this.reason,
    this.chiefComplaint,
    required this.scheduledDateTime,
    this.actualStartTime,
    this.actualEndTime,
    required this.estimatedDurationMinutes,
    required this.priority,
    this.referralId,
    this.appointmentId,
    this.notes,
    this.diagnosis,
    this.prescriptions,
    this.recommendations,
    this.followUpInstructions,
    this.nextAppointmentDate,
    this.vitals,
    this.attachments,
    this.cancelledBy,
    this.cancellationReason,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  factory Consultation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Consultation(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      facilityId: data['facilityId'],
      facilityName: data['facilityName'],
      type: data['type'] ?? 'in-person',
      status: data['status'] ?? 'scheduled',
      reason: data['reason'],
      chiefComplaint: data['chiefComplaint'],
      scheduledDateTime:
          (data['scheduledDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actualStartTime: (data['actualStartTime'] as Timestamp?)?.toDate(),
      actualEndTime: (data['actualEndTime'] as Timestamp?)?.toDate(),
      estimatedDurationMinutes: data['estimatedDurationMinutes'] ?? 30,
      priority: data['priority'] ?? 'routine',
      referralId: data['referralId'],
      appointmentId: data['appointmentId'],
      notes: data['notes'],
      diagnosis: data['diagnosis'],
      prescriptions: data['prescriptions'] != null
          ? List<String>.from(data['prescriptions'])
          : null,
      recommendations: data['recommendations'] != null
          ? List<String>.from(data['recommendations'])
          : null,
      followUpInstructions: data['followUpInstructions'],
      nextAppointmentDate: (data['nextAppointmentDate'] as Timestamp?)
          ?.toDate(),
      vitals: data['vitals'] as Map<String, dynamic>?,
      attachments: data['attachments'] != null
          ? List<String>.from(data['attachments'])
          : null,
      cancelledBy: data['cancelledBy'],
      cancellationReason: data['cancellationReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'facilityId': facilityId,
      'facilityName': facilityName,
      'type': type,
      'status': status,
      'reason': reason,
      'chiefComplaint': chiefComplaint,
      'scheduledDateTime': Timestamp.fromDate(scheduledDateTime),
      'actualStartTime': actualStartTime != null
          ? Timestamp.fromDate(actualStartTime!)
          : null,
      'actualEndTime': actualEndTime != null
          ? Timestamp.fromDate(actualEndTime!)
          : null,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'priority': priority,
      'referralId': referralId,
      'appointmentId': appointmentId,
      'notes': notes,
      'diagnosis': diagnosis,
      'prescriptions': prescriptions,
      'recommendations': recommendations,
      'followUpInstructions': followUpInstructions,
      'nextAppointmentDate': nextAppointmentDate != null
          ? Timestamp.fromDate(nextAppointmentDate!)
          : null,
      'vitals': vitals,
      'attachments': attachments,
      'cancelledBy': cancelledBy,
      'cancellationReason': cancellationReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
    };
  }

  Consultation copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    String? facilityId,
    String? facilityName,
    String? type,
    String? status,
    String? reason,
    String? chiefComplaint,
    DateTime? scheduledDateTime,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    int? estimatedDurationMinutes,
    String? priority,
    String? referralId,
    String? notes,
    String? diagnosis,
    List<String>? prescriptions,
    List<String>? recommendations,
    String? followUpInstructions,
    DateTime? nextAppointmentDate,
    Map<String, dynamic>? vitals,
    List<String>? attachments,
    String? cancelledBy,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Consultation(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      type: type ?? this.type,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      priority: priority ?? this.priority,
      referralId: referralId ?? this.referralId,
      notes: notes ?? this.notes,
      diagnosis: diagnosis ?? this.diagnosis,
      prescriptions: prescriptions ?? this.prescriptions,
      recommendations: recommendations ?? this.recommendations,
      followUpInstructions: followUpInstructions ?? this.followUpInstructions,
      nextAppointmentDate: nextAppointmentDate ?? this.nextAppointmentDate,
      vitals: vitals ?? this.vitals,
      attachments: attachments ?? this.attachments,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Utility methods
  bool get isScheduled => status == 'scheduled';
  bool get isInProgress => status == 'in-progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isNoShow => status == 'no-show';

  bool get isUpcoming =>
      isScheduled && scheduledDateTime.isAfter(DateTime.now());
  bool get isPastDue =>
      isScheduled && scheduledDateTime.isBefore(DateTime.now());
  bool get isToday =>
      scheduledDateTime.day == DateTime.now().day &&
      scheduledDateTime.month == DateTime.now().month &&
      scheduledDateTime.year == DateTime.now().year;

  bool get isHighPriority => priority == 'urgent' || priority == 'emergency';
  bool get isEmergency => priority == 'emergency';

  String get formattedScheduledDate =>
      '${scheduledDateTime.day}/${scheduledDateTime.month}/${scheduledDateTime.year}';

  String get formattedScheduledTime =>
      '${scheduledDateTime.hour.toString().padLeft(2, '0')}:${scheduledDateTime.minute.toString().padLeft(2, '0')}';

  String get formattedScheduledDateTime =>
      '$formattedScheduledDate at $formattedScheduledTime';

  Duration? get actualDuration {
    if (actualStartTime != null && actualEndTime != null) {
      return actualEndTime!.difference(actualStartTime!);
    }
    return null;
  }

  String get statusDisplayText {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in-progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'no-show':
        return 'No Show';
      default:
        return 'Scheduled';
    }
  }

  String get typeDisplayText {
    switch (type) {
      case 'in-person':
        return 'In-Person';
      case 'telemedicine':
        return 'Telemedicine';
      case 'follow-up':
        return 'Follow-up';
      default:
        return 'In-Person';
    }
  }

  String get priorityDisplayText {
    switch (priority) {
      case 'routine':
        return 'Routine';
      case 'urgent':
        return 'Urgent';
      case 'emergency':
        return 'Emergency';
      default:
        return 'Routine';
    }
  }
}
