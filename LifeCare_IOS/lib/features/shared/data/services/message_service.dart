// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';

class MessageService {
  /// Finds or creates a direct conversation between two users and returns the Conversation object
  static Future<Conversation?> findOrCreateConversation({
    required String userId,
    required String otherUserId,
    required String otherUserName,
  }) async {
    // Get current user info
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final otherUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUserId)
        .get();
    if (!userDoc.exists || !otherUserDoc.exists) return null;
    final userData = userDoc.data() as Map<String, dynamic>;
    final otherUserData = otherUserDoc.data() as Map<String, dynamic>;
    final userName = userData['name'] ?? 'You';
    final userRole = userData['role'] ?? 'patient';
    final otherUserRole = otherUserData['role'] ?? 'provider';
    // Use createOrGetConversation to get conversationId
    final conversationId = await createOrGetConversation(
      user1Id: userId,
      user1Name: userName,
      user1Role: userRole,
      user2Id: otherUserId,
      user2Name: otherUserName,
      user2Role: otherUserRole,
    );
    // Fetch the conversation object
    return await getConversationById(conversationId);
  }

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create or get existing conversation between two users
  static Future<String> createOrGetConversation({
    required String user1Id,
    required String user1Name,
    required String user1Role,
    required String user2Id,
    required String user2Name,
    required String user2Role,
    String? title,
    String type = 'direct',
    String? relatedId,
  }) async {
    try {
      // Create a consistent conversation ID based on participant IDs
      final participantIds = [user1Id, user2Id]..sort();
      final conversationId = '${participantIds[0]}_${participantIds[1]}';

      // Check if conversation already exists
      final existingConversation = await _firestore
          .collection('messages')
          .doc(conversationId)
          .get();

      if (existingConversation.exists) {
        return conversationId;
      }

      // Create new conversation
      final conversationData = {
        'participantIds': [user1Id, user2Id],
        'participants': [
          user1Id,
          user2Id,
        ], // Add this field for patient message screen compatibility
        'participantNames': {user1Id: user1Name, user2Id: user2Name},
        'participantRoles': {user1Id: user1Role, user2Id: user2Role},
        'title': title,
        'type': type,
        'recipientType': _getRecipientType(
          user1Role,
          user2Role,
        ), // Add recipientType field
        'relatedId': relatedId,
        'unreadCounts': {user1Id: 0, user2Id: 0},
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageTime':
            FieldValue.serverTimestamp(), // Add this for ordering
      };

      await _firestore
          .collection('messages')
          .doc(conversationId)
          .set(conversationData);

      return conversationId;
    } catch (e) {
      throw Exception('Failed to create conversation: $e');
    }
  }

  /// Send a message in a conversation
  static Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String receiverId,
    required String receiverName,
    required String receiverRole,
    required String content,
    String type = 'text',
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    String? replyToMessageId,
    String priority = 'normal',
    List<String>? participants,
  }) async {
    try {
      final messageData = {
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
        'isRead': false,
        'isDelivered': false,
        'status': 'sent',
        'replyToMessageId': replyToMessageId,
        'priority': priority,
        'createdAt': FieldValue.serverTimestamp(),
        'participants': ?participants,
      };

      // Add message to messages collection
      final messageRef = await _firestore
          .collection('messages')
          .add(messageData);

      // Update conversation with last message info
      await _firestore.collection('messages').doc(conversationId).update({
        'lastMessageId': messageRef.id,
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.$receiverId': FieldValue.increment(1),
      });

      return messageRef.id;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// Mark message as read
  static Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'isRead': true,
        'status': 'read',
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark message as read: $e');
    }
  }

  /// Mark all messages in conversation as read
  static Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // Get all unread messages for this user in this conversation
      final unreadMessages = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      // Mark all messages as read
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'status': 'read',
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      // Reset unread count for this user in conversation
      batch.update(_firestore.collection('messages').doc(conversationId), {
        'unreadCounts.$userId': 0,
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark conversation as read: $e');
    }
  }

  /// Get messages in a conversation
  static Stream<QuerySnapshot> getConversationMessages({
    required String conversationId,
    int? limit,
  }) {
    Query query = _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots();
  }

  /// Get conversations for a user
  static Stream<QuerySnapshot> getUserConversations({required String userId}) {
    return _firestore
        .collection('messages')
        .where('participantIds', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Search conversations by participant name
  static Future<List<Conversation>> searchConversations({
    required String userId,
    required String searchTerm,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('participantIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final conversations = snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .where((conversation) {
            final otherParticipantName = conversation.getOtherParticipantName(
              userId,
            );
            return otherParticipantName.toLowerCase().contains(
                  searchTerm.toLowerCase(),
                ) ||
                (conversation.title?.toLowerCase().contains(
                      searchTerm.toLowerCase(),
                    ) ??
                    false);
          })
          .toList();

      conversations.sort(
        (a, b) =>
            (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt),
      );

      return conversations;
    } catch (e) {
      throw Exception('Failed to search conversations: $e');
    }
  }

  /// Search users to start new conversation
  static Future<List<Map<String, dynamic>>> searchUsers({
    required String searchTerm,
    required String currentUserId,
    List<String>? roleFilter,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('isActive', isEqualTo: true);

      if (roleFilter != null && roleFilter.isNotEmpty) {
        query = query.where('role', whereIn: roleFilter);
      }

      final snapshot = await query.get();

      final users = snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final firstName = data['firstName'] ?? '';
            final lastName = data['lastName'] ?? '';
            final fullName = '$firstName $lastName';
            final role = data['role'] ?? '';

            return doc.id != currentUserId &&
                (fullName.toLowerCase().contains(searchTerm.toLowerCase()) ||
                    role.toLowerCase().contains(searchTerm.toLowerCase()));
          })
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                  .trim(),
              'role': data['role'] ?? '',
              'specialization': data['specialization'],
              'facilityName': data['facilityName'],
              'isOnline': data['isOnline'] ?? false,
              'lastSeen': data['lastSeen'],
            };
          })
          .toList();

      return users;
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  /// Delete message (soft delete)
  static Future<void> deleteMessage({
    required String messageId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'content': 'This message was deleted',
        'type': 'system',
        'status': 'deleted',
        'deletedBy': userId,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  /// Archive conversation
  static Future<void> archiveConversation({
    required String conversationId,
  }) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'isActive': false,
        'archivedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to archive conversation: $e');
    }
  }

  /// Clear all messages in a conversation
  static Future<void> clearConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      print(
        '🧹 Starting to clear conversation: $conversationId for user: $userId',
      );

      // Get all messages in the conversation from the messages collection
      final QuerySnapshot messagesSnapshot = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .get();

      print('🧹 Found ${messagesSnapshot.docs.length} messages to clear');

      if (messagesSnapshot.docs.isEmpty) {
        print('🧹 No messages found in conversation $conversationId');
        return;
      }

      // Delete all messages in a batch
      final WriteBatch batch = _firestore.batch();

      for (final QueryDocumentSnapshot doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {
          'content': 'This message was deleted',
          'isDeleted': true,
          'status': 'deleted',
          'deletedBy': userId,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update conversation metadata in the messages collection (conversation document)
      batch.update(_firestore.collection('messages').doc(conversationId), {
        'lastMessage': 'Chat cleared',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'clearedAt': FieldValue.serverTimestamp(),
        'clearedBy': userId,
      });

      await batch.commit();
      print(
        '🧹 Successfully cleared ${messagesSnapshot.docs.length} messages from conversation $conversationId',
      );
    } catch (e) {
      print('🧹 Error clearing conversation: $e');
      throw Exception('Failed to clear conversation: $e');
    }
  }

  /// Get unread message count for user
  static Future<int> getTotalUnreadCount({required String userId}) async {
    try {
      final snapshot = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();

      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final conversation = Conversation.fromFirestore(doc);
        totalUnread += conversation.getUnreadCount(userId);
      }

      return totalUnread;
    } catch (e) {
      throw Exception('Failed to get unread count: $e');
    }
  }

  /// Create system message (for notifications, status updates)
  static Future<String> createSystemMessage({
    required String conversationId,
    required String content,
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final messageData = {
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': 'System',
        'senderRole': 'SYSTEM',
        'receiverId': receiverId,
        'receiverName': '',
        'receiverRole': '',
        'content': content,
        'type': 'system',
        'isRead': false,
        'isDelivered': true,
        'status': 'delivered',
        'priority': 'normal',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final messageRef = await _firestore
          .collection('messages')
          .add(messageData);

      // Update conversation
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessageId': messageRef.id,
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return messageRef.id;
    } catch (e) {
      throw Exception('Failed to create system message: $e');
    }
  }

  /// Get conversation by ID
  static Future<Conversation?> getConversationById(
    String conversationId,
  ) async {
    try {
      final doc = await _firestore
          .collection('messages')
          .doc(conversationId)
          .get();

      if (doc.exists) {
        return Conversation.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get conversation: $e');
    }
  }

  /// Update user online status
  static Future<void> updateUserOnlineStatus({
    required String userId,
    required bool isOnline,
  }) async {
    try {
      final updateData = {
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(userId).update(updateData);
    } catch (e) {
      throw Exception('Failed to update online status: $e');
    }
  }

  /// Send message with consultation context
  static Future<String> sendConsultationMessage({
    required String consultationId,
    required String patientId,
    required String doctorId,
    required String senderId,
    required String content,
    String type = 'text',
  }) async {
    try {
      // Get user details
      final senderDoc = await _firestore
          .collection('users')
          .doc(senderId)
          .get();
      final senderData = senderDoc.data() as Map<String, dynamic>;
      final senderName = '${senderData['firstName']} ${senderData['lastName']}';
      final senderRole = senderData['role'];

      final receiverId = senderId == patientId ? doctorId : patientId;
      final receiverDoc = await _firestore
          .collection('users')
          .doc(receiverId)
          .get();
      final receiverData = receiverDoc.data() as Map<String, dynamic>;
      final receiverName =
          '${receiverData['firstName']} ${receiverData['lastName']}';
      final receiverRole = receiverData['role'];

      // Create or get consultation conversation
      final conversationId = await createOrGetConversation(
        user1Id: patientId,
        user1Name: receiverName,
        user1Role: receiverRole,
        user2Id: doctorId,
        user2Name: senderName,
        user2Role: senderRole,
        type: 'consultation',
        relatedId: consultationId,
        title: 'Consultation Chat',
      );

      // Send the message
      return await sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverRole: receiverRole,
        content: content,
        type: type,
      );
    } catch (e) {
      throw Exception('Failed to send consultation message: $e');
    }
  }

  /// Send notification when a patient books an appointment with a doctor
  static Future<void> notifyDoctorOfNewAppointment({
    required String appointmentId,
    required String doctorId,
    required String patientName,
    required DateTime appointmentDate,
    required String reason,
  }) async {
    try {
      // Get doctor details
      final doctorDoc = await _firestore
          .collection('users')
          .doc(doctorId)
          .get();

      if (!doctorDoc.exists) {
        print('❌ Doctor not found: $doctorId');
        return;
      }

      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final doctorName =
          '${doctorData['firstName'] ?? ''} ${doctorData['lastName'] ?? ''}'
              .trim();

      // Get patient details
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No current user found');
        return;
      }

      final patientDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final patientData = patientDoc.exists
          ? patientDoc.data() as Map<String, dynamic>
          : {};

      // Format appointment details
      final formattedDate =
          "${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}";
      final formattedTime =
          "${appointmentDate.hour.toString().padLeft(2, '0')}:${appointmentDate.minute.toString().padLeft(2, '0')}";

      // Create notification message
      String messageContent =
          "🩺 NEW APPOINTMENT REQUEST\n\n"
          "Hello Dr. $doctorName,\n\n"
          "You have received a new appointment request:\n\n"
          "👤 Patient: $patientName\n"
          "📅 Date: $formattedDate\n"
          "🕐 Time: $formattedTime\n"
          "📝 Reason: $reason\n\n"
          "Please review and approve/decline this appointment through your dashboard.\n\n"
          "Appointment ID: $appointmentId\n\n"
          "Best regards,\n"
          "LifeCare Connect Team";

      // Create or get conversation
      final conversationId = await createOrGetConversation(
        user1Id: currentUser.uid,
        user1Name: patientName,
        user1Role: patientData['role'] ?? 'patient',
        user2Id: doctorId,
        user2Name: doctorName,
        user2Role: 'doctor',
        title: 'Appointment Notification',
        type: 'appointment_notification',
        relatedId: appointmentId,
      );

      // Send notification message
      await sendMessage(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderName: patientName,
        senderRole: patientData['role'] ?? 'patient',
        receiverId: doctorId,
        receiverName: doctorName,
        receiverRole: 'doctor',
        content: messageContent,
        type: 'appointment_booking',
        priority: 'high',
      );

      print('✅ Doctor notification sent for appointment: $appointmentId');
    } catch (e) {
      print('❌ Error sending doctor notification: $e');
    }
  }

  /// Send notification when a CHW books an appointment with a doctor
  static Future<void> notifyDoctorOfCHWAppointment({
    required String appointmentId,
    required String doctorId,
    required String chwId,
    required String patientName,
    required DateTime appointmentDate,
    required String reason,
  }) async {
    try {
      // Get doctor details
      final doctorDoc = await _firestore
          .collection('users')
          .doc(doctorId)
          .get();

      if (!doctorDoc.exists) {
        print('❌ Doctor not found: $doctorId');
        return;
      }

      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final doctorName =
          '${doctorData['firstName'] ?? ''} ${doctorData['lastName'] ?? ''}'
              .trim();

      // Get CHW details
      final chwDoc = await _firestore.collection('users').doc(chwId).get();

      final chwData = chwDoc.exists
          ? chwDoc.data() as Map<String, dynamic>
          : {};
      final chwName =
          '${chwData['firstName'] ?? ''} ${chwData['lastName'] ?? ''}'.trim();

      // Format appointment details
      final formattedDate =
          "${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}";
      final formattedTime =
          "${appointmentDate.hour.toString().padLeft(2, '0')}:${appointmentDate.minute.toString().padLeft(2, '0')}";

      // Create notification message
      String messageContent =
          "🩺 NEW CHW APPOINTMENT REQUEST\n\n"
          "Hello Dr. $doctorName,\n\n"
          "A Community Health Worker has booked an appointment for a patient:\n\n"
          "👥 CHW: $chwName\n"
          "👤 Patient: $patientName\n"
          "📅 Date: $formattedDate\n"
          "🕐 Time: $formattedTime\n"
          "📝 Reason: $reason\n\n"
          "Please review and approve/decline this appointment through your dashboard.\n\n"
          "Appointment ID: $appointmentId\n\n"
          "Best regards,\n"
          "LifeCare Connect Team";

      // Create or get conversation
      final conversationId = await createOrGetConversation(
        user1Id: chwId,
        user1Name: chwName,
        user1Role: 'chw',
        user2Id: doctorId,
        user2Name: doctorName,
        user2Role: 'doctor',
        title: 'CHW Appointment Notification',
        type: 'chw_appointment_notification',
        relatedId: appointmentId,
      );

      // Send notification message
      await sendMessage(
        conversationId: conversationId,
        senderId: chwId,
        senderName: chwName,
        senderRole: 'chw',
        receiverId: doctorId,
        receiverName: doctorName,
        receiverRole: 'doctor',
        content: messageContent,
        type: 'chw_appointment_booking',
        priority: 'high',
      );

      print('✅ Doctor notification sent for CHW appointment: $appointmentId');
    } catch (e) {
      print('❌ Error sending CHW appointment notification: $e');
    }
  }

  /// Send notification when a patient books an appointment with a CHW
  static Future<void> notifyChwOfNewAppointment({
    required String appointmentId,
    required String chwId,
    required String patientName,
    required DateTime appointmentDate,
    required String reason,
  }) async {
    try {
      // Get CHW details
      final chwDoc = await _firestore.collection('users').doc(chwId).get();

      if (!chwDoc.exists) {
        print('❌ CHW not found: $chwId');
        return;
      }

      final chwData = chwDoc.data() as Map<String, dynamic>;
      final chwName =
          '${chwData['firstName'] ?? ''} ${chwData['lastName'] ?? ''}'.trim();

      // Get patient details
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No current user found');
        return;
      }

      final patientDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final patientData = patientDoc.exists
          ? patientDoc.data() as Map<String, dynamic>
          : {};

      // Format appointment details
      final formattedDate =
          "${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}";
      final formattedTime =
          "${appointmentDate.hour.toString().padLeft(2, '0')}:${appointmentDate.minute.toString().padLeft(2, '0')}";

      // Create notification message
      String messageContent =
          "👩‍⚕️ NEW APPOINTMENT REQUEST\n\n"
          "Hello $chwName,\n\n"
          "You have received a new appointment request:\n\n"
          "👤 Patient: $patientName\n"
          "📅 Date: $formattedDate\n"
          "🕐 Time: $formattedTime\n"
          "📝 Reason: $reason\n\n"
          "Please review and approve/decline this appointment through your dashboard.\n\n"
          "Appointment ID: $appointmentId\n\n"
          "Best regards,\n"
          "LifeCare Connect Team";

      // Create or get conversation
      final conversationId = await createOrGetConversation(
        user1Id: currentUser.uid,
        user1Name: patientName,
        user1Role: patientData['role'] ?? 'patient',
        user2Id: chwId,
        user2Name: chwName,
        user2Role: 'chw',
        title: 'Appointment Notification',
        type: 'appointment_notification',
        relatedId: appointmentId,
      );

      // Send notification message
      await sendMessage(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderName: patientName,
        senderRole: patientData['role'] ?? 'patient',
        receiverId: chwId,
        receiverName: chwName,
        receiverRole: 'chw',
        content: messageContent,
        type: 'appointment_booking',
        priority: 'high',
      );

      print('✅ CHW notification sent for appointment: $appointmentId');
    } catch (e) {
      print('❌ Error sending CHW notification: $e');
    }
  }

  /// Send notification when a doctor makes a referral
  static Future<void> notifyDoctorOfReferral({
    required String referralId,
    required String referringDoctorId,
    required String referredDoctorId,
    required String patientName,
    required String reason,
    required String specialty,
  }) async {
    try {
      // Get referring doctor details
      final referringDoctorDoc = await _firestore
          .collection('users')
          .doc(referringDoctorId)
          .get();

      final referringDoctorData = referringDoctorDoc.exists
          ? referringDoctorDoc.data() as Map<String, dynamic>
          : {};
      final referringDoctorName =
          '${referringDoctorData['firstName'] ?? ''} ${referringDoctorData['lastName'] ?? ''}'
              .trim();

      // Get referred doctor details
      final referredDoctorDoc = await _firestore
          .collection('users')
          .doc(referredDoctorId)
          .get();

      if (!referredDoctorDoc.exists) {
        print('❌ Referred doctor not found: $referredDoctorId');
        return;
      }

      final referredDoctorData =
          referredDoctorDoc.data() as Map<String, dynamic>;
      final referredDoctorName =
          '${referredDoctorData['firstName'] ?? ''} ${referredDoctorData['lastName'] ?? ''}'
              .trim();

      // Create notification message
      String messageContent =
          "🔄 NEW PATIENT REFERRAL\n\n"
          "Hello Dr. $referredDoctorName,\n\n"
          "You have received a new patient referral:\n\n"
          "👤 Patient: $patientName\n"
          "👨‍⚕️ Referring Doctor: Dr. $referringDoctorName\n"
          "🏥 Specialty: $specialty\n"
          "📝 Referral Reason: $reason\n\n"
          "Please review this referral and accept/decline through your dashboard.\n\n"
          "Referral ID: $referralId\n\n"
          "Best regards,\n"
          "LifeCare Connect Team";

      // Create or get conversation
      final conversationId = await createOrGetConversation(
        user1Id: referringDoctorId,
        user1Name: referringDoctorName,
        user1Role: 'doctor',
        user2Id: referredDoctorId,
        user2Name: referredDoctorName,
        user2Role: 'doctor',
        title: 'Patient Referral Notification',
        type: 'referral_notification',
        relatedId: referralId,
      );

      // Send notification message
      await sendMessage(
        conversationId: conversationId,
        senderId: referringDoctorId,
        senderName: referringDoctorName,
        senderRole: 'doctor',
        receiverId: referredDoctorId,
        receiverName: referredDoctorName,
        receiverRole: 'doctor',
        content: messageContent,
        type: 'referral_notification',
        priority: 'high',
      );

      print('✅ Referral notification sent: $referralId');
    } catch (e) {
      print('❌ Error sending referral notification: $e');
    }
  }

  /// Send notification when a CHW makes a referral
  static Future<void> notifyDoctorOfChwReferral({
    required String referralId,
    required String chwId,
    required String doctorId,
    required String patientName,
    required String reason,
    required String urgency,
  }) async {
    try {
      // Get CHW details
      final chwDoc = await _firestore.collection('users').doc(chwId).get();

      final chwData = chwDoc.exists
          ? chwDoc.data() as Map<String, dynamic>
          : {};
      final chwName =
          '${chwData['firstName'] ?? ''} ${chwData['lastName'] ?? ''}'.trim();

      // Get doctor details
      final doctorDoc = await _firestore
          .collection('users')
          .doc(doctorId)
          .get();

      if (!doctorDoc.exists) {
        print('❌ Doctor not found: $doctorId');
        return;
      }

      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final doctorName =
          '${doctorData['firstName'] ?? ''} ${doctorData['lastName'] ?? ''}'
              .trim();

      // Create notification message
      String messageContent =
          "🔄 NEW CHW REFERRAL\n\n"
          "Hello Dr. $doctorName,\n\n"
          "You have received a new patient referral from a Community Health Worker:\n\n"
          "👤 Patient: $patientName\n"
          "👩‍⚕️ CHW: $chwName\n"
          "📝 Referral Reason: $reason\n"
          "⚠️ Urgency: $urgency\n\n"
          "Please review this referral and accept/decline through your dashboard.\n\n"
          "Referral ID: $referralId\n\n"
          "Best regards,\n"
          "LifeCare Connect Team";

      // Use a system/admin sender so CHW does not see the message
      const String systemSenderId = 'system';
      const String systemSenderName = 'LifeCare System';
      const String systemSenderRole = 'system';

      // Create or get a system-to-doctor conversation
      final conversationId = await createOrGetConversation(
        user1Id: systemSenderId,
        user1Name: systemSenderName,
        user1Role: systemSenderRole,
        user2Id: doctorId,
        user2Name: doctorName,
        user2Role: 'doctor',
        title: 'CHW Referral Notification',
        type: 'chw_referral_notification',
        relatedId: referralId,
      );

      // Send notification message (from system to doctor only)
      await sendMessage(
        conversationId: conversationId,
        senderId: systemSenderId,
        senderName: systemSenderName,
        senderRole: systemSenderRole,
        receiverId: doctorId,
        receiverName: doctorName,
        receiverRole: 'doctor',
        content: messageContent,
        type: 'chw_referral_notification',
        priority: 'high',
      );

      print('✅ CHW referral notification sent: $referralId');
    } catch (e) {
      print('❌ Error sending CHW referral notification: $e');
    }
  }

  /// Helper method to determine recipient type based on roles
  static String _getRecipientType(String user1Role, String user2Role) {
    // Return the non-patient role as the recipient type
    if (user1Role == 'patient') {
      return user2Role;
    } else if (user2Role == 'patient') {
      return user1Role;
    } else {
      // If neither is patient, return the second user's role
      return user2Role;
    }
  }
}
