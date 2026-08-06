const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Cloud Function: Release Escrow Payments
 * 
 * This function monitors appointment documents for status changes.
 * When an appointment status changes to 'completed', it:
 * 1. Finds the associated pendingPayment in escrow
 * 2. Credits 70% to the doctor's wallet
 * 3. Credits 30% to the admin wallet (admin_wallet)
 * 4. Marks the pendingPayment as 'released'
 * 
 * This ensures that regular patient appointments (non-facility) properly
 * distribute revenue to doctors and the platform.
 */

const ADMIN_WALLET_ID = 'admin_wallet';

exports.onAppointmentStatusChange = functions.firestore
  .document('appointments/{appointmentId}')
  .onUpdate(async (change, context) => {
    const appointmentId = context.params.appointmentId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed to 'completed'
    const statusChanged = beforeData.status !== afterData.status;
    const isNowCompleted = afterData.status === 'completed';

    if (!statusChanged || !isNowCompleted) {
      console.log(`Appointment ${appointmentId}: Status not changed to completed. Skipping.`);
      return null;
    }

    console.log(`🎯 Appointment ${appointmentId} marked as COMPLETED. Processing escrow release...`);

    try {
      const db = admin.firestore();

      // Find the pending payment for this appointment
      const pendingPaymentQuery = await db
        .collection('pendingPayments')
        .where('appointmentId', '==', appointmentId)
        .where('status', '==', 'held')
        .limit(1)
        .get();

      if (pendingPaymentQuery.empty) {
        console.log(`⚠️ No pending payment found for appointment ${appointmentId}. May be a free appointment or already released.`);
        return null;
      }

      const pendingPaymentDoc = pendingPaymentQuery.docs[0];
      const pendingPayment = pendingPaymentDoc.data();

      const {
        patientId,
        providerId,
        totalAmount,
        providerShare,
        adminShare,
      } = pendingPayment;

      console.log(`💰 Releasing escrow payment:
        - Appointment ID: ${appointmentId}
        - Patient ID: ${patientId}
        - Provider ID: ${providerId}
        - Total Amount: ₦${totalAmount}
        - Provider Share (70%): ₦${providerShare}
        - Admin Share (30%): ₦${adminShare}`);

      // Use transaction to ensure atomicity
      await db.runTransaction(async (transaction) => {
        // References
        const providerWalletRef = db.collection('wallets').doc(providerId);
        const adminWalletRef = db.collection('wallets').doc(ADMIN_WALLET_ID);
        const pendingPaymentRef = pendingPaymentDoc.ref;

        // Read current wallet balances
        const providerWalletDoc = await transaction.get(providerWalletRef);
        const adminWalletDoc = await transaction.get(adminWalletRef);

        const providerBalance = providerWalletDoc.exists 
          ? (providerWalletDoc.data().balance || 0) 
          : 0;
        const adminBalance = adminWalletDoc.exists 
          ? (adminWalletDoc.data().balance || 0) 
          : 0;

        // Prepare transaction records
        const timestamp = new Date().toISOString();

        const providerTransaction = {
          type: 'appointment_earning',
          amount: providerShare,
          description: `Consultation fee (70%) - Appointment ${appointmentId}`,
          timestamp: timestamp,
          appointmentId: appointmentId,
          patientId: patientId,
        };

        const adminTransaction = {
          type: 'platform_commission',
          amount: adminShare,
          description: `Platform commission (30%) - Appointment ${appointmentId}`,
          timestamp: timestamp,
          appointmentId: appointmentId,
          patientId: patientId,
          providerId: providerId,
        };

        // Credit provider wallet (70%)
        transaction.set(providerWalletRef, {
          balance: providerBalance + providerShare,
          currency: 'NGN',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactions: admin.firestore.FieldValue.arrayUnion(providerTransaction),
        }, { merge: true });

        console.log(`✅ Credited ₦${providerShare} to provider wallet ${providerId}`);

        // Credit admin wallet (30%)
        transaction.set(adminWalletRef, {
          balance: adminBalance + adminShare,
          currency: 'NGN',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactions: admin.firestore.FieldValue.arrayUnion(adminTransaction),
        }, { merge: true });

        console.log(`✅ Credited ₦${adminShare} to admin wallet ${ADMIN_WALLET_ID}`);

        // Mark pending payment as released
        transaction.update(pendingPaymentRef, {
          status: 'released',
          releasedAt: admin.firestore.FieldValue.serverTimestamp(),
          releasedBy: 'system',
          appointmentId: appointmentId,
        });

        console.log(`✅ Marked pendingPayment as released`);
      });

      console.log(`🎉 Escrow payment successfully released for appointment ${appointmentId}`);
      return { success: true, appointmentId, providerShare, adminShare };

    } catch (error) {
      console.error(`❌ Error releasing escrow payment for appointment ${appointmentId}:`, error);
      
      // Log error to a dedicated collection for monitoring
      try {
        await admin.firestore().collection('payment_errors').add({
          type: 'escrow_release_failure',
          appointmentId: appointmentId,
          error: error.message,
          stack: error.stack,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (logError) {
        console.error('Failed to log error:', logError);
      }

      throw error;
    }
  });

/**
 * Manual Cloud Function to Release a Specific Escrow Payment
 * 
 * This can be called by admin to manually release a stuck payment.
 * 
 * Usage:
 * Call with data: { appointmentId: 'xxx' } or { pendingPaymentId: 'yyy' }
 */
exports.releaseEscrowPaymentManually = functions.https.onCall(async (data, context) => {
  // Only allow authenticated admin users
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Check if user is admin (you may want to add role checking here)
  const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can manually release escrow payments');
  }

  const { appointmentId, pendingPaymentId } = data;

  if (!appointmentId && !pendingPaymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'Either appointmentId or pendingPaymentId is required');
  }

  try {
    const db = admin.firestore();
    let pendingPaymentDoc;

    // Find the pending payment
    if (pendingPaymentId) {
      pendingPaymentDoc = await db.collection('pendingPayments').doc(pendingPaymentId).get();
      if (!pendingPaymentDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Pending payment not found');
      }
    } else {
      const query = await db
        .collection('pendingPayments')
        .where('appointmentId', '==', appointmentId)
        .where('status', '==', 'held')
        .limit(1)
        .get();

      if (query.empty) {
        throw new functions.https.HttpsError('not-found', 'No pending payment found for this appointment');
      }

      pendingPaymentDoc = query.docs[0];
    }

    const pendingPayment = pendingPaymentDoc.data();

    if (pendingPayment.status !== 'held') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment is not in held status');
    }

    const {
      patientId,
      providerId,
      totalAmount,
      providerShare,
      adminShare,
    } = pendingPayment;

    console.log(`🔧 MANUAL RELEASE: Processing payment ${pendingPaymentDoc.id}`);

    // Use transaction to ensure atomicity
    await db.runTransaction(async (transaction) => {
      const providerWalletRef = db.collection('wallets').doc(providerId);
      const adminWalletRef = db.collection('wallets').doc(ADMIN_WALLET_ID);
      const pendingPaymentRef = pendingPaymentDoc.ref;

      const providerWalletDoc = await transaction.get(providerWalletRef);
      const adminWalletDoc = await transaction.get(adminWalletRef);

      const providerBalance = providerWalletDoc.exists ? (providerWalletDoc.data().balance || 0) : 0;
      const adminBalance = adminWalletDoc.exists ? (adminWalletDoc.data().balance || 0) : 0;

      const timestamp = new Date().toISOString();

      // Credit provider wallet (70%)
      transaction.set(providerWalletRef, {
        balance: providerBalance + providerShare,
        currency: 'NGN',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactions: admin.firestore.FieldValue.arrayUnion({
          type: 'appointment_earning',
          amount: providerShare,
          description: `Manual release - Consultation fee (70%)`,
          timestamp: timestamp,
          releasedBy: context.auth.uid,
        }),
      }, { merge: true });

      // Credit admin wallet (30%)
      transaction.set(adminWalletRef, {
        balance: adminBalance + adminShare,
        currency: 'NGN',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        transactions: admin.firestore.FieldValue.arrayUnion({
          type: 'platform_commission',
          amount: adminShare,
          description: `Manual release - Platform commission (30%)`,
          timestamp: timestamp,
          releasedBy: context.auth.uid,
        }),
      }, { merge: true });

      // Mark as released
      transaction.update(pendingPaymentRef, {
        status: 'released',
        releasedAt: admin.firestore.FieldValue.serverTimestamp(),
        releasedBy: context.auth.uid,
        releaseMethod: 'manual',
      });
    });

    console.log(`✅ Manual release completed for payment ${pendingPaymentDoc.id}`);

    return {
      success: true,
      message: 'Payment released successfully',
      providerShare,
      adminShare,
      totalAmount,
    };

  } catch (error) {
    console.error('Error in manual release:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});
