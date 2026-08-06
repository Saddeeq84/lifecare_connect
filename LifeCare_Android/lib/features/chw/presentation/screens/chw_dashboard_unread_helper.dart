import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> getCHWHasUnreadMessages() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: user.uid)
        .where('isActive', isEqualTo: true)
        .get();
    int totalUnread = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final unread = data['unreadCount_${user.uid}'] ?? 0;
      if (unread is int && unread > 0) {
        totalUnread += unread;
      }
    }
    return totalUnread > 0;
  } catch (e) {
    return false;
  }
}
