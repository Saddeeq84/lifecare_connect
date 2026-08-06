import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifecare_connect/core/utils/admin_notifications.dart';

class WithdrawalService {
  /// Payout to provider's bank account using Cloud Function
  static Future<Map<String, dynamic>> payoutWithdrawal({
    required String withdrawalId,
    required String userId,
    required double amount,
    required String accountNumber,
    required String bankCode,
    required String accountName,
    bool isAdminApproval = false, // For logging purposes only
  }) async {
    final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'paystackTransfer',
    );
    final result = await callable.call({
      'withdrawalId': withdrawalId,
      'userId': userId,
      'amount': amount,
      'accountNumber': accountNumber,
      'bankCode': bankCode,
      'accountName': accountName,
      'isAdminApproval': isAdminApproval, // Pass for logging and transparency
    });
    return Map<String, dynamic>.from(result.data);
  }

  static final _firestore = FirebaseFirestore.instance;

  /// Request a withdrawal for a user (provider/admin)
  static Future<void> requestWithdrawal({
    required String userId,
    required double amount,
    required String bankName,
    required String bankCode, // Paystack bank code
    required String accountNumber,
    required String accountName,
    String? role, // doctor, chw, admin
  }) async {
    final withdrawalRef = _firestore.collection('withdrawals').doc();
    final isAdmin = role == 'admin';
    final isFacility = role == 'facility';
    final requiresApproval =
        !isAdmin &&
        !isFacility; // Only non-admin and non-facility users require approval

    // IMPORTANT FIX: Deduct amount from user's wallet immediately when request is submitted
    // This prevents the accumulation issue where failed transfers cause double crediting
    if (requiresApproval) {
      // For non-admin users, deduct the amount from their wallet immediately
      final walletRef = _firestore.collection('wallets').doc(userId);

      // First, check escrow amount outside the transaction (for service providers)
      double totalEscrow = 0;
      if (role == 'doctor' || role == 'chw') {
        try {
          final pendingPaymentsQuery = await _firestore
              .collection('pendingPayments')
              .where('providerId', isEqualTo: userId)
              .where('status', isEqualTo: 'held')
              .get();

          for (final doc in pendingPaymentsQuery.docs) {
            final data = doc.data();
            final providerShare =
                (data['providerShare'] as num?)?.toDouble() ?? 0.0;
            totalEscrow += providerShare;
          }
        } catch (e) {
          // Continue without escrow calculation if query fails
        }
      }

      await _firestore.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);
        final walletData = walletSnapshot.data() ?? {};
        final currentBalance =
            (walletData['balance'] as num?)?.toDouble() ?? 0.0;

        // Check available balance (subtract escrow for providers)
        final availableBalance = currentBalance - totalEscrow;

        if (availableBalance < amount) {
          throw Exception(
            'Insufficient balance. Available: ₦${availableBalance.toStringAsFixed(2)}, Requested: ₦${amount.toStringAsFixed(2)}',
          );
        }

        // Deduct the amount immediately

        // Create transaction entry with explicit type casting
        // NOTE: Cannot use FieldValue.serverTimestamp() inside arrays within transactions
        final Map<String, dynamic> transactionEntry = <String, dynamic>{
          'type': 'withdrawal_request',
          'amount': amount,
          'description':
              'Withdrawal request to $accountName ($accountNumber) - Amount held pending approval',
          'timestamp': DateTime.now().toIso8601String(),
          'withdrawalId': withdrawalRef.id,
          'status': 'pending_approval',
        };

        // Add transaction entry to existing transactions
        final List<Map<String, dynamic>> currentTransactions = [];
        if (walletData['transactions'] != null) {
          final existingTransactions = walletData['transactions'] as List;
          for (final trans in existingTransactions) {
            if (trans is Map) {
              currentTransactions.add(Map<String, dynamic>.from(trans));
            }
          }
        }
        currentTransactions.add(transactionEntry);

        // CRITICAL FIX: Combine balance and transactions update into a single transaction.update()
        // This prevents the "type 'minified:aah' is not a subtype of type 'minified:u'" error
        transaction.update(walletRef, <String, dynamic>{
          'balance': currentBalance - amount,
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': currentTransactions,
        });
      });
    }

    try {
      // Create withdrawal data with explicit type declaration
      final Map<String, dynamic> withdrawalData = <String, dynamic>{
        'userId': userId,
        'amount': amount,
        'bankName': bankName,
        'bankCode': bankCode,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'role': role,
        'status': (isAdmin || isFacility) ? 'approved' : 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'amountDeducted':
            requiresApproval, // Track if amount was deducted at request time
      };

      if (isAdmin || isFacility) {
        withdrawalData['approvedAt'] = FieldValue.serverTimestamp();
      }

      await withdrawalRef.set(withdrawalData);

      // For facilities and admins, automatically process the withdrawal immediately
      if (isAdmin || isFacility) {
        try {
          await payoutWithdrawal(
            withdrawalId: withdrawalRef.id,
            userId: userId,
            amount: amount,
            accountNumber: accountNumber,
            bankCode: bankCode,
            accountName: accountName,
            isAdminApproval: true, // Mark as approved withdrawal
          );
        } catch (e) {
          // If payout fails, update withdrawal status to failed
          await withdrawalRef.update({
            'status': 'failed',
            'errorMessage': e.toString(),
            'failedAt': FieldValue.serverTimestamp(),
          });
          rethrow;
        }
      }
    } catch (e) {
      rethrow;
    }

    // Send confirmation notification to provider about withdrawal submission
    await _sendProviderWithdrawalConfirmation(
      userId: userId,
      userName: accountName,
      amount: amount,
      role: role ?? 'provider',
    );

    // Send admin notification only for withdrawals that require approval (not admin or facility)
    if (requiresApproval) {
      try {
        // Get user details from Firestore
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final userName =
              userData['fullName'] ?? userData['name'] ?? 'Unknown User';
          final userEmail = userData['email'] ?? 'no-email@example.com';

          await sendAdminWithdrawalNotification(
            userId: userId,
            userName: userName,
            userEmail: userEmail,
            role: role ?? 'unknown',
            amount: amount,
            bankName: bankName,
            accountNumber: accountNumber,
            accountName: accountName,
            withdrawalId: withdrawalRef.id,
          );
        }
      } catch (e) {
        // Don't throw - notification failure shouldn't block withdrawal request
      }
    }
  }

  /// Get withdrawal requests for a user
  static Future<List<Map<String, dynamic>>> getWithdrawals(
    String userId,
  ) async {
    final query = await _firestore
        .collection('withdrawals')
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt', descending: true)
        .get();
    return query.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Include document ID
      return data;
    }).toList();
  }

  /// Send confirmation notification to provider when withdrawal is submitted
  static Future<void> _sendProviderWithdrawalConfirmation({
    required String userId,
    required String userName,
    required double amount,
    required String role,
  }) async {
    try {
      // Send in-app message with explicit type declaration
      final Map<String, dynamic> messageData = <String, dynamic>{
        'conversationId': userId,
        'senderId': 'system',
        'senderName': 'LifeCare Connect',
        'senderRole': 'system',
        'receiverId': userId,
        'receiverName': userName,
        'receiverRole': role,
        'content':
            '✅ WITHDRAWAL REQUEST SUBMITTED\n\n'
            'Your withdrawal request for ₦${amount.toStringAsFixed(2)} has been successfully submitted and is now pending admin approval.\n\n'
            '⏰ PROCESSING TIME:\n'
            'Withdrawal requests typically take 1-2 working days to process after approval. You should expect the funds in your bank account within this timeframe.\n\n'
            '📋 WHAT HAPPENS NEXT:\n'
            '• Admin will review and approve your request\n'
            '• Once approved, funds will be transferred to your bank account\n'
            '• You will receive a notification when the transfer is completed\n\n'
            '💡 TIP: You can check the status of your withdrawal in the "Wallet" section of the app.\n\n'
            'Thank you for using LifeCare Connect!',
        'type': 'withdrawal_submitted',
        'priority': 'normal',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('messages').add(messageData);

      // You can integrate with your email service to send similar content via email
    } catch (e) {
      // Don't throw - notification failure shouldn't block withdrawal request
    }
  }

  /// Reject a withdrawal and refund if amount was deducted
  static Future<void> rejectWithdrawal(String withdrawalId) async {
    final withdrawalRef = _firestore
        .collection('withdrawals')
        .doc(withdrawalId);
    final withdrawalDoc = await withdrawalRef.get();

    if (!withdrawalDoc.exists) {
      throw Exception('Withdrawal not found');
    }

    final withdrawalData = withdrawalDoc.data()!;
    final amountDeducted = withdrawalData['amountDeducted'] == true;
    final amount = (withdrawalData['amount'] as num).toDouble();
    final userId = withdrawalData['userId'] as String;
    final accountName = withdrawalData['accountName'] as String;
    final accountNumber = withdrawalData['accountNumber'] as String;

    // Update withdrawal status
    await withdrawalRef.update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    // If amount was deducted during request, refund it
    if (amountDeducted) {
      final walletRef = _firestore.collection('wallets').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);
        final walletData = walletSnapshot.data() ?? {};
        final currentBalance =
            (walletData['balance'] as num?)?.toDouble() ?? 0.0;

        // Refund the amount
        // NOTE: Cannot use FieldValue.serverTimestamp() inside arrays within transactions
        final Map<String, dynamic> refundTransaction = <String, dynamic>{
          'type': 'refund',
          'amount': amount,
          'description':
              'Withdrawal rejected - Amount refunded to $accountName ($accountNumber)',
          'timestamp': DateTime.now().toIso8601String(),
          'withdrawalId': withdrawalId,
          'status': 'completed',
        };

        // Handle transactions array properly
        final List<Map<String, dynamic>> currentTransactions = [];
        if (walletData['transactions'] != null) {
          final existingTransactions = walletData['transactions'] as List;
          for (final trans in existingTransactions) {
            if (trans is Map) {
              currentTransactions.add(Map<String, dynamic>.from(trans));
            }
          }
        }
        currentTransactions.add(refundTransaction);

        // CRITICAL FIX: Combine balance and transactions update into a single transaction.update()
        transaction.update(walletRef, <String, dynamic>{
          'balance': currentBalance + amount,
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': currentTransactions,
        });
      });
    }
  }
}
