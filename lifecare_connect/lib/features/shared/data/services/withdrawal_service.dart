import 'package:cloud_firestore/cloud_firestore.dart';

class WithdrawalService {
  static final _firestore = FirebaseFirestore.instance;

  /// Request a withdrawal for a user (provider/admin)
  static Future<void> requestWithdrawal({
    required String userId,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? role, // doctor, chw, admin
  }) async {
    final withdrawalRef = _firestore.collection('withdrawals').doc();
    final isAdmin = role == 'admin';
    await withdrawalRef.set({
      'userId': userId,
      'amount': amount,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'role': role,
      'status': isAdmin ? 'approved' : 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      if (isAdmin) 'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get withdrawal requests for a user
  static Future<List<Map<String, dynamic>>> getWithdrawals(String userId) async {
    final query = await _firestore
        .collection('withdrawals')
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }
}
