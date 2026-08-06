/**
 * WALLET REFUND MANAGEMENT SYSTEM
 * 
 * Handles patient wallet refunds with strict safety checks:
 * - Death of patient (next of kin claim)
 * - Patient relocation
 * - Other legitimate reasons
 * 
 * Security Features:
 * - Dual approval (Medical Records + Facility Admin)
 * - Bank account name verification
 * - Audit trail logging
 * - Automatic wallet balance verification
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * PAYSTACK BANK ACCOUNT NAME VERIFICATION
 * Verifies that the bank account name matches the patient/beneficiary name
 */
exports.verifyBankAccountName = functions.https.onCall(async (data, context) => {
  const { accountNumber, bankCode, expectedName, refundApplicationId } = data;

  // Validation
  if (!accountNumber || !bankCode || !expectedName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Account number, bank code, and expected name are required'
    );
  }

  try {
    // Paystack API: Resolve Bank Account
    const paystackSecretKey = functions.config().paystack?.secret_key;
    if (!paystackSecretKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Paystack configuration not found'
      );
    }

    const fetch = require('node-fetch');
    const paystackUrl = `https://api.paystack.co/bank/resolve?account_number=${accountNumber}&bank_code=${bankCode}`;
    
    const response = await fetch(paystackUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${paystackSecretKey}`,
        'Content-Type': 'application/json',
      },
    });

    const result = await response.json();

    if (!result.status) {
      throw new functions.https.HttpsError(
        'not-found',
        `Failed to resolve bank account: ${result.message}`
      );
    }

    const accountName = result.data.account_name;
    const accountNameLower = accountName.toLowerCase().trim();
    const expectedNameLower = expectedName.toLowerCase().trim();

    // Fuzzy name matching (accounts for middle names, initials, etc.)
    const nameSimilarity = calculateNameSimilarity(accountNameLower, expectedNameLower);
    const isMatch = nameSimilarity >= 0.7; // 70% similarity threshold

    // Log verification attempt
    if (refundApplicationId) {
      await admin.firestore()
        .collection('refund_applications')
        .doc(refundApplicationId)
        .collection('verification_logs')
        .add({
          type: 'bank_account_verification',
          accountNumber,
          bankCode,
          accountName,
          expectedName,
          similarity: nameSimilarity,
          isMatch,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
    }

    return {
      success: true,
      accountName,
      expectedName,
      isMatch,
      similarity: nameSimilarity,
      message: isMatch
        ? 'Bank account name verified successfully'
        : 'Bank account name does not match. Please verify the details.',
    };
  } catch (error) {
    console.error('❌ Bank account verification failed:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Verification failed: ${error.message}`
    );
  }
});

/**
 * PROCESS REFUND APPROVAL (Facility Admin)
 * Final step: Transfer funds to verified bank account
 */
exports.processRefundApproval = functions.https.onCall(async (data, context) => {
  const { refundApplicationId, facilityId, adminId, adminName } = data;

  // Validation
  if (!refundApplicationId || !facilityId || !adminId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields'
    );
  }

  const db = admin.firestore();
  const refundRef = db.collection('refund_applications').doc(refundApplicationId);

  try {
    // Get refund application
    const refundDoc = await refundRef.get();
    if (!refundDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Refund application not found');
    }

    const refund = refundDoc.data();

    // Security checks
    if (refund.facilityId !== facilityId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Refund application does not belong to this facility'
      );
    }

    if (refund.status !== 'pending_admin_approval') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Cannot approve refund with status: ${refund.status}`
      );
    }

    if (!refund.bankAccountVerified) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Bank account must be verified before approval'
      );
    }

    // Get patient wallet
    const walletRef = db.collection('wallets').doc(refund.patientId);
    const walletDoc = await walletRef.get();

    if (!walletDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Patient wallet not found');
    }

    const wallet = walletDoc.data();
    const currentBalance = wallet.balance || 0;

    // Check sufficient balance
    if (currentBalance < refund.refundAmount) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient wallet balance. Required: ₦${refund.refundAmount}, Available: ₦${currentBalance}`
      );
    }

    // Initialize Paystack transfer
    const transferResult = await initiatePaystackTransfer({
      amount: refund.refundAmount,
      recipientCode: refund.recipientCode, // Created during bank verification
      reason: `Wallet refund - ${refund.refundReason}`,
      reference: `REFUND_${refundApplicationId}`,
    });

    if (!transferResult.success) {
      // Update refund status to failed
      await refundRef.update({
        status: 'transfer_failed',
        transferError: transferResult.message,
        approvedBy: adminId,
        approvedByName: adminName,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      throw new functions.https.HttpsError(
        'internal',
        `Transfer failed: ${transferResult.message}`
      );
    }

    // Run transaction to deduct from wallet and update refund
    await db.runTransaction(async (transaction) => {
      // Re-read wallet to ensure balance hasn't changed
      const freshWallet = await transaction.get(walletRef);
      const freshBalance = freshWallet.data().balance || 0;

      if (freshBalance < refund.refundAmount) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Wallet balance changed during processing'
        );
      }

      // Deduct from wallet
      transaction.update(walletRef, {
        balance: freshBalance - refund.refundAmount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create wallet transaction
      const walletTransactionRef = walletRef.collection('transactions').doc();
      transaction.set(walletTransactionRef, {
        type: 'refund',
        amount: refund.refundAmount,
        balanceBefore: freshBalance,
        balanceAfter: freshBalance - refund.refundAmount,
        description: `Wallet refund - ${refund.refundReason}`,
        refundApplicationId,
        transferReference: transferResult.reference,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        processedBy: adminId,
        processedByName: adminName,
      });

      // Update refund application
      transaction.update(refundRef, {
        status: 'approved',
        approvedBy: adminId,
        approvedByName: adminName,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        transferReference: transferResult.reference,
        transferId: transferResult.transferId,
        walletBalanceBefore: freshBalance,
        walletBalanceAfter: freshBalance - refund.refundAmount,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create approval log
      const approvalLogRef = refundRef.collection('approval_logs').doc();
      transaction.set(approvalLogRef, {
        type: 'admin_approval',
        performedBy: adminId,
        performedByName: adminName,
        action: 'approved',
        notes: 'Transfer initiated successfully',
        transferReference: transferResult.reference,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    console.log(`✅ Refund approved: ${refundApplicationId} - ₦${refund.refundAmount}`);

    return {
      success: true,
      message: 'Refund approved and transfer initiated successfully',
      transferReference: transferResult.reference,
      amount: refund.refundAmount,
    };
  } catch (error) {
    console.error('❌ Refund approval failed:', error);
    
    // Log the failure
    await refundRef.collection('approval_logs').add({
      type: 'admin_approval_failed',
      performedBy: adminId,
      performedByName: adminName,
      action: 'approval_failed',
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    throw error;
  }
});

/**
 * REJECT REFUND APPLICATION (Facility Admin)
 */
exports.rejectRefundApplication = functions.https.onCall(async (data, context) => {
  const { refundApplicationId, facilityId, adminId, adminName, rejectionReason } = data;

  if (!refundApplicationId || !facilityId || !adminId || !rejectionReason) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields'
    );
  }

  const db = admin.firestore();
  const refundRef = db.collection('refund_applications').doc(refundApplicationId);

  try {
    const refundDoc = await refundRef.get();
    if (!refundDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Refund application not found');
    }

    const refund = refundDoc.data();

    if (refund.facilityId !== facilityId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Refund application does not belong to this facility'
      );
    }

    if (refund.status !== 'pending_admin_approval') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Cannot reject refund with status: ${refund.status}`
      );
    }

    const batch = db.batch();

    // Update refund status
    batch.update(refundRef, {
      status: 'rejected',
      rejectedBy: adminId,
      rejectedByName: adminName,
      rejectionReason,
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create rejection log
    const rejectionLogRef = refundRef.collection('approval_logs').doc();
    batch.set(rejectionLogRef, {
      type: 'admin_rejection',
      performedBy: adminId,
      performedByName: adminName,
      action: 'rejected',
      notes: rejectionReason,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    console.log(`❌ Refund rejected: ${refundApplicationId}`);

    return {
      success: true,
      message: 'Refund application rejected successfully',
    };
  } catch (error) {
    console.error('❌ Refund rejection failed:', error);
    throw error;
  }
});

/**
 * Helper: Calculate name similarity (Levenshtein distance)
 */
function calculateNameSimilarity(str1, str2) {
  // Remove common titles and normalize
  const normalize = (str) => {
    return str
      .replace(/\b(mr|mrs|ms|miss|dr|prof|chief|engr|arc|barr|hon)\b\.?/gi, '')
      .replace(/[^a-z\s]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  };

  const s1 = normalize(str1);
  const s2 = normalize(str2);

  // Check if one name contains the other
  if (s1.includes(s2) || s2.includes(s1)) {
    return 0.9;
  }

  // Levenshtein distance
  const matrix = [];
  const len1 = s1.length;
  const len2 = s2.length;

  for (let i = 0; i <= len1; i++) {
    matrix[i] = [i];
  }

  for (let j = 0; j <= len2; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= len1; i++) {
    for (let j = 1; j <= len2; j++) {
      const cost = s1[i - 1] === s2[j - 1] ? 0 : 1;
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost
      );
    }
  }

  const distance = matrix[len1][len2];
  const maxLength = Math.max(len1, len2);
  return 1 - distance / maxLength;
}

/**
 * Helper: Initiate Paystack transfer
 */
async function initiatePaystackTransfer({ amount, recipientCode, reason, reference }) {
  try {
    const paystackSecretKey = functions.config().paystack?.secret_key;
    const fetch = require('node-fetch');

    const response = await fetch('https://api.paystack.co/transfer', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${paystackSecretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        source: 'balance',
        reason,
        amount: amount * 100, // Convert to kobo
        recipient: recipientCode,
        reference,
      }),
    });

    const result = await response.json();

    if (!result.status) {
      return {
        success: false,
        message: result.message || 'Transfer failed',
      };
    }

    return {
      success: true,
      transferId: result.data.id,
      reference: result.data.reference,
      message: 'Transfer initiated successfully',
    };
  } catch (error) {
    return {
      success: false,
      message: error.message,
    };
  }
}

/**
 * CREATE PAYSTACK TRANSFER RECIPIENT
 * Called after bank account verification
 */
exports.createTransferRecipient = functions.https.onCall(async (data, context) => {
  const { refundApplicationId, accountNumber, bankCode, accountName } = data;

  if (!refundApplicationId || !accountNumber || !bankCode || !accountName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields'
    );
  }

  try {
    const paystackSecretKey = functions.config().paystack?.secret_key;
    const fetch = require('node-fetch');

    const response = await fetch('https://api.paystack.co/transferrecipient', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${paystackSecretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        type: 'nuban',
        name: accountName,
        account_number: accountNumber,
        bank_code: bankCode,
        currency: 'NGN',
      }),
    });

    const result = await response.json();

    if (!result.status) {
      throw new functions.https.HttpsError(
        'internal',
        `Failed to create recipient: ${result.message}`
      );
    }

    const recipientCode = result.data.recipient_code;

    // Update refund application with recipient code
    await admin.firestore()
      .collection('refund_applications')
      .doc(refundApplicationId)
      .update({
        recipientCode,
        bankAccountVerified: true,
        status: 'pending_admin_approval',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
      recipientCode,
      message: 'Transfer recipient created successfully',
    };
  } catch (error) {
    console.error('❌ Create recipient failed:', error);
    throw error;
  }
});
