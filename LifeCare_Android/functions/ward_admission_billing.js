/**
 * Ward Admission Billing System
 * 
 * Handles automatic daily charging for ward admissions:
 * - Charges patients per night for ward stays
 * - Stops charging when patient is discharged
 * - Tracks all charges in billing history
 * - Handles insufficient balance scenarios
 * 
 * Cloud Functions:
 * 1. processWardBillingDaily - Scheduled daily function to charge all admitted patients
 * 2. processAdmissionCharge - Callable function to charge a specific admission
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Scheduled function that runs daily at 11:59 PM to charge all active admissions
 * Runs on: Africa/Lagos timezone (Nigerian time)
 * Schedule: Every day at 23:59 (11:59 PM)
 */
exports.processWardBillingDaily = functions.pubsub
  .schedule('59 23 * * *')
  .timeZone('Africa/Lagos')
  .onRun(async (context) => {
    console.log('🏥 Starting daily ward billing process...');

    try {
      const now = admin.firestore.Timestamp.now();
      const db = admin.firestore();

      // Get all active admissions that should be charged
      // Note: Using 'inpatients' collection (not 'admissions')
      const admissionsSnapshot = await db.collection('inpatients')
        .where('status', '==', 'admitted')
        .where('chargePerNight', '>', 0)
        .get();

      console.log(`📋 Found ${admissionsSnapshot.size} active admissions to process`);

      let successCount = 0;
      let failureCount = 0;
      const results = [];

      // Process each admission
      for (const admissionDoc of admissionsSnapshot.docs) {
        try {
          const admissionData = admissionDoc.data();
          const admissionId = admissionDoc.id;

          // Check if we should charge today
          const shouldCharge = await shouldChargeToday(admissionDoc.ref, admissionData, now);

          if (!shouldCharge) {
            console.log(`⏭️  Skipping ${admissionId} - Already charged today or grace period`);
            continue;
          }

          // Process the charge
          const result = await processAdmissionChargeInternal(admissionDoc.ref, admissionData);
          
          if (result.success) {
            successCount++;
            console.log(`✅ Successfully charged admission ${admissionId}`);
          } else {
            failureCount++;
            console.log(`⚠️  Failed to charge admission ${admissionId}: ${result.error}`);
          }

          results.push({
            admissionId,
            ...result
          });

        } catch (error) {
          failureCount++;
          console.error(`❌ Error processing admission ${admissionDoc.id}:`, error);
          results.push({
            admissionId: admissionDoc.id,
            success: false,
            error: error.message
          });
        }
      }

      console.log(`🏥 Daily billing complete: ${successCount} successful, ${failureCount} failed`);

      // Store billing run summary
      await db.collection('billing_runs').add({
        runDate: now,
        totalProcessed: admissionsSnapshot.size,
        successCount,
        failureCount,
        results,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      return {
        success: true,
        totalProcessed: admissionsSnapshot.size,
        successCount,
        failureCount
      };

    } catch (error) {
      console.error('❌ Fatal error in daily billing:', error);
      throw error;
    }
  });

/**
 * Callable function to manually charge a specific admission
 * Can be called from the app for immediate charging
 */
exports.chargeAdmissionNow = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { admissionId } = data;

  if (!admissionId) {
    throw new functions.https.HttpsError('invalid-argument', 'admissionId is required');
  }

  try {
    const db = admin.firestore();
    const admissionRef = db.collection('inpatients').doc(admissionId);
    const admissionDoc = await admissionRef.get();

    if (!admissionDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Admission not found');
    }

    const admissionData = admissionDoc.data();

    if (admissionData.status !== 'admitted') {
      throw new functions.https.HttpsError('failed-precondition', 'Patient is not currently admitted');
    }

    const result = await processAdmissionChargeInternal(admissionRef, admissionData);

    if (!result.success) {
      throw new functions.https.HttpsError('internal', result.error || 'Failed to process charge');
    }

    return result;

  } catch (error) {
    console.error('Error in chargeAdmissionNow:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Internal function to process a single admission charge
 */
async function processAdmissionChargeInternal(admissionRef, admissionData) {
  const db = admin.firestore();
  const admissionId = admissionRef.id;

  try {
    const {
      patientId,
      patientName,
      chargePerNight,
      facilityId,
      facilityName,
      wardName,
      bedNumber,
      roomNumber,
    } = admissionData;

    if (!chargePerNight || chargePerNight <= 0) {
      return {
        success: false,
        error: 'No charge configured for this admission'
      };
    }

    // Calculate charge amount (could include taxes, etc. in future)
    const chargeAmount = Number(chargePerNight);
    const facilityShare = Math.round(chargeAmount * 0.975); // 97.5% to facility
    const platformFee = chargeAmount - facilityShare; // 2.5% platform fee

    // Process payment using transaction for atomicity
    const result = await db.runTransaction(async (transaction) => {
      // Get patient wallet
      const patientWalletRef = db.collection('wallets').doc(patientId);
      const patientWalletDoc = await transaction.get(patientWalletRef);

      let patientBalance = 0;
      if (patientWalletDoc.exists) {
        patientBalance = patientWalletDoc.data()?.balance || 0;
      }

      // Check sufficient balance
      if (patientBalance < chargeAmount) {
        // Record insufficient balance
        await recordBillingHistory(transaction, admissionRef, {
          patientId,
          patientName,
          chargeAmount,
          status: 'insufficient_balance',
          patientBalance,
          chargeDate: admin.firestore.FieldValue.serverTimestamp(),
          description: `Insufficient balance: ₦${patientBalance.toFixed(2)} < ₦${chargeAmount.toFixed(2)}`
        });

        // Update admission with payment issue flag
        transaction.update(admissionRef, {
          paymentIssue: true,
          lastPaymentIssueDate: admin.firestore.FieldValue.serverTimestamp(),
          insufficientBalanceCount: admin.firestore.FieldValue.increment(1),
        });

        return {
          success: false,
          error: `Insufficient balance: ₦${patientBalance.toFixed(2)} < ₦${chargeAmount.toFixed(2)}`,
          requiresAction: true
        };
      }

      // Deduct from patient wallet
      const newBalance = patientBalance - chargeAmount;
      transaction.set(patientWalletRef, {
        balance: newBalance,
        currency: 'NGN',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactions: admin.firestore.FieldValue.arrayUnion({
          type: 'deduct',
          amount: chargeAmount,
          description: `Ward admission charge - ${wardName} Room ${roomNumber} Bed ${bedNumber}`,
          timestamp: new Date().toISOString(),
          admissionId: admissionId,
          facilityId: facilityId,
        }),
      }, { merge: true });

      // Credit facility wallet
      const facilityWalletRef = db.collection('wallets').doc(facilityId);
      const facilityWalletDoc = await transaction.get(facilityWalletRef);
      const facilityBalance = facilityWalletDoc.exists ? (facilityWalletDoc.data()?.balance || 0) : 0;

      transaction.set(facilityWalletRef, {
        balance: facilityBalance + facilityShare,
        currency: 'NGN',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactions: admin.firestore.FieldValue.arrayUnion({
          type: 'credit',
          amount: facilityShare,
          description: `Ward admission revenue - ${patientName}`,
          timestamp: new Date().toISOString(),
          admissionId: admissionId,
          patientId: patientId,
        }),
      }, { merge: true });

      // Credit admin wallet with platform fee
      const adminWalletRef = db.collection('wallets').doc('admin_wallet');
      const adminWalletDoc = await transaction.get(adminWalletRef);
      const adminBalance = adminWalletDoc.exists ? (adminWalletDoc.data()?.balance || 0) : 0;

      transaction.set(adminWalletRef, {
        balance: adminBalance + platformFee,
        currency: 'NGN',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactions: admin.firestore.FieldValue.arrayUnion({
          type: 'credit',
          amount: platformFee,
          description: `Platform fee - Ward admission ${admissionId}`,
          timestamp: new Date().toISOString(),
          admissionId: admissionId,
          facilityId: facilityId,
        }),
      }, { merge: true });

      // Record successful billing
      await recordBillingHistory(transaction, admissionRef, {
        patientId,
        patientName,
        chargeAmount,
        facilityShare,
        platformFee,
        status: 'successful',
        chargeDate: admin.firestore.FieldValue.serverTimestamp(),
        previousBalance: patientBalance,
        newBalance: newBalance,
        description: `Daily ward charge - ${wardName} Room ${roomNumber} Bed ${bedNumber}`
      });

      // Update admission record
      transaction.update(admissionRef, {
        lastChargeDate: admin.firestore.FieldValue.serverTimestamp(),
        totalChargedAmount: admin.firestore.FieldValue.increment(chargeAmount),
        chargeCount: admin.firestore.FieldValue.increment(1),
        paymentIssue: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        chargeAmount,
        facilityShare,
        platformFee,
        newBalance
      };
    });

    return result;

  } catch (error) {
    console.error(`Error processing charge for admission ${admissionId}:`, error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Helper function to record billing history
 */
async function recordBillingHistory(transaction, admissionRef, billingData) {
  const billingHistoryRef = admissionRef.collection('billing_history').doc();
  transaction.set(billingHistoryRef, {
    ...billingData,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Helper function to determine if we should charge today
 * Prevents duplicate charges on the same day
 */
async function shouldChargeToday(admissionRef, admissionData, now) {
  const { lastChargeDate, admissionDate, chargesStopped } = admissionData;

  // Check if billing has been stopped (e.g., patient discharged)
  if (chargesStopped === true) {
    console.log('⏹️  Billing stopped for this admission');
    return false;
  }

  // Check if already charged today
  if (lastChargeDate) {
    const lastCharge = lastChargeDate.toDate();
    const today = now.toDate();
    
    // If last charge was today, skip
    if (
      lastCharge.getDate() === today.getDate() &&
      lastCharge.getMonth() === today.getMonth() &&
      lastCharge.getFullYear() === today.getFullYear()
    ) {
      return false;
    }
  }

  // Optional: Grace period (don't charge on acceptance day)
  // Use acceptedAt if available, otherwise fall back to admittedAt
  const acceptanceDate = admissionData.acceptedAt || admissionDate;
  if (acceptanceDate) {
    const acceptanceDay = acceptanceDate.toDate();
    const today = now.toDate();
    
    // If accepted/admitted today, skip charge (grace period)
    if (
      acceptanceDay.getDate() === today.getDate() &&
      acceptanceDay.getMonth() === today.getMonth() &&
      acceptanceDay.getFullYear() === today.getFullYear()
    ) {
      return false;
    }
  }

  return true;
}

/**
 * Get billing summary for an admission
 * Useful for displaying in the app
 */
exports.getAdmissionBillingSummary = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { admissionId } = data;

  if (!admissionId) {
    throw new functions.https.HttpsError('invalid-argument', 'admissionId is required');
  }

  try {
    const db = admin.firestore();
    const admissionRef = db.collection('inpatients').doc(admissionId);
    const admissionDoc = await admissionRef.get();

    if (!admissionDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Admission not found');
    }

    const admissionData = admissionDoc.data();

    // Get billing history
    const billingHistorySnapshot = await admissionRef.collection('billing_history')
      .orderBy('createdAt', 'desc')
      .get();

    const billingHistory = billingHistorySnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Calculate summary
    const totalCharged = admissionData.totalChargedAmount || 0;
    const chargeCount = admissionData.chargeCount || 0;
    const chargePerNight = admissionData.chargePerNight || 0;

    // Calculate days admitted
    const admissionDate = admissionData.admissionDate?.toDate() || new Date();
    const now = new Date();
    const daysAdmitted = Math.floor((now - admissionDate) / (1000 * 60 * 60 * 24));

    return {
      success: true,
      admissionId,
      patientName: admissionData.patientName,
      status: admissionData.status,
      admissionDate: admissionDate.toISOString(),
      daysAdmitted,
      chargePerNight,
      totalCharged,
      chargeCount,
      expectedCharges: daysAdmitted * chargePerNight,
      unpaidAmount: (daysAdmitted * chargePerNight) - totalCharged,
      hasPaymentIssue: admissionData.paymentIssue || false,
      billingHistory,
    };

  } catch (error) {
    console.error('Error getting billing summary:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

module.exports = {
  processWardBillingDaily: exports.processWardBillingDaily,
  chargeAdmissionNow: exports.chargeAdmissionNow,
  getAdmissionBillingSummary: exports.getAdmissionBillingSummary,
};
