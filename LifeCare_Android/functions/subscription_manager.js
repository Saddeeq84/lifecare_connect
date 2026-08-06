// Subscription Management Functions
// Handles automatic 2.5% monthly deductions, warnings, and facility status management

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// Scheduled function to process monthly subscription payments (runs daily at 9 AM)
exports.processMonthlySubscriptions = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Africa/Lagos')
  .onRun(async (context) => {
    console.log('Starting monthly subscription processing...');
    
    try {
      const today = new Date();
      const facilities = await db.collection('subscriptions').get();
      
      for (const facilityDoc of facilities.docs) {
        const subscriptionData = facilityDoc.data();
        const facilityId = facilityDoc.id;
        
        // Skip if subscription is not active
        if (subscriptionData.status !== 'active') {
          continue;
        }
        
        const nextPaymentDate = subscriptionData.nextPaymentDate?.toDate();
        if (!nextPaymentDate || nextPaymentDate > today) {
          continue;
        }
        
        console.log(`Processing payment for facility: ${facilityId}`);
        await processSubscriptionPayment(facilityId, subscriptionData);
      }
      
      console.log('Monthly subscription processing completed');
    } catch (error) {
      console.error('Error processing monthly subscriptions:', error);
      throw error;
    }
  });

// Function to process individual subscription payment
async function processSubscriptionPayment(facilityId, subscriptionData) {
  try {
    // Calculate monthly earnings for the past 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const earningsQuery = await db.collection('transactions')
      .where('facilityId', '==', facilityId)
      .where('type', '==', 'earning')
      .where('createdAt', '>', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();
    
    let totalEarnings = 0;
    earningsQuery.forEach(doc => {
      const data = doc.data();
      totalEarnings += data.amount || 0;
    });
    
    const subscriptionAmount = totalEarnings * 0.025; // 2.5% of earnings
    
    if (subscriptionAmount <= 0) {
      console.log(`No subscription payment required for facility ${facilityId} (no earnings)`);
      await updateNextPaymentDate(facilityId);
      return;
    }
    
    // Get facility wallet balance
    const walletDoc = await db.collection('wallets').doc(facilityId).get();
    const walletData = walletDoc.data();
    const currentBalance = walletData?.balance || 0;
    
    if (currentBalance < subscriptionAmount) {
      console.log(`Insufficient balance for facility ${facilityId}. Required: ${subscriptionAmount}, Available: ${currentBalance}`);
      await handleInsufficientBalance(facilityId, subscriptionAmount, currentBalance);
      return;
    }
    
    // Process the payment
    await processPayment(facilityId, subscriptionAmount, totalEarnings);
    console.log(`Successfully processed payment for facility ${facilityId}: ₦${subscriptionAmount}`);
    
  } catch (error) {
    console.error(`Error processing payment for facility ${facilityId}:`, error);
    await recordFailedPayment(facilityId, error.message);
  }
}

// Process the actual payment transaction
async function processPayment(facilityId, subscriptionAmount, totalEarnings) {
  const batch = db.batch();
  
  try {
    // Deduct from facility wallet
    const facilityWalletRef = db.collection('wallets').doc(facilityId);
    batch.update(facilityWalletRef, {
      balance: admin.firestore.FieldValue.increment(-subscriptionAmount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Add to admin wallet (assuming admin ID is 'admin_wallet')
    const adminWalletRef = db.collection('wallets').doc('admin_wallet');
    batch.update(adminWalletRef, {
      balance: admin.firestore.FieldValue.increment(subscriptionAmount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Record facility transaction (deduction)
    const facilityTransactionRef = db.collection('transactions').doc();
    batch.set(facilityTransactionRef, {
      facilityId: facilityId,
      type: 'subscription_deduction',
      amount: -subscriptionAmount,
      description: 'Monthly subscription payment (2.5% of earnings)',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'completed'
    });
    
    // Record admin transaction (income)
    const adminTransactionRef = db.collection('transactions').doc();
    batch.set(adminTransactionRef, {
      facilityId: 'admin_wallet',
      type: 'subscription_income',
      amount: subscriptionAmount,
      description: `Subscription payment from facility ${facilityId}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'completed',
      sourceFacilityId: facilityId
    });
    
    // Record subscription payment
    const paymentRef = db.collection('subscription_payments').doc();
    batch.set(paymentRef, {
      facilityId: facilityId,
      amount: subscriptionAmount,
      monthlyEarnings: totalEarnings,
      subscriptionRate: 2.5,
      paymentDate: admin.firestore.FieldValue.serverTimestamp(),
      status: 'completed',
      paymentMethod: 'wallet_deduction'
    });
    
    // Update subscription record
    const subscriptionRef = db.collection('subscriptions').doc(facilityId);
    const nextPaymentDate = new Date();
    nextPaymentDate.setDate(nextPaymentDate.getDate() + 30);
    
    batch.update(subscriptionRef, {
      lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
      nextPaymentDate: admin.firestore.Timestamp.fromDate(nextPaymentDate),
      totalPaid: admin.firestore.FieldValue.increment(subscriptionAmount),
      warningsIssued: 0, // Reset warnings after successful payment
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await batch.commit();
    
  } catch (error) {
    console.error(`Error executing payment batch for facility ${facilityId}:`, error);
    throw error;
  }
}

// Handle insufficient balance scenario
async function handleInsufficientBalance(facilityId, requiredAmount, currentBalance) {
  try {
    const subscriptionRef = db.collection('subscriptions').doc(facilityId);
    const subscriptionDoc = await subscriptionRef.get();
    const subscriptionData = subscriptionDoc.data();
    
    const warningsIssued = subscriptionData.warningsIssued || 0;
    const newWarningsCount = warningsIssued + 1;
    
    // Record failed payment
    await db.collection('subscription_payments').add({
      facilityId: facilityId,
      amount: requiredAmount,
      paymentDate: admin.firestore.FieldValue.serverTimestamp(),
      status: 'failed',
      failureReason: 'insufficient_balance',
      requiredAmount: requiredAmount,
      availableBalance: currentBalance
    });
    
    // Update subscription with warning count
    await subscriptionRef.update({
      warningsIssued: newWarningsCount,
      lastWarningDate: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Disable facility after 3 warnings (3 failed payments)
    if (newWarningsCount >= 3) {
      await disableFacility(facilityId);
    } else {
      // Send warning notification
      await sendInsufficientBalanceWarning(facilityId, requiredAmount, currentBalance, newWarningsCount);
    }
    
  } catch (error) {
    console.error(`Error handling insufficient balance for facility ${facilityId}:`, error);
  }
}

// Disable facility after multiple failed payments
async function disableFacility(facilityId) {
  try {
    const batch = db.batch();
    
    // Update subscription status
    const subscriptionRef = db.collection('subscriptions').doc(facilityId);
    batch.update(subscriptionRef, {
      status: 'disabled',
      disabledAt: admin.firestore.FieldValue.serverTimestamp(),
      disabledReason: 'subscription_payment_failure',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Update facility status in users collection
    const facilityRef = db.collection('users').doc(facilityId);
    batch.update(facilityRef, {
      isActive: false,
      disabledAt: admin.firestore.FieldValue.serverTimestamp(),
      disabledReason: 'subscription_payment_failure',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await batch.commit();
    
    // Send facility disabled notification
    await sendFacilityDisabledNotification(facilityId);
    
    console.log(`Facility ${facilityId} has been disabled due to subscription payment failure`);
    
  } catch (error) {
    console.error(`Error disabling facility ${facilityId}:`, error);
  }
}

// Send insufficient balance warning
async function sendInsufficientBalanceWarning(facilityId, requiredAmount, currentBalance, warningNumber) {
  try {
    // Get facility details from users collection
    const facilityDoc = await db.collection('users').doc(facilityId).get();
    const facilityData = facilityDoc.data();
    
    const warningMessage = {
      title: `Subscription Payment Warning ${warningNumber}/3`,
      body: `Insufficient balance for monthly subscription. Required: ₦${requiredAmount.toFixed(2)}, Available: ₦${currentBalance.toFixed(2)}. Please top up your wallet to avoid service interruption.`,
      type: 'subscription_warning',
      facilityId: facilityId,
      facilityName: facilityData?.facilityName || 'Unknown Facility',
      requiredAmount: requiredAmount,
      currentBalance: currentBalance,
      warningNumber: warningNumber,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    };
    
    // Add notification for facility
    await db.collection('notifications').add({
      ...warningMessage,
      userId: facilityId,
      userType: 'facility'
    });
    
    // Add notification for admin
    await db.collection('notifications').add({
      ...warningMessage,
      userId: 'admin_wallet',
      userType: 'admin'
    });
    
  } catch (error) {
    console.error(`Error sending warning for facility ${facilityId}:`, error);
  }
}

// Send facility disabled notification
async function sendFacilityDisabledNotification(facilityId) {
  try {
    // Get facility details from users collection
    const facilityDoc = await db.collection('users').doc(facilityId).get();
    const facilityData = facilityDoc.data();
    
    const disabledMessage = {
      title: 'Facility Access Disabled',
      body: 'Your facility has been disabled due to repeated subscription payment failures. Please contact support to reactivate your account.',
      type: 'facility_disabled',
      facilityId: facilityId,
      facilityName: facilityData?.facilityName || 'Unknown Facility',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    };
    
    // Add notification for facility
    await db.collection('notifications').add({
      ...disabledMessage,
      userId: facilityId,
      userType: 'facility'
    });
    
    // Add notification for admin
    await db.collection('notifications').add({
      ...disabledMessage,
      userId: 'admin_wallet',
      userType: 'admin'
    });
    
  } catch (error) {
    console.error(`Error sending disabled notification for facility ${facilityId}:`, error);
  }
}

// Record failed payment
async function recordFailedPayment(facilityId, errorMessage) {
  try {
    await db.collection('subscription_payments').add({
      facilityId: facilityId,
      amount: 0,
      paymentDate: admin.firestore.FieldValue.serverTimestamp(),
      status: 'failed',
      failureReason: 'system_error',
      errorMessage: errorMessage
    });
  } catch (error) {
    console.error(`Error recording failed payment for facility ${facilityId}:`, error);
  }
}

// Update next payment date (when no payment is required)
async function updateNextPaymentDate(facilityId) {
  try {
    const nextPaymentDate = new Date();
    nextPaymentDate.setDate(nextPaymentDate.getDate() + 30);
    
    await db.collection('subscriptions').doc(facilityId).update({
      nextPaymentDate: admin.firestore.Timestamp.fromDate(nextPaymentDate),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (error) {
    console.error(`Error updating next payment date for facility ${facilityId}:`, error);
  }
}

// Scheduled function to send subscription warnings (runs daily at 8 AM)
exports.sendSubscriptionWarnings = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('Africa/Lagos')
  .onRun(async (context) => {
    console.log('Checking for upcoming subscription renewals...');
    
    try {
      const sevenDaysFromNow = new Date();
      sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);
      
      const subscriptions = await db.collection('subscriptions')
        .where('status', '==', 'active')
        .where('nextPaymentDate', '<=', admin.firestore.Timestamp.fromDate(sevenDaysFromNow))
        .get();
      
      for (const doc of subscriptions.docs) {
        const subscriptionData = doc.data();
        const facilityId = doc.id;
        const nextPaymentDate = subscriptionData.nextPaymentDate?.toDate();
        
        if (!nextPaymentDate) continue;
        
        const daysUntilPayment = Math.ceil((nextPaymentDate - new Date()) / (1000 * 60 * 60 * 24));
        
        if (daysUntilPayment <= 7 && daysUntilPayment > 0) {
          await sendRenewalWarning(facilityId, daysUntilPayment);
        }
      }
      
      console.log('Subscription warning check completed');
    } catch (error) {
      console.error('Error checking subscription warnings:', error);
    }
  });

// Send renewal warning
async function sendRenewalWarning(facilityId, daysUntilPayment) {
  try {
    // Get facility details from users collection
    const facilityDoc = await db.collection('users').doc(facilityId).get();
    const facilityData = facilityDoc.data();
    
    // Check if wallet has sufficient balance
    const walletDoc = await db.collection('wallets').doc(facilityId).get();
    const walletData = walletDoc.data();
    const currentBalance = walletData?.balance || 0;
    
    // Calculate estimated subscription amount based on recent earnings
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const earningsQuery = await db.collection('transactions')
      .where('facilityId', '==', facilityId)
      .where('type', '==', 'earning')
      .where('createdAt', '>', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();
    
    let estimatedEarnings = 0;
    earningsQuery.forEach(doc => {
      const data = doc.data();
      estimatedEarnings += data.amount || 0;
    });
    
    const estimatedSubscription = estimatedEarnings * 0.025;
    
    const warningMessage = {
      title: `Subscription Renewal in ${daysUntilPayment} day${daysUntilPayment === 1 ? '' : 's'}`,
      body: `Your subscription will renew automatically in ${daysUntilPayment} day${daysUntilPayment === 1 ? '' : 's'}. Estimated amount: ₦${estimatedSubscription.toFixed(2)}. Current wallet balance: ₦${currentBalance.toFixed(2)}.`,
      type: 'subscription_renewal_reminder',
      facilityId: facilityId,
      facilityName: facilityData?.facilityName || 'Unknown Facility',
      daysUntilRenewal: daysUntilPayment,
      estimatedAmount: estimatedSubscription,
      currentBalance: currentBalance,
      sufficientBalance: currentBalance >= estimatedSubscription,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    };
    
    // Add notification for facility
    await db.collection('notifications').add({
      ...warningMessage,
      userId: facilityId,
      userType: 'facility'
    });
    
  } catch (error) {
    console.error(`Error sending renewal warning for facility ${facilityId}:`, error);
  }
}

// HTTP function to manually process subscription for a specific facility (admin use)
exports.processSpecificSubscription = functions.https.onCall(async (data, context) => {
  // Check if the caller is an admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can manually process subscriptions');
  }
  
  const { facilityId } = data;
  
  if (!facilityId) {
    throw new functions.https.HttpsError('invalid-argument', 'Facility ID is required');
  }
  
  try {
    const subscriptionDoc = await db.collection('subscriptions').doc(facilityId).get();
    if (!subscriptionDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Subscription not found');
    }
    
    const subscriptionData = subscriptionDoc.data();
    await processSubscriptionPayment(facilityId, subscriptionData);
    
    return { success: true, message: 'Subscription processed successfully' };
  } catch (error) {
    console.error(`Error manually processing subscription for ${facilityId}:`, error);
    throw new functions.https.HttpsError('internal', `Error processing subscription: ${error.message}`);
  }
});

// HTTP function to reactivate a disabled facility (admin use)
exports.reactivateFacility = functions.https.onCall(async (data, context) => {
  // Check if the caller is an admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can reactivate facilities');
  }
  
  const { facilityId } = data;
  
  if (!facilityId) {
    throw new functions.https.HttpsError('invalid-argument', 'Facility ID is required');
  }
  
  try {
    const batch = db.batch();
    
    // Update subscription status
    const subscriptionRef = db.collection('subscriptions').doc(facilityId);
    batch.update(subscriptionRef, {
      status: 'active',
      warningsIssued: 0,
      reactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Update facility status in users collection
    const facilityRef = db.collection('users').doc(facilityId);
    batch.update(facilityRef, {
      isActive: true,
      reactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await batch.commit();
    
    return { success: true, message: 'Facility reactivated successfully' };
  } catch (error) {
    console.error(`Error reactivating facility ${facilityId}:`, error);
    throw new functions.https.HttpsError('internal', `Error reactivating facility: ${error.message}`);
  }
});