import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CHWMessageHelper {
  static Future<void> sendPatientMessageToId(
    String patientId,
    String appointmentId,
    String message,
  ) async {
    await FirebaseFirestore.instance.collection('messages').add({
      'to': patientId,
      'from': FirebaseAuth.instance.currentUser?.uid ?? '',
      'appointmentId': appointmentId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system',
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
