const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Auto-Billing Cloud Function
 * 
 * Runs daily to check subscriptions and process monthly payments
 * Calculates: Base monthly fee + transaction fee percentage
 * Deducts from facility wallet
 * 
 * Schedule: Every day at 2:00 AM
 */
exports.processSubscriptionBilling = functions.pubsub
  .schedule('0 2 * * *') // Cron: 2:00 AM daily
  .timeZone('Africa/Lagos')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const today = new Date();
    
    console.log('Starting subscription billing process...');

    try {
      // Get all active subscriptions where nextPaymentDate is today or overdue
      const subscriptionsSnapshot = await db.collection('subscriptions')
        .where('isActive', '==', true)
        .where('nextPaymentDate', '<=', now)
        .get();

      console.log(`Found ${subscriptionsSnapshot.size} subscriptions due for payment`);

      const billingPromises = subscriptionsSnapshot.docs.map(async (subscriptionDoc) => {
        const subscription = subscriptionDoc.data();
        const userId = subscription.userId;
        
        try {
          // Get facility details
          const userDoc = await db.collection('users').doc(userId).get();
          if (!userDoc.exists) {
            console.error(`User ${userId} not found`);
            return { userId, status: 'error', message: 'User not found' };
          }

          const facilityName = userDoc.data().name || 'Unknown Facility';
          
          // Calculate monthly fee
          let monthlyFee = 0;
          let transactionFeePercent = 2.5; // Default fallback
          let planName = 'Legacy Plan';

          // Check if facility has a plan assigned
          if (subscription.planId) {
            const planDoc = await db.collection('subscription_plans').doc(subscription.planId).get();
            
            if (planDoc.exists) {
              const plan = planDoc.data();
              monthlyFee = plan.monthlyFee || 0;
              transactionFeePercent = plan.transactionFeePercent || 2.5;
              planName = plan.name || 'Unknown Plan';
            } else {
              console.warn(`Plan ${subscription.planId} not found for user ${userId}`);
            }
          }

          // Calculate transaction fees for the past month
          const lastMonth = new Date(today);
          lastMonth.setMonth(lastMonth.getMonth() - 1);
          
          const transactionsSnapshot = await db.collection('transactions')
            .where('facilityId', '==', userId)
            .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
            .where('timestamp', '<', now)
            .get();

          let totalTransactionAmount = 0;
          transactionsSnapshot.forEach(doc => {
            const amount = doc.data().amount || 0;
            totalTransactionAmount += amount;
          });

          const transactionFee = totalTransactionAmount * (transactionFeePercent / 100);
          const totalDue = monthlyFee + transactionFee;

          console.log(`User ${userId} (${facilityName}): Monthly Fee = ₦${monthlyFee}, Transaction Fee = ₦${transactionFee.toFixed(2)}, Total = ₦${totalDue.toFixed(2)}`);

          // Get wallet balance
          const walletDoc = await db.collection('wallets').doc(userId).get();
          
          if (!walletDoc.exists) {
            console.error(`Wallet not found for user ${userId}`);
            return await handleInsufficientBalance(db, userId, facilityName, totalDue, 0, subscription);
          }

          const walletBalance = walletDoc.data().balance || 0;

          // Check if sufficient balance
          if (walletBalance < totalDue) {
            console.warn(`Insufficient balance for user ${userId}. Balance: ₦${walletBalance}, Required: ₦${totalDue.toFixed(2)}`);
            return await handleInsufficientBalance(db, userId, facilityName, totalDue, walletBalance, subscription);
          }

          // Deduct from wallet
          await db.collection('wallets').doc(userId).update({
            balance: admin.firestore.FieldValue.increment(-totalDue),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Create payment record
          await db.collection('subscription_payments').add({
            userId: userId,
            type: 'monthly_billing',
            amount: totalDue,
            monthlyFee: monthlyFee,
            transactionFee: transactionFee,
            transactionFeePercent: transactionFeePercent,
            totalTransactionAmount: totalTransactionAmount,
            planId: subscription.planId || null,
            planName: planName,
            status: 'success',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            billingPeriod: {
              from: admin.firestore.Timestamp.fromDate(lastMonth),
              to: now,
            },
          });

          // Update subscription
          const nextPayment = new Date(today);
          nextPayment.setDate(nextPayment.getDate() + 30);

          await db.collection('subscriptions').doc(userId).update({
            totalPaid: admin.firestore.FieldValue.increment(totalDue),
            lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
            lastPaymentAmount: totalDue,
            nextPaymentDate: admin.firestore.Timestamp.fromDate(nextPayment),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            failedPaymentAttempts: 0, // Reset on successful payment
          });

          console.log(`✓ Successfully billed user ${userId} (${facilityName}): ₦${totalDue.toFixed(2)}`);

          return { userId, status: 'success', amount: totalDue };

        } catch (error) {
          console.error(`Error processing billing for user ${userId}:`, error);
          return { userId, status: 'error', message: error.message };
        }
      });

      const results = await Promise.allSettled(billingPromises);
      
      const summary = {
        total: results.length,
        successful: results.filter(r => r.status === 'fulfilled' && r.value.status === 'success').length,
        failed: results.filter(r => r.status === 'rejected' || (r.status === 'fulfilled' && r.value.status !== 'success')).length,
      };

      console.log('Billing process completed:', summary);

      return null;
    } catch (error) {
      console.error('Fatal error in billing process:', error);
      throw error;
    }
  });

/**
 * Handle insufficient balance scenario
 * Sends warnings, suspends after grace period
 */
async function handleInsufficientBalance(db, userId, facilityName, amountDue, currentBalance, subscription) {
  const failedAttempts = (subscription.failedPaymentAttempts || 0) + 1;
  const gracePeriod = 7; // 7 days grace period

  // Log failed payment
  await db.collection('subscription_payments').add({
    userId: userId,
    type: 'monthly_billing',
    amount: amountDue,
    status: 'failed',
    failureReason: 'insufficient_balance',
    requiredBalance: amountDue,
    currentBalance: currentBalance,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Update subscription with failed attempt
  const updateData = {
    failedPaymentAttempts: failedAttempts,
    lastFailedPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Suspend after grace period (7 failed attempts = 7 days)
  if (failedAttempts >= gracePeriod) {
    updateData.isActive = false;
    updateData.suspendedAt = admin.firestore.FieldValue.serverTimestamp();
    updateData.suspensionReason = 'insufficient_balance';

    console.warn(`⚠ Subscription suspended for user ${userId} (${facilityName}) after ${failedAttempts} failed attempts`);

    // Send suspension notification
    await sendNotification(db, userId, {
      title: 'Subscription Suspended',
      message: `Your subscription has been suspended due to insufficient balance. Please add ₦${amountDue.toFixed(2)} to your wallet to reactivate.`,
      type: 'subscription_suspended',
      priority: 'high',
    });
  } else {
    // Send warning notification
    const daysLeft = gracePeriod - failedAttempts;
    console.warn(`⚠ Payment failed for user ${userId} (${facilityName}). Attempt ${failedAttempts}/${gracePeriod}. ${daysLeft} days left`);

    await sendNotification(db, userId, {
      title: 'Payment Failed - Action Required',
      message: `Subscription payment failed. Please add ₦${amountDue.toFixed(2)} to your wallet. ${daysLeft} day(s) remaining before suspension.`,
      type: 'payment_failed',
      priority: 'high',
    });
  }

  await db.collection('subscriptions').doc(userId).update(updateData);

  return { 
    userId, 
    status: 'insufficient_balance', 
    attempts: failedAttempts, 
    suspended: failedAttempts >= gracePeriod 
  };
}

/**
 * Send notification to facility
 */
async function sendNotification(db, userId, notification) {
  try {
    await db.collection('notifications').add({
      userId: userId,
      title: notification.title,
      message: notification.message,
      type: notification.type,
      priority: notification.priority || 'normal',
      read: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error(`Failed to send notification to user ${userId}:`, error);
  }
}

/**
 * Manual trigger for testing - can be called via HTTP
 */
exports.triggerSubscriptionBilling = functions.https.onCall(async (data, context) => {
  // Only allow admin users
  if (!context.auth || context.auth.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can trigger manual billing');
  }

  console.log('Manual billing triggered by admin:', context.auth.uid);

  // Reuse the same logic
  return exports.processSubscriptionBilling.run();
});
