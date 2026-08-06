// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'CHW', 'DOCTOR', 'PATIENT', 'FACILITY'
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String content;
  final String type; // 'text', 'image', 'document', 'voice', 'system'
  final String? attachmentUrl;
  final String? attachmentType; // 'image/jpeg', 'application/pdf', etc.
  final String? attachmentName;
  final bool isRead;
  final bool isDelivered;
  final String status; // 'sent', 'delivered', 'read', 'failed'
  final String? replyToMessageId;
  final String? priority; // 'low', 'normal', 'high', 'urgent'
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  final Map<String, dynamic>? metadata;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.receiverId,
    required this.receiverName,
    required this.receiverRole,
    required this.content,
    required this.type,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    required this.isRead,
    required this.isDelivered,
    required this.status,
    this.replyToMessageId,
    this.priority,
    required this.createdAt,
    this.readAt,
    this.deliveredAt,
    this.metadata,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverRole: data['receiverRole'] ?? '',
      content: data['content'] ?? '',
      type: data['type'] ?? 'text',
      attachmentUrl: data['attachmentUrl'],
      attachmentType: data['attachmentType'],
      attachmentName: data['attachmentName'],
      isRead: data['isRead'] ?? false,
      isDelivered: data['isDelivered'] ?? false,
      status: data['status'] ?? 'sent',
      replyToMessageId: data['replyToMessageId'],
      priority: data['priority'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverRole': receiverRole,
      'content': content,
      'type': type,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'attachmentName': attachmentName,
      'isRead': isRead,
      'isDelivered': isDelivered,
      'status': status,
      'replyToMessageId': replyToMessageId,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
      'metadata': metadata,
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? receiverId,
    String? receiverName,
    String? receiverRole,
    String? content,
    String? type,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    bool? isRead,
    bool? isDelivered,
    String? status,
    String? replyToMessageId,
    String? priority,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? deliveredAt,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverRole: receiverRole ?? this.receiverRole,
      content: content ?? this.content,
      type: type ?? this.type,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentName: attachmentName ?? this.attachmentName,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      status: status ?? this.status,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Utility methods
  bool get isSent => status == 'sent';
  bool get isFailedToSend => status == 'failed';
  bool get hasAttachment => attachmentUrl?.isNotEmpty == true;
  bool get isSystemMessage => type == 'system';
  bool get isTextMessage => type == 'text';
  bool get isImageMessage => type == 'image';
  bool get isDocumentMessage => type == 'document';
  bool get isVoiceMessage => type == 'voice';
  bool get isHighPriority => priority == 'high' || priority == 'urgent';
  bool get isReply => replyToMessageId?.isNotEmpty == true;

  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    if (messageDate == today) {
      return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  String get statusDisplayText {
    switch (status) {
      case 'sent':
        return 'Sent';
      case 'delivered':
        return 'Delivered';
      case 'read':
        return 'Read';
      case 'failed':
        return 'Failed';
      default:
        return 'Sent';
    }
  }
}

// Conversation model for managing chat threads
class Conversation {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String> participantRoles;
  final String? title;
  final String type; // 'direct', 'group', 'consultation', 'referral'
  final String? relatedId; // consultationId, referralId, etc.
  final String? lastMessageId;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSenderId;
  final Map<String, int> unreadCounts; // userId -> unread count
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const Conversation({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantRoles,
    this.title,
    required this.type,
    this.relatedId,
    this.lastMessageId,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    required this.unreadCounts,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: Map<String, String>.from(
        data['participantNames'] ?? {},
      ),
      participantRoles: Map<String, String>.from(
        data['participantRoles'] ?? {},
      ),
      title: data['title'],
      type: data['type'] ?? 'direct',
      relatedId: data['relatedId'],
      lastMessageId: data['lastMessageId'],
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastSenderId: data['lastSenderId'],
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participantIds': participantIds,
      'participantNames': participantNames,
      'participantRoles': participantRoles,
      'title': title,
      'type': type,
      'relatedId': relatedId,
      'lastMessageId': lastMessageId,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastSenderId': lastSenderId,
      'unreadCounts': unreadCounts,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
    };
  }

  // Utility methods
  int getUnreadCount(String userId) => unreadCounts[userId] ?? 0;
  bool hasUnreadMessages(String userId) => getUnreadCount(userId) > 0;

  String getOtherParticipantName(String currentUserId) {
    final otherParticipants = participantIds
        .where((id) => id != currentUserId)
        .toList();
    if (otherParticipants.isNotEmpty) {
      return participantNames[otherParticipants.first] ?? 'Unknown';
    }
    return 'Unknown';
  }

  String getOtherParticipantRole(String currentUserId) {
    final otherParticipants = participantIds
        .where((id) => id != currentUserId)
        .toList();
    if (otherParticipants.isNotEmpty) {
      return participantRoles[otherParticipants.first] ?? 'USER';
    }
    return 'USER';
  }

  String get displayTitle {
    if (title?.isNotEmpty == true) return title!;
    if (type == 'group') return 'Group Chat';
    if (type == 'consultation') return 'Consultation Chat';
    if (type == 'referral') return 'Referral Chat';
    return 'Chat';
  }
}
