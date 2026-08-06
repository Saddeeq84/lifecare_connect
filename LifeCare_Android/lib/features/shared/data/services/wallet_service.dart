import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Get user ID from Firebase Auth or SharedPreferences (for Termii login)
  static Future<String> getCurrentUserId() async {
    // First try Firebase Auth
    final firebaseUserId = _auth.currentUser?.uid;
    if (firebaseUserId != null && firebaseUserId.isNotEmpty) {
      return firebaseUserId;
    }

    // Then try SharedPreferences (for Termii OTP login)
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      return userId ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Safely convert any Firestore value to double for wallet balances
  static double safeDouble(dynamic value) {
    if (value is int || value is double) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Credit a wallet for a specific user (provider/admin)
  static Future<void> creditWallet(
    String userId,
    double amount, {
    String? description,
    String type = 'credit',
  }) async {
    if (userId.isEmpty) {
      throw Exception('UserId cannot be empty for creditWallet');
    }

    if (amount <= 0) {
      throw Exception('Amount must be positive for creditWallet');
    }

    final walletRef = _firestore.collection('wallets').doc(userId);

    try {
      // Ensure wallet doc exists before transaction
      final doc = await walletRef.get();

      if (!doc.exists || doc.data() == null) {
        await walletRef.set({
          'balance': 0.0,
          'currency': 'NGN',
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': [],
        });
      }

      await _firestore.runTransaction((txn) async {
        final doc = await txn.get(walletRef);
        double prev = 0.0;
        if (doc.exists && doc.data() != null) {
          final bal = doc.data()!['balance'];
          if (bal is! int && bal is! double && bal is! String) {
            await walletRef.update({'balance': 0.0});
            throw Exception('Corrupted wallet balance. Please try again.');
          }
          prev = safeDouble(bal);
        }
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

      // Also save to wallet_transactions collection for better querying
      await _firestore.collection('wallet_transactions').add({
        'walletId': userId,
        'type': 'credit',
        'amount': amount,
        'description': description ?? 'Wallet credited',
        'reference': 'CREDIT_${DateTime.now().millisecondsSinceEpoch}',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  static Future<double> getBalance({String? userId}) async {
    final uid = userId ?? currentUserId;
    print('💳 Getting balance for user ID: $uid');
    final doc = await _firestore.collection('wallets').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final balance = safeDouble(doc.data()!['balance']);
      print('💳 Wallet document found. Balance: ₦$balance');
      return balance;
    }
    print('❌ No wallet document found for user: $uid');
    return 0.0;
  }

  static Future<void> fundWallet(double amount, {String? description}) async {
    final uid = await getCurrentUserId();
    if (uid.isEmpty) {
      throw Exception('User not logged in. Cannot fund wallet.');
    }
    final walletRef = _firestore.collection('wallets').doc(uid);
    try {
      // Ensure wallet doc exists before transaction
      final doc = await walletRef.get();
      if (!doc.exists || doc.data() == null) {
        await walletRef.set({
          'balance': 0.0,
          'currency': 'NGN',
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': [],
        });
      }
      await _firestore.runTransaction((txn) async {
        final doc = await txn.get(walletRef);
        double prev = 0.0;
        if (doc.exists && doc.data() != null) {
          final bal = doc.data()!['balance'];
          prev = safeDouble(bal);
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
      });

      // Also save to wallet_transactions collection for better querying
      await _firestore.collection('wallet_transactions').add({
        'walletId': uid,
        'type': 'credit',
        'amount': amount,
        'description': description ?? 'Funded via card',
        'reference': 'FUND_${DateTime.now().millisecondsSinceEpoch}',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Fallback: try to create or update the wallet doc directly if transaction fails
      try {
        final doc = await walletRef.get();
        double prev = 0.0;
        List<dynamic> prevTxs = [];
        if (doc.exists && doc.data() != null) {
          final bal = doc.data()!['balance'];
          prev = safeDouble(bal);
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

        // Also save to wallet_transactions collection
        await _firestore.collection('wallet_transactions').add({
          'walletId': uid,
          'type': 'credit',
          'amount': amount,
          'description': description ?? 'Funded via card',
          'reference': 'FUND_${DateTime.now().millisecondsSinceEpoch}',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e2) {
        rethrow;
      }
    }
  }

  static Future<bool> deductWallet(double amount, {String? description}) async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw Exception('User not logged in. Cannot deduct from wallet.');
    }
    final walletRef = _firestore.collection('wallets').doc(uid);
    try {
      await _firestore.runTransaction((txn) async {
        final doc = await txn.get(walletRef);
        final data = doc.data();
        double prev = 0.0;
        if (doc.exists && data != null) {
          final bal = data['balance'];
          if (bal is! int && bal is! double && bal is! String) {
            await walletRef.update({'balance': 0.0});
            throw Exception('Corrupted wallet balance. Please try again.');
          }
          prev = safeDouble(bal);
          // Defensive: check transactions field
          if (data.containsKey('transactions')) {
            if (data['transactions'] == null) {
            } else if (data['transactions'] is! List) {}
          }
        }
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
      });

      // Also save to wallet_transactions collection for better querying
      await _firestore.collection('wallet_transactions').add({
        'walletId': uid,
        'type': 'debit',
        'amount': amount,
        'description': description ?? 'Appointment payment',
        'reference': 'DEBIT_${DateTime.now().millisecondsSinceEpoch}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      if (e.toString().contains('Insufficient funds')) {
        return false;
      }
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getTransactions({
    String? userId,
  }) async {
    final uid = userId ?? currentUserId;

    // First, try to get transactions from the wallet's transactions subcollection
    try {
      final querySnapshot = await _firestore
          .collection('wallets')
          .doc(uid)
          .collection('transactions')
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final transactions = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'type': data['type'] ?? 'credit',
            'amount': data['amount'] ?? 0.0,
            'description': data['description'] ?? data['type'] ?? 'Transaction',
            'timestamp': data['timestamp'] ?? data['createdAt'],
          };
        }).toList();

        // Sort by timestamp manually
        transactions.sort((a, b) {
          final tsA = a['timestamp'];
          final tsB = b['timestamp'];
          if (tsA is Timestamp && tsB is Timestamp) {
            return tsB.compareTo(tsA);
          }
          return 0;
        });

        return transactions;
      }
    } catch (e) {
      // If subcollection query fails, fall back to wallet document array
    }

    // Fallback: try to get transactions from wallet document (legacy)
    final doc = await _firestore.collection('wallets').doc(uid).get();
    if (doc.exists &&
        doc.data() != null &&
        doc.data()!['transactions'] != null) {
      final rawTxs = doc.data()!['transactions'];
      List<Map<String, dynamic>> txs = [];
      if (rawTxs is List) {
        for (var tx in rawTxs) {
          if (tx is Map) {
            // Defensive: ensure all keys are String and values are dynamic
            final safeTx = <String, dynamic>{};
            tx.forEach((key, value) {
              if (key is String) safeTx[key] = value;
            });
            // Extra: skip if timestamp is missing or not Timestamp/DateTime/String
            final ts = safeTx['timestamp'];
            if (ts is Timestamp ||
                ts is DateTime ||
                (ts is String && DateTime.tryParse(ts) != null)) {
              txs.add(safeTx);
            } else {}
          } else {}
        }
      } else {}
      // Sort by timestamp if possible
      txs.sort((a, b) {
        final tA = a['timestamp'];
        final tB = b['timestamp'];
        Timestamp? tsA;
        Timestamp? tsB;
        if (tA is Timestamp) {
          tsA = tA;
        } else if (tA is DateTime)
          tsA = Timestamp.fromDate(tA);
        else if (tA is String) {
          try {
            tsA = Timestamp.fromDate(DateTime.parse(tA));
          } catch (_) {}
        }
        if (tB is Timestamp) {
          tsB = tB;
        } else if (tB is DateTime)
          tsB = Timestamp.fromDate(tB);
        else if (tB is String) {
          try {
            tsB = Timestamp.fromDate(DateTime.parse(tB));
          } catch (_) {}
        }
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });
      return txs;
    }
    return [];
  }
}
