/**
 * Firebase Cloud Functions for Patient Wallet Refund Management
 * Handles refund applications from independent/remote patients
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Reuse the existing admin initialization if available
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Process patient refund approval
 * Called by Main Admin to approve a refund application
 */
exports.processPatientRefundApproval = functions.https.onCall(async (data, context) => {
  // Verify admin authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Verify admin role
  const adminDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!adminDoc.exists || adminDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can approve refunds');
  }

  const { applicationId } = data;

  if (!applicationId) {
    throw new functions.https.HttpsError('invalid-argument', 'Application ID is required');
  }

  try {
    // Get the refund application
    const applicationRef = db.collection('patient_refund_applications').doc(applicationId);
    const applicationDoc = await applicationRef.get();

    if (!applicationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Refund application not found');
    }

    const applicationData = applicationDoc.data();

    if (applicationData.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 
        `Application is already ${applicationData.status}`);
    }

    const patientId = applicationData.patientId;
    const amount = applicationData.amount;
    const bankCode = applicationData.bankCode;
    const accountNumber = applicationData.accountNumber;
    const accountName = applicationData.accountName;

    // Step 1: Create Paystack transfer recipient
    const recipientCode = await createPaystackRecipient(
      accountName,
      accountNumber,
      bankCode
    );

    // Step 2: Execute transfer and wallet deduction in a transaction
    await db.runTransaction(async (transaction) => {
      const walletRef = db.collection('wallets').doc(patientId);
      const walletDoc = await transaction.get(walletRef);

      if (!walletDoc.exists) {
        throw new Error('Patient wallet not found');
      }

      const currentBalance = walletDoc.data().balance || 0;

      if (currentBalance < amount) {
        throw new Error('Insufficient wallet balance');
      }

      // Deduct from patient wallet
      const newBalance = currentBalance - amount;
      transaction.update(walletRef, {
        balance: newBalance,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Add transaction record to wallet
      const walletTransaction = {
        type: 'refund_withdrawal',
        amount: -amount,
        description: `Wallet refund to ${accountName} (${accountNumber})`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        balance: newBalance,
        referenceId: applicationId,
      };

      transaction.update(walletRef, {
        transactions: admin.firestore.FieldValue.arrayUnion(walletTransaction),
      });

      // Update application status
      transaction.update(applicationRef, {
        status: 'approved',
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: context.auth.uid,
        paystackRecipientCode: recipientCode,
      });

      // Log approval
      const approvalLog = {
        adminId: context.auth.uid,
        adminName: adminDoc.data().name || 'Admin',
        action: 'approved',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        amount: amount,
      };

      transaction.set(
        applicationRef.collection('approval_logs').doc(),
        approvalLog
      );
    });

    // Step 3: Initiate Paystack transfer (outside transaction)
    await initiatePaystackTransfer(recipientCode, amount, applicationId);

    return {
      success: true,
      message: 'Refund approved and transfer initiated successfully',
      applicationId: applicationId,
    };
  } catch (error) {
    console.error('Error processing refund approval:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Reject patient refund application
 */
exports.rejectPatientRefundApplication = functions.https.onCall(async (data, context) => {
  // Verify admin authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Verify admin role
  const adminDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!adminDoc.exists || adminDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can reject refunds');
  }

  const { applicationId, reason } = data;

  if (!applicationId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 
      'Application ID and rejection reason are required');
  }

  try {
    const applicationRef = db.collection('patient_refund_applications').doc(applicationId);
    const applicationDoc = await applicationRef.get();

    if (!applicationDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Refund application not found');
    }

    const applicationData = applicationDoc.data();

    if (applicationData.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 
        `Application is already ${applicationData.status}`);
    }

    await db.runTransaction(async (transaction) => {
      // Update application status
      transaction.update(applicationRef, {
        status: 'rejected',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectedBy: context.auth.uid,
        rejectionReason: reason,
      });

      // Log rejection
      const rejectionLog = {
        adminId: context.auth.uid,
        adminName: adminDoc.data().name || 'Admin',
        action: 'rejected',
        reason: reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      };

      transaction.set(
        applicationRef.collection('approval_logs').doc(),
        rejectionLog
      );
    });

    return {
      success: true,
      message: 'Refund application rejected',
      applicationId: applicationId,
    };
  } catch (error) {
    console.error('Error rejecting refund application:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Helper function to create Paystack transfer recipient
 */
async function createPaystackRecipient(accountName, accountNumber, bankCode) {
  const fetch = (await import('node-fetch')).default;
  const paystackSecretKey = functions.config().paystack?.secret_key;

  if (!paystackSecretKey) {
    throw new Error('Paystack secret key not configured');
  }

  const url = 'https://api.paystack.co/transferrecipient';
  const payload = {
    type: 'nuban',
    name: accountName,
    account_number: accountNumber,
    bank_code: bankCode,
    currency: 'NGN',
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${paystackSecretKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const result = await response.json();

  if (!result.status) {
    throw new Error(result.message || 'Failed to create transfer recipient');
  }

  return result.data.recipient_code;
}

/**
 * Helper function to initiate Paystack transfer
 */
async function initiatePaystackTransfer(recipientCode, amount, reference) {
  const fetch = (await import('node-fetch')).default;
  const paystackSecretKey = functions.config().paystack?.secret_key;

  if (!paystackSecretKey) {
    throw new Error('Paystack secret key not configured');
  }

  const url = 'https://api.paystack.co/transfer';
  const amountInKobo = Math.round(amount * 100); // Convert to kobo

  const payload = {
    source: 'balance',
    amount: amountInKobo,
    recipient: recipientCode,
    reason: `Patient wallet refund - ${reference}`,
    reference: reference,
  };

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${paystackSecretKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const result = await response.json();

  if (!result.status) {
    throw new Error(result.message || 'Failed to initiate transfer');
  }

  return result.data;
}
