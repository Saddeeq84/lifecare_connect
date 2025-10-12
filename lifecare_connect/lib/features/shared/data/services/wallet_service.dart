import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletService {
  /// Credit a wallet for a specific user (provider/admin)
  static Future<void> creditWallet(String userId, double amount, {String? description, String type = 'credit'}) async {
    print('[WalletService] creditWallet called for userId: $userId, amount: $amount, type: $type, description: $description');
    final walletRef = _firestore.collection('wallets').doc(userId);
    try {
      // Ensure wallet doc exists before transaction
      final doc = await walletRef.get();
      if (!doc.exists) {
        print('[WalletService] Wallet doc does not exist for $userId. Creating new wallet doc.');
        await walletRef.set({
          'balance': 0.0,
          'currency': 'NGN',
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': [],
        });
      }
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
        print('[WalletService] Crediting wallet for $userId. Previous balance: $prev, New balance: $newBalance');
        txn.set(walletRef, {
          'balance': newBalance,
          'currency': 'NGN',
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': FieldValue.arrayUnion([tx]),
        }, SetOptions(merge: true));
        // No return statement here
      });
      print('[WalletService] creditWallet succeeded for $userId');
    } catch (e, st) {
      print('[WalletService] ERROR in creditWallet for $userId: $e\n$st');
      rethrow;
    }
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
    print('[WalletService] fundWallet called. currentUserId: $uid');
    if (uid.isEmpty) {
      print('[WalletService] ERROR: currentUserId is empty. User must be logged in.');
      throw Exception('User not logged in. Cannot fund wallet.');
    }
    final walletRef = _firestore.collection('wallets').doc(uid);
    try {
      await _firestore.runTransaction((txn) async {
        final doc = await txn.get(walletRef);
        print('[WalletService] wallet doc exists: \\${doc.exists}, data: \\${doc.data()}');
        double prev = 0.0;
        if (doc.exists && doc.data() != null) {
          final bal = doc.data()!['balance'];
          if (bal is num) {
            prev = bal.toDouble();
          } else {
            print('[WalletService] WARNING: balance field is not a number.');
          }
        }
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
        // No return statement here
      });
    } catch (e, st) {
      print('[WalletService] ERROR in fundWallet transaction: $e\\n$st');
      // Fallback: try to create or update the wallet doc directly if transaction fails
      try {
        print('[WalletService] Attempting fallback wallet doc creation...');
        final doc = await walletRef.get();
        double prev = 0.0;
        List<dynamic> prevTxs = [];
        if (doc.exists && doc.data() != null) {
          final bal = doc.data()!['balance'];
          if (bal is num) {
            prev = bal.toDouble();
          }
          if (doc.data()!['transactions'] is List) {
            prevTxs = List.from(doc.data()!['transactions']);
          }
        }
        final newBalance = prev + amount;
        final tx = {
          'type': 'fund',
          'amount': amount,
          'timestamp': DateTime.now().toUtc(),
          'description': description ?? 'Funded via card',
        };
        await walletRef.set({
          'balance': newBalance,
          'currency': 'NGN',
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': [...prevTxs, tx],
        }, SetOptions(merge: true));
        print('[WalletService] Fallback wallet doc creation succeeded.');
      } catch (e2, st2) {
        print('[WalletService] Fallback wallet doc creation failed: $e2\\n$st2');
        rethrow;
      }
    }
  }

  static Future<bool> deductWallet(double amount, {String? description}) async {
    final uid = currentUserId;
    print('[WalletService] deductWallet called. currentUserId: $uid, amount: $amount, description: $description');
    if (uid.isEmpty) {
      print('[WalletService] ERROR: currentUserId is empty. User must be logged in.');
      throw Exception('User not logged in. Cannot deduct from wallet.');
    }
    final walletRef = _firestore.collection('wallets').doc(uid);
    try {
      await _firestore.runTransaction((txn) async {
        final doc = await txn.get(walletRef);
        final prev = doc.exists && doc.data() != null ? (doc.data()!['balance'] ?? 0).toDouble() : 0.0;
        print('[WalletService] deductWallet Firestore doc exists: \\${doc.exists}, prev balance: \\${prev}');
        if (prev < amount) {
          throw Exception('Insufficient funds');
        }
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
        print('[WalletService] deductWallet transaction succeeded. New balance: \\${newBalance}');
        // No return statement here
      });
      print('[WalletService] deductWallet transaction completed. Success: true');
      return true;
    } catch (e, st) {
      print('[WalletService] ERROR in deductWallet transaction: $e\n$st');
      if (e.toString().contains('Insufficient funds')) {
        return false;
      }
      rethrow;
    }
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
