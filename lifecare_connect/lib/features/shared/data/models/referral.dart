import 'package:cloud_firestore/cloud_firestore.dart';

class Referral {
  /// Returns a map with the 'to' provider's details for use in booking pre-selection.
  Map<String, dynamic> toProviderMap() {
    return {
      'id': toProviderId,
      'name': toProviderName,
      'type': toProviderType,
      if (facilityId != null) 'facilityId': facilityId,
      if (facilityName != null) 'facilityName': facilityName,
    };
  }
  final String id;
  final String patientId;
  final String patientName;
  final String fromProviderId;
  final String fromProviderName;
  final String fromProviderType; // 'CHW', 'DOCTOR', 'FACILITY'
  final String toProviderId;
  final String toProviderName;
  final String toProviderType; // 'DOCTOR', 'FACILITY', 'SPECIALIST'
  final String reason;
  final String urgency; // 'low', 'medium', 'high', 'critical'
  final String status; // 'pending', 'approved', 'rejected', 'completed'
  final String? notes;
  final String? facilityId;
  final String? facilityName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? actionDate;
  final String? actionBy;
  final String? actionNotes;
  final Map<String, dynamic>? medicalHistory;
  final List<String>? attachments;

  const Referral({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.fromProviderId,
    required this.fromProviderName,
    required this.fromProviderType,
    required this.toProviderId,
    required this.toProviderName,
    required this.toProviderType,
    required this.reason,
    required this.urgency,
    required this.status,
    this.notes,
    this.facilityId,
    this.facilityName,
    required this.createdAt,
    this.updatedAt,
    this.actionDate,
    this.actionBy,
    this.actionNotes,
    this.medicalHistory,
    this.attachments,
  });

  factory Referral.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Referral(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      fromProviderId: data['fromProviderId'] ?? '',
      fromProviderName: data['fromProviderName'] ?? '',
      fromProviderType: data['fromProviderType'] ?? '',
      toProviderId: data['toProviderId'] ?? '',
      toProviderName: data['toProviderName'] ?? '',
      toProviderType: data['toProviderType'] ?? '',
      reason: data['reason'] ?? '',
      urgency: data['urgency'] ?? 'medium',
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      facilityId: data['facilityId'],
      facilityName: data['facilityName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      actionDate: (data['actionDate'] as Timestamp?)?.toDate(),
      actionBy: data['actionBy'],
      actionNotes: data['actionNotes'],
      medicalHistory: data['medicalHistory'] as Map<String, dynamic>?,
      attachments: data['attachments'] != null
          ? List<String>.from(data['attachments'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'fromProviderId': fromProviderId,
      'fromProviderName': fromProviderName,
      'fromProviderType': fromProviderType,
      'toProviderId': toProviderId,
      'toProviderName': toProviderName,
      'toProviderType': toProviderType,
      'reason': reason,
      'urgency': urgency,
      'status': status,
      'notes': notes,
      'facilityId': facilityId,
      'facilityName': facilityName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'actionDate': actionDate != null ? Timestamp.fromDate(actionDate!) : null,
      'actionBy': actionBy,
      'actionNotes': actionNotes,
      'medicalHistory': medicalHistory,
      'attachments': attachments,
    };
  }

  Referral copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? fromProviderId,
    String? fromProviderName,
    String? fromProviderType,
    String? toProviderId,
    String? toProviderName,
    String? toProviderType,
    String? reason,
    String? urgency,
    String? status,
    String? notes,
    String? facilityId,
    String? facilityName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? actionDate,
    String? actionBy,
    String? actionNotes,
    Map<String, dynamic>? medicalHistory,
    List<String>? attachments,
  }) {
    return Referral(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      fromProviderId: fromProviderId ?? this.fromProviderId,
      fromProviderName: fromProviderName ?? this.fromProviderName,
      fromProviderType: fromProviderType ?? this.fromProviderType,
      toProviderId: toProviderId ?? this.toProviderId,
      toProviderName: toProviderName ?? this.toProviderName,
      toProviderType: toProviderType ?? this.toProviderType,
      reason: reason ?? this.reason,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      actionDate: actionDate ?? this.actionDate,
      actionBy: actionBy ?? this.actionBy,
      actionNotes: actionNotes ?? this.actionNotes,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      attachments: attachments ?? this.attachments,
    );
  }

  // Utility methods
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCompleted => status == 'completed';

  bool get isHighPriority => urgency == 'high' || urgency == 'critical';
  bool get isCritical => urgency == 'critical';

  String get formattedCreatedDate =>
      '${createdAt.day}/${createdAt.month}/${createdAt.year}';

  String get formattedCreatedTime =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  String get urgencyDisplayText {
    switch (urgency) {
      case 'low':
        return 'Low Priority';
      case 'medium':
        return 'Medium Priority';
      case 'high':
        return 'High Priority';
      case 'critical':
        return 'Critical';
      default:
        return 'Medium Priority';
    }
  }

  String get statusDisplayText {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending Review';
    }
  }
}
