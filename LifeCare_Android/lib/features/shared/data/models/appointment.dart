import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String providerId;
  final String providerName;
  final String providerType; // 'CHW', 'DOCTOR', 'FACILITY'
  final DateTime appointmentDate;
  final String reason;
  final String? notes;
  final String
  status; // 'pending', 'approved', 'denied', 'completed', 'cancelled'
  final String? facilityId;
  final String? facilityName;
  final String appointmentType; // Type of appointment (General, ANC, etc.)
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? statusNotes;
  final String? rescheduleNotes;
  final String? cancellationReason;

  Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.providerId,
    required this.providerName,
    required this.providerType,
    required this.appointmentDate,
    required this.reason,
    this.notes,
    required this.status,
    this.facilityId,
    this.facilityName,
    required this.appointmentType,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.statusNotes,
    this.rescheduleNotes,
    this.cancellationReason,
  });

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Appointment(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      providerType: data['providerType'] ?? '',
      appointmentDate: (data['appointmentDate'] as Timestamp).toDate(),
      reason: data['reason'] ?? '',
      notes: data['notes'],
      status: data['status'] ?? 'pending',
      facilityId: data['facilityId'],
      facilityName: data['facilityName'],
      appointmentType: data['appointmentType'] ?? 'General Consultation',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      statusNotes: data['statusNotes'],
      rescheduleNotes: data['rescheduleNotes'],
      cancellationReason: data['cancellationReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'providerId': providerId,
      'providerName': providerName,
      'providerType': providerType,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'reason': reason,
      'notes': notes,
      'status': status,
      'facilityId': facilityId,
      'facilityName': facilityName,
      'appointmentType': appointmentType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'statusNotes': statusNotes,
      'rescheduleNotes': rescheduleNotes,
      'cancellationReason': cancellationReason,

      // Add role-specific fields for Firestore rules compatibility
      if (providerType == 'CHW') 'chwId': providerId,
      if (providerType == 'DOCTOR') 'doctorId': providerId,
      if (providerType == 'FACILITY') 'staffId': providerId,
    };
  }

  String get formattedDate {
    return '${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}';
  }

  String get formattedTime {
    return '${appointmentDate.hour.toString().padLeft(2, '0')}:${appointmentDate.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDateTime {
    return '$formattedDate at $formattedTime';
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get isPast => appointmentDate.isBefore(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;
  }

  Appointment copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? providerId,
    String? providerName,
    String? providerType,
    DateTime? appointmentDate,
    String? reason,
    String? notes,
    String? status,
    String? facilityId,
    String? facilityName,
    String? appointmentType,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? statusNotes,
    String? rescheduleNotes,
    String? cancellationReason,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      providerType: providerType ?? this.providerType,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      appointmentType: appointmentType ?? this.appointmentType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      statusNotes: statusNotes ?? this.statusNotes,
      rescheduleNotes: rescheduleNotes ?? this.rescheduleNotes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}
