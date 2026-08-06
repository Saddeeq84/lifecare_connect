import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CHWMessageHelper {
  static Future<void> sendPatientMessageToId(
    String patientId,
    String appointmentId,
    String message,
  ) async {
    final senderId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Get CHW name
    String senderName = 'Community Health Worker';
    try {
      final chwDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      if (chwDoc.exists) {
        final chwData = chwDoc.data() as Map<String, dynamic>;
        senderName = chwData['name'] ?? 'Community Health Worker';
      }
    } catch (e) {}

    // Get patient name
    String patientName = 'Patient';
    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();
      if (patientDoc.exists) {
        final patientData = patientDoc.data() as Map<String, dynamic>;
        patientName = patientData['name'] ?? 'Patient';
      }
    } catch (e) {}

    await FirebaseFirestore.instance.collection('messages').add({
      'conversationId': patientId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': 'chw',
      'receiverId': patientId,
      'receiverName': patientName,
      'receiverRole': 'patient',
      'content': message,
      'type': 'appointment_notification',
      'priority': 'high',
      'read': false,
      'appointmentId': appointmentId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendReferralMessageToPatient(
    String patientId,
    String referralDetails,
  ) async {
    final senderId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final messageText = 'You have been referred: $referralDetails';
    await FirebaseFirestore.instance.collection('messages').add({
      'participants': [patientId, senderId],
      'recipientType': 'doctor', // or 'chw' if the sender is a CHW
      'lastMessage': messageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_$patientId': 1,
      'unreadCount_$senderId': 0,
      'from': senderId,
      'to': patientId,
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'referral',
    });
  }

  static Future<void> sendHealthRecordUpdateToPatient(
    String patientId,
    String updateType,
    String details,
  ) async {
    await FirebaseFirestore.instance.collection('messages').add({
      'to': patientId,
      'from': FirebaseAuth.instance.currentUser?.uid ?? '',
      'message': 'New $updateType added: $details',
      'timestamp': FieldValue.serverTimestamp(),
      'type': updateType,
    });
  }
}
