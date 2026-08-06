const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * AUTOMATIC WARD BILLING SYSTEM
 * 
 * This Cloud Function runs daily at midnight (00:00 UTC) to:
 * 1. Find all admitted in-patients with daily billing services
 * 2. Create billing records for accommodation and daily care services
 * 3. Automatically charge patient wallets for services rendered
 * 4. Update billing history and activity logs
 * 
 * Billing Types:
 * - Accommodation (beds): Charged daily at midnight
 * - Daily care services: Charged when marked as completed
 * - One-time services: Charged manually or on discharge
 */

// Scheduled function - runs daily at midnight UTC (1 AM WAT - West Africa Time)
exports.processAutomaticWardBilling = functions.pubsub
  .schedule('0 0 * * *') // Every day at midnight UTC
  .timeZone('Africa/Lagos') // West Africa Time Zone
  .onRun(async (context) => {
    console.log('🏥 Starting automatic ward billing process...');
    
    const db = admin.firestore();
    const batch = db.batch();
    const now = admin.firestore.Timestamp.now();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayStr = today.toISOString().split('T')[0]; // 'YYYY-MM-DD'
    
    try {
      // Get all admitted in-patients
      const inpatientsSnapshot = await db.collection('inpatients')
        .where('status', '==', 'admitted')
        .get();
      
      console.log(`📊 Found ${inpatientsSnapshot.size} admitted patients to process`);
      
      let billsCreated = 0;
      let chargesSuccessful = 0;
      let chargesFailed = 0;
      
      // Process each admitted patient
      for (const inpatientDoc of inpatientsSnapshot.docs) {
        const inpatient = inpatientDoc.data();
        const inpatientId = inpatientDoc.id;
        
        // Check if billing cycle is daily
        if (inpatient.billingCycle !== 'daily') {
          console.log(`⏭️  Skipping ${inpatient.patientName} - billing cycle is ${inpatient.billingCycle}`);
          continue;
        }
        
        // Check if already billed today
        const lastBillingDate = inpatient.lastBillingDate?.toDate();
        if (lastBillingDate) {
          const lastBillingStr = lastBillingDate.toISOString().split('T')[0];
          if (lastBillingStr === todayStr) {
            console.log(`✅ Already billed today: ${inpatient.patientName}`);
            continue;
          }
        }
        
        // Calculate days since admission or last billing
        const acceptedAt = inpatient.acceptedAt?.toDate() || new Date();
        const daysSinceAdmission = Math.floor((today - acceptedAt) / (1000 * 60 * 60 * 24));
        
        // Skip if admitted today (bill starting tomorrow)
        if (daysSinceAdmission < 1) {
          console.log(`⏭️  Patient ${inpatient.patientName} admitted today, billing starts tomorrow`);
          continue;
        }
        
        // Create billing record
        const billRef = db.collection('patient_bills').doc();
        const billData = {
          billId: billRef.id,
          facilityId: inpatient.facilityId,
          patientId: inpatient.patientId,
          patientName: inpatient.patientName || 'Unknown',
          inpatientDocId: inpatientId,
          serviceId: inpatient.wardServiceId,
          serviceName: inpatient.wardServiceName || 'Ward Accommodation',
          serviceCategory: inpatient.wardServiceCategory || 'Accommodation',
          billingCycle: 'daily',
          unitPrice: inpatient.chargePerNight || 0,
          quantity: 1, // One day
          totalAmount: inpatient.chargePerNight || 0,
          status: 'pending', // Will try to charge immediately
          billType: 'accommodation',
          billedAt: now,
          billedBy: 'system',
          billedByName: 'Automatic Billing System',
          billingDate: todayStr,
          dueDate: now,
          chargedAt: null,
          notes: `Daily accommodation charge - Day ${daysSinceAdmission}`,
          autoCharge: 'daily_if_admitted',
          createdAt: now,
        };
        
        batch.set(billRef, billData);
        billsCreated++;
        
        // Try to charge patient wallet immediately
        const walletRef = db.collection('wallets').doc(inpatient.patientId);
        const walletDoc = await walletRef.get();
        
        if (walletDoc.exists) {
          const walletData = walletDoc.data();
          const currentBalance = walletData.balance || 0;
          const chargeAmount = inpatient.chargePerNight || 0;
          
          if (currentBalance >= chargeAmount) {
            // Sufficient balance - charge wallet
            const newBalance = currentBalance - chargeAmount;
            
            batch.update(walletRef, {
              balance: newBalance,
              updatedAt: now,
            });
            
            // Create transaction record
            const transactionRef = db.collection('wallets').doc(inpatient.patientId)
              .collection('transactions').doc();
            
            batch.set(transactionRef, {
              transactionId: transactionRef.id,
              type: 'debit',
              amount: chargeAmount,
              description: `Ward accommodation - ${inpatient.wardServiceName} (Day ${daysSinceAdmission})`,
              billId: billRef.id,
              category: 'ward_accommodation',
              timestamp: now,
              balanceBefore: currentBalance,
              balanceAfter: newBalance,
              status: 'completed',
              processedBy: 'system',
            });
            
            // Update bill status to charged
            batch.update(billRef, {
              status: 'charged',
              chargedAt: now,
              walletBalanceBefore: currentBalance,
              walletBalanceAfter: newBalance,
            });
            
            // Update inpatient total charged amount
            const totalCharged = (inpatient.totalChargedAmount || 0) + chargeAmount;
            const chargeCount = (inpatient.chargeCount || 0) + 1;
            
            batch.update(inpatientDoc.ref, {
              totalChargedAmount: totalCharged,
              chargeCount: chargeCount,
              lastBillingDate: now,
              lastChargeAmount: chargeAmount,
              updatedAt: now,
            });
            
            // Create billing activity log
            const activityRef = db.collection('inpatients').doc(inpatientId)
              .collection('billing_activities').doc();
            
            batch.set(activityRef, {
              activityId: activityRef.id,
              type: 'daily_charge',
              description: `Daily accommodation charged: ₦${chargeAmount.toFixed(0)} (Day ${daysSinceAdmission})`,
              serviceId: inpatient.wardServiceId,
              serviceName: inpatient.wardServiceName,
              amount: chargeAmount,
              billId: billRef.id,
              performedBy: 'system',
              performedByName: 'Automatic Billing',
              timestamp: now,
              status: 'success',
            });
            
            chargesSuccessful++;
            console.log(`✅ Charged ${inpatient.patientName}: ₦${chargeAmount} (Balance: ₦${currentBalance} → ₦${newBalance})`);
            
          } else {
            // Insufficient balance - mark bill as pending
            console.log(`⚠️  Insufficient balance for ${inpatient.patientName}: ₦${currentBalance} < ₦${chargeAmount}`);
            
            // Create notification/alert for low balance
            const activityRef = db.collection('inpatients').doc(inpatientId)
              .collection('billing_activities').doc();
            
            batch.set(activityRef, {
              activityId: activityRef.id,
              type: 'charge_failed',
              description: `Charge failed - Insufficient balance. Required: ₦${chargeAmount}, Available: ₦${currentBalance}`,
              serviceId: inpatient.wardServiceId,
              serviceName: inpatient.wardServiceName,
              amount: chargeAmount,
              billId: billRef.id,
              performedBy: 'system',
              performedByName: 'Automatic Billing',
              timestamp: now,
              status: 'failed',
              reason: 'insufficient_balance',
            });
            
            // Update inpatient with last billing attempt
            batch.update(inpatientDoc.ref, {
              lastBillingDate: now,
              lastBillingStatus: 'failed',
              lastBillingError: 'insufficient_balance',
              pendingBillAmount: (inpatient.pendingBillAmount || 0) + chargeAmount,
              updatedAt: now,
            });
            
            chargesFailed++;
          }
        } else {
          // No wallet found
          console.log(`❌ No wallet found for ${inpatient.patientName}`);
          
          const activityRef = db.collection('inpatients').doc(inpatientId)
            .collection('billing_activities').doc();
          
          batch.set(activityRef, {
            activityId: activityRef.id,
            type: 'charge_failed',
            description: `Charge failed - Wallet not found`,
            serviceId: inpatient.wardServiceId,
            serviceName: inpatient.wardServiceName,
            amount: inpatient.chargePerNight || 0,
            billId: billRef.id,
            performedBy: 'system',
            performedByName: 'Automatic Billing',
            timestamp: now,
            status: 'failed',
            reason: 'no_wallet',
          });
          
          chargesFailed++;
        }
      }
      
      // Commit all changes
      if (billsCreated > 0) {
        await batch.commit();
        console.log(`✅ Batch committed successfully`);
      }
      
      console.log(`\n📊 BILLING SUMMARY:`);
      console.log(`   Bills Created: ${billsCreated}`);
      console.log(`   Charges Successful: ${chargesSuccessful}`);
      console.log(`   Charges Failed: ${chargesFailed}`);
      console.log(`   Total Processed: ${inpatientsSnapshot.size} patients`);
      
      return {
        success: true,
        billsCreated,
        chargesSuccessful,
        chargesFailed,
        totalProcessed: inpatientsSnapshot.size,
        timestamp: now.toDate().toISOString(),
      };
      
    } catch (error) {
      console.error('❌ Error processing automatic billing:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });


/**
 * MANUAL TRIGGER for testing - Call this HTTP function to test billing
 * URL: https://[region]-[project-id].cloudfunctions.net/triggerManualWardBilling
 */
exports.triggerManualWardBilling = functions.https.onRequest(async (req, res) => {
  console.log('🧪 Manual billing trigger called');
  
  try {
    // Call the same logic as scheduled function
    const result = await exports.processAutomaticWardBilling.run({});
    
    res.status(200).json({
      success: true,
      message: 'Manual billing completed',
      ...result,
    });
  } catch (error) {
    console.error('Error in manual billing:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});


/**
 * CHARGE PENDING BILLS - Retry failed charges when wallet is topped up
 * This can be called from the client or triggered when wallet balance increases
 */
exports.chargePendingBills = functions.https.onCall(async (data, context) => {
  const { patientId } = data;
  
  if (!patientId) {
    throw new functions.https.HttpsError('invalid-argument', 'Patient ID is required');
  }
  
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  
  try {
    // Get pending bills for this patient
    const pendingBillsSnapshot = await db.collection('patient_bills')
      .where('patientId', '==', patientId)
      .where('status', '==', 'pending')
      .orderBy('billedAt', 'asc')
      .get();
    
    if (pendingBillsSnapshot.empty) {
      return {
        success: true,
        message: 'No pending bills found',
        billsCharged: 0,
      };
    }
    
    // Get wallet
    const walletRef = db.collection('wallets').doc(patientId);
    const walletDoc = await walletRef.get();
    
    if (!walletDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Patient wallet not found');
    }
    
    const walletData = walletDoc.data();
    let currentBalance = walletData.balance || 0;
    
    const batch = db.batch();
    let billsCharged = 0;
    let totalCharged = 0;
    
    // Process each pending bill
    for (const billDoc of pendingBillsSnapshot.docs) {
      const bill = billDoc.data();
      const chargeAmount = bill.totalAmount || 0;
      
      if (currentBalance >= chargeAmount) {
        // Charge the bill
        const newBalance = currentBalance - chargeAmount;
        
        // Update bill status
        batch.update(billDoc.ref, {
          status: 'charged',
          chargedAt: now,
          walletBalanceBefore: currentBalance,
          walletBalanceAfter: newBalance,
          updatedAt: now,
        });
        
        // Create transaction
        const transactionRef = db.collection('wallets').doc(patientId)
          .collection('transactions').doc();
        
        batch.set(transactionRef, {
          transactionId: transactionRef.id,
          type: 'debit',
          amount: chargeAmount,
          description: bill.serviceName || 'Ward service',
          billId: billDoc.id,
          category: bill.billType || 'ward_service',
          timestamp: now,
          balanceBefore: currentBalance,
          balanceAfter: newBalance,
          status: 'completed',
          processedBy: 'system',
        });
        
        currentBalance = newBalance;
        billsCharged++;
        totalCharged += chargeAmount;
        
      } else {
        // Not enough balance, stop processing
        break;
      }
    }
    
    // Update wallet balance
    if (billsCharged > 0) {
      batch.update(walletRef, {
        balance: currentBalance,
        updatedAt: now,
      });
      
      await batch.commit();
      
      return {
        success: true,
        message: `Successfully charged ${billsCharged} pending bills`,
        billsCharged,
        totalCharged,
        remainingBalance: currentBalance,
      };
    }
    
    return {
      success: false,
      message: 'Insufficient balance to charge any pending bills',
      billsCharged: 0,
    };
    
  } catch (error) {
    console.error('Error charging pending bills:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
