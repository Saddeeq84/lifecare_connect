import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletService {
  /// Credit a wallet for a specific user (provider/admin)
  static Future<void> creditWallet(String userId, double amount, {String? description, String type = 'credit'}) async {
    final walletRef = _firestore.collection('wallets').doc(userId);
    await _firestore.runTransaction((txn) async {
      final doc = await txn.get(walletRef);
      final prev = doc.exists && doc.data() != null ? (doc.data()!['balance'] ?? 0).toDouble() : 0.0;
      final newBalance = prev + amount;
      final tx = {
        'type': type,
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description ?? 'Wallet credited',
      };
      txn.set(walletRef, {
        'balance': newBalance,
        'currency': 'NGN',
        'updatedAt': FieldValue.serverTimestamp(),
        'transactions': FieldValue.arrayUnion([tx]),
      }, SetOptions(merge: true));
    });
  }
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get currentUserId => _auth.currentUser?.uid ?? '';

  static Future<double> getBalance({String? userId}) async {
    final uid = userId ?? currentUserId;
    final doc = await _firestore.collection('wallets').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return (doc.data()!['balance'] ?? 0).toDouble();
    }
    return 0.0;
  }

  static Future<void> fundWallet(double amount, {String? description}) async {
    final uid = currentUserId;
    final walletRef = _firestore.collection('wallets').doc(uid);
    await _firestore.runTransaction((txn) async {
      final doc = await txn.get(walletRef);
      final prev = doc.exists && doc.data() != null ? (doc.data()!['balance'] ?? 0).toDouble() : 0.0;
      final newBalance = prev + amount;
      final tx = {
        'type': 'fund',
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description ?? 'Funded via card',
      };
      txn.set(walletRef, {
        'balance': newBalance,
        'currency': 'NGN',
        'updatedAt': FieldValue.serverTimestamp(),
        'transactions': FieldValue.arrayUnion([tx]),
      }, SetOptions(merge: true));
    });
  }

  static Future<bool> deductWallet(double amount, {String? description}) async {
    final uid = currentUserId;
    final walletRef = _firestore.collection('wallets').doc(uid);
    return _firestore.runTransaction((txn) async {
      final doc = await txn.get(walletRef);
      final prev = doc.exists && doc.data() != null ? (doc.data()!['balance'] ?? 0).toDouble() : 0.0;
      if (prev < amount) return false;
      final newBalance = prev - amount;
      final tx = {
        'type': 'deduct',
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),
        'description': description ?? 'Appointment payment',
      };
      txn.set(walletRef, {
        'balance': newBalance,
        'currency': 'NGN',
        'updatedAt': FieldValue.serverTimestamp(),
        'transactions': FieldValue.arrayUnion([tx]),
      }, SetOptions(merge: true));
      return true;
    });
  }

  static Future<List<Map<String, dynamic>>> getTransactions({String? userId}) async {
    final uid = userId ?? currentUserId;
    final doc = await _firestore.collection('wallets').doc(uid).get();
    if (doc.exists && doc.data() != null && doc.data()!['transactions'] != null) {
      final txs = List<Map<String, dynamic>>.from(doc.data()!['transactions']);
      txs.sort((a, b) {
        final tA = a['timestamp'] as Timestamp?;
        final tB = b['timestamp'] as Timestamp?;
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tB.compareTo(tA);
      });
      return txs;
    }
    return [];
  }
}
