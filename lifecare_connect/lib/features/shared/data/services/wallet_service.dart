import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get currentUserId => _auth.currentUser?.uid ?? '';

  /// Safely convert any Firestore value to double for wallet balances
  static double safeDouble(dynamic value) {
    if (value is int || value is double) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    print('[WalletService] ERROR: Unexpected balance type: [33m[1m[0m${value.runtimeType}, value: $value. Defaulting to 0.0');
    return 0.0;
  }

  /// Credit a wallet for a specific user (provider/admin)
  static Future<void> creditWallet(String userId, double amount, {String? description, String type = 'credit'}) async {
    print('[WalletService] creditWallet called for userId: $userId, amount: $amount, type: $type, description: $description');
    final walletRef = _firestore.collection('wallets').doc(userId);
    try {
      // Ensure wallet doc exists before transaction
      final doc = await walletRef.get();
      if (!doc.exists || doc.data() == null) {
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
        double prev = 0.0;
        if (doc.exists && doc.data() != null) {
          final bal = doc.data()!['balance'];
          if (bal is! int && bal is! double && bal is! String) {
            print('[WalletService] FATAL: balance is an unexpected type: [31m${bal.runtimeType}[0m, value: $bal. Forcing to 0.0 and updating Firestore.');
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
        print('[WalletService] Crediting wallet for $userId. Previous balance: $prev, New balance: $newBalance');
        txn.set(walletRef, {
          'balance': newBalance,
          'currency': 'NGN',
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': FieldValue.arrayUnion([tx]),
        }, SetOptions(merge: true));
      });
      print('[WalletService] creditWallet succeeded for $userId');
    } catch (e, st) {
      print('[WalletService] ERROR in creditWallet for $userId: $e\n$st');
      rethrow;
    }
  }

  static Future<double> getBalance({String? userId}) async {
    final uid = userId ?? currentUserId;
    final doc = await _firestore.collection('wallets').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return safeDouble(doc.data()!['balance']);
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
      // Ensure wallet doc exists before transaction
      final doc = await walletRef.get();
      if (!doc.exists || doc.data() == null) {
        print('[WalletService] Wallet doc does not exist for $uid. Creating new wallet doc.');
        await walletRef.set({
          'balance': 0.0,
          'currency': 'NGN',
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': [],
        });
      }
      await _firestore.runTransaction((txn) async {
        final doc = await txn.get(walletRef);
        print('[WalletService] wallet doc exists: ${doc.exists}, data: ${doc.data()}');
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
    } catch (e, st) {
      print('[WalletService] ERROR in fundWallet transaction: $e\n$st');
      // Fallback: try to create or update the wallet doc directly if transaction fails
      try {
        print('[WalletService] Attempting fallback wallet doc creation...');
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
        print('[WalletService] Fallback wallet doc creation succeeded.');
      } catch (e2, st2) {
        print('[WalletService] Fallback wallet doc creation failed: $e2\n$st2');
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
        final data = doc.data();
        print('[WalletService] Full wallet doc data: ${data}');
        double prev = 0.0;
        if (doc.exists && data != null) {
          final bal = data['balance'];
          if (bal is! int && bal is! double && bal is! String) {
            print('[WalletService] FATAL: balance is an unexpected type: [31m${bal.runtimeType}[0m, value: $bal. Forcing to 0.0 and updating Firestore.');
            await walletRef.update({'balance': 0.0});
            throw Exception('Corrupted wallet balance. Please try again.');
          }
          prev = safeDouble(bal);
          // Defensive: check transactions field
          if (data.containsKey('transactions')) {
            if (data['transactions'] == null) {
              print('[WalletService] WARNING: transactions field is null.');
            } else if (data['transactions'] is! List) {
              print('[WalletService] WARNING: transactions field is not a List. Value: ${data['transactions']}');
            }
          }
        }
        print('[WalletService] deductWallet Firestore doc exists: ${doc.exists}, prev balance: ${prev}');
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
        print('[WalletService] deductWallet transaction succeeded. New balance: ${newBalance}');
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
            if (ts is Timestamp || ts is DateTime || (ts is String && DateTime.tryParse(ts) != null)) {
              txs.add(safeTx);
            } else {
              print('[WalletService] Skipping transaction with bad timestamp: $safeTx');
            }
          } else {
            print('[WalletService] WARNING: Transaction is not a Map: $tx');
          }
        }
      } else {
        print('[WalletService] WARNING: transactions field is not a List. Value: $rawTxs');
      }
      // Sort by timestamp if possible
      txs.sort((a, b) {
        final tA = a['timestamp'];
        final tB = b['timestamp'];
        Timestamp? tsA;
        Timestamp? tsB;
        if (tA is Timestamp) {
          tsA = tA;
        } else if (tA is DateTime) tsA = Timestamp.fromDate(tA);
        else if (tA is String) {
          try { tsA = Timestamp.fromDate(DateTime.parse(tA)); } catch (_) {}
        }
        if (tB is Timestamp) {
          tsB = tB;
        } else if (tB is DateTime) tsB = Timestamp.fromDate(tB);
        else if (tB is String) {
          try { tsB = Timestamp.fromDate(DateTime.parse(tB)); } catch (_) {}
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
