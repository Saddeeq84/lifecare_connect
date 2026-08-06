const functions = require('firebase-functions');
const fetch = require('node-fetch');
const admin = require('firebase-admin');
const cors = require('cors')({
  origin: [
    'https://lifecare-connect.web.app',
    'https://lifecare-connect.firebaseapp.com',
    'http://localhost:8080',
    'http://localhost:5000',
    'http://localhost:3000',
    /^http:\/\/localhost:\d+$/,  // Allow any localhost port
  ],
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true,
});

const PAYSTACK_SECRET_KEY = functions.config().paystack.secret_key;
const { checkWithdrawalFeasibility, getPaystackBalance } = require('./withdrawal_reserve_manager');

// Helper: Create or get Paystack recipient code for a provider
async function getOrCreateRecipient({ accountNumber, bankCode, accountName }) {
  console.log('📝 Creating recipient with details:', { accountNumber, bankCode, accountName });
  console.log('   Account Number Length:', accountNumber.length);
  console.log('   Account Number Type:', typeof accountNumber);
  
  // Ensure account number is a string and trim any whitespace
  const cleanAccountNumber = String(accountNumber).trim();
  const cleanBankCode = String(bankCode).trim();
  
  console.log('   Clean Account Number:', cleanAccountNumber, '(length:', cleanAccountNumber.length + ')');
  console.log('   Clean Bank Code:', cleanBankCode);
  
  // First, verify the account number with Paystack
  const verifyUrl = `https://api.paystack.co/bank/resolve?account_number=${cleanAccountNumber}&bank_code=${cleanBankCode}`;
  console.log('🔍 Verifying account with Paystack API');
  console.log('   URL:', verifyUrl);
  
  try {
    const verifyResponse = await fetch(verifyUrl, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
    });
    
    console.log('   Response Status:', verifyResponse.status);
    console.log('   Response OK:', verifyResponse.ok);
    
    const verifyData = await verifyResponse.json();
    console.log('✅ Account verification result:', JSON.stringify(verifyData, null, 2));
    
    // Check if using test key
    const isTestMode = PAYSTACK_SECRET_KEY.startsWith('sk_test_');
    console.log(`🔑 API Key Mode: ${isTestMode ? 'TEST' : 'LIVE'}`);
    
    if (!verifyData.status) {
      const errorMsg = verifyData.message || 'Cannot resolve account. Please verify bank details.';
      console.error('❌ Account verification failed:', errorMsg);
      console.error('   Account Number:', cleanAccountNumber);
      console.error('   Bank Code:', cleanBankCode);
      console.error('   Account Name (provided):', accountName);
      console.error('   Full API Response:', JSON.stringify(verifyData, null, 2));
      
      // Provide detailed error message
      let detailedError = `Account verification failed: ${errorMsg}\n\n`;
      detailedError += `Details:\n`;
      detailedError += `- Account Number: ${cleanAccountNumber} (${cleanAccountNumber.length} digits)\n`;
      detailedError += `- Bank Code: ${cleanBankCode}\n`;
      detailedError += `- Mode: ${isTestMode ? 'TEST' : 'LIVE'}\n\n`;
      detailedError += `Possible reasons:\n`;
      detailedError += `1. Account number may be incorrect\n`;
      detailedError += `2. Account may not be active\n`;
      detailedError += `3. Bank's service may be temporarily unavailable\n`;
      detailedError += `4. There may be restrictions on this account type\n\n`;
      detailedError += `Please double-check your account number and try again.\n`;
      detailedError += `If the problem persists, please contact your bank or try another account.`;
      
      throw new Error(detailedError);
    }
    
    // Use the verified account name from Paystack
    const verifiedAccountName = verifyData.data?.account_name || accountName;
    console.log('✅ Verified account name:', verifiedAccountName);
    console.log('   Account verification successful!');
    
    // In production, cache recipientCode in Firestore for each provider
    console.log('📝 Creating transfer recipient...');
    const response = await fetch('https://api.paystack.co/transferrecipient', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        type: 'nuban',
        name: verifiedAccountName,
        account_number: cleanAccountNumber,
        bank_code: cleanBankCode,
        currency: 'NGN',
      }),
    });
    
    const data = await response.json();
    console.log('📦 Recipient creation result:', JSON.stringify(data, null, 2));
    
    if (data.status && data.data && data.data.recipient_code) {
      console.log('✅ Recipient created successfully:', data.data.recipient_code);
      return data.data.recipient_code;
    } else {
      const errorMsg = data.message || 'Failed to create recipient';
      console.error('❌ Recipient creation failed:', errorMsg);
      throw new Error(`Failed to create transfer recipient: ${errorMsg}`);
    }
  } catch (error) {
    console.error('❌ Exception during account verification/recipient creation:', error);
    throw error;
  }
}

// Callable function for Flutter app
exports.paystackTransfer = functions.https.onCall(async (data, context) => {
  const { userId, amount, accountNumber, bankCode, accountName, withdrawalId, isAdminApproval } = data;
  
  if (!userId || !amount || !accountNumber || !bankCode || !accountName || !withdrawalId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }
  
  try {
    console.log(`💸 Processing withdrawal for ${userId}: ₦${amount}`);
    console.log(`📋 Bank details: ${bankCode} - ${accountNumber} (${accountName})`);
    console.log(`🔍 Is Admin Approval: ${isAdminApproval}`);
    
    // Determine user type for better logging
    let userType = 'unknown';
    let userRole = null;
    
    // Try to get user role from withdrawal document first
    try {
      const withdrawalDoc = await admin.firestore().collection('withdrawals').doc(withdrawalId).get();
      userRole = withdrawalDoc.data()?.userRole || withdrawalDoc.data()?.role;
      
      if (userRole === 'facility') {
        userType = 'facility';
      } else if (userRole === 'admin' || userId === 'admin_wallet' || userId.startsWith('admin')) {
        userType = 'admin';
      } else if (userRole) {
        userType = userRole; // doctor, chw, etc.
      }
    } catch (e) {
      console.log(`⚠️ Could not determine user role from withdrawal: ${e.message}`);
      
      // Fallback: check if it's admin by userId
      if (userId === 'admin_wallet' || userId.startsWith('admin')) {
        userType = 'admin';
        userRole = 'admin';
      }
    }
    console.log(`👤 User type: ${userType}, User role: ${userRole}`);
    
    // 0. PRE-CHECK: Verify Paystack has sufficient balance for this withdrawal
    console.log(`🏦 Pre-checking Paystack balance feasibility...`);
    try {
      const feasibility = await checkWithdrawalFeasibility(amount);
      console.log(`💰 Paystack Balance Check:`, feasibility);
      
      if (!feasibility.canProcess) {
        const errorMsg = `Insufficient Paystack balance for withdrawal. Available: ₦${feasibility.availableForWithdrawal.toFixed(2)}, Required: ₦${amount.toFixed(2)}, Shortfall: ₦${feasibility.shortfall.toFixed(2)}`;
        console.error(`❌ ${errorMsg}`);
        
        // Update withdrawal status to indicate balance issue
        await admin.firestore().collection('withdrawals').doc(withdrawalId).update({
          status: 'paystack_insufficient_balance',
          errorReason: errorMsg,
          paystackBalanceCheck: feasibility,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        throw new functions.https.HttpsError('failed-precondition', 
          `Organization Paystack balance insufficient. Admin needs to transfer ₦${feasibility.shortfall.toFixed(2)} from bank to Paystack balance before processing withdrawals.`
        );
      }
      console.log(`✅ Paystack balance check passed - proceeding with withdrawal`);
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        throw error; // Re-throw our custom error
      }
      console.error(`⚠️ Could not verify Paystack balance, proceeding anyway: ${error.message}`);
      // Continue with existing flow if balance check fails
    }
    
    // For both admin approvals and user withdrawals: 
    // Check if amount was already deducted during request submission
    // If so, skip wallet deduction to prevent double deduction
    
    // 1. Get withdrawal document to check if amount was already deducted
    const withdrawalDoc = await admin.firestore().collection('withdrawals').doc(withdrawalId).get();
    const withdrawalData = withdrawalDoc.data() || {};
    const amountAlreadyDeducted = withdrawalData.amountDeducted === true;
    
    console.log(`💰 Amount already deducted at request time: ${amountAlreadyDeducted}`);
    
    // 2. Check user's wallet balance
    const userWalletRef = admin.firestore().collection('wallets').doc(userId);
    const walletDoc = await userWalletRef.get();
    const currentBalance = walletDoc.data()?.balance || 0;
    
    console.log(`💰 ${userType.toUpperCase()} wallet balance (${userId}): ₦${currentBalance}`);
    
    // 3. If amount not already deducted (old withdrawals), perform balance check and deduction
    if (!amountAlreadyDeducted) {
      console.log(`⚠️ Legacy withdrawal - performing balance check and deduction`);
      
      // Check available balance (minus escrow for non-admin users)
      let availableBalance = currentBalance;
      
      console.log(`🔍 Checking user type for escrow calculation...`);
      console.log(`🔍 userId: ${userId}`);
      console.log(`🔍 userType: ${userType}`);
      console.log(`🔍 userRole: ${userRole}`);
      
      // Facility admins and main admins don't need escrow calculation
      const isAdminOrFacility = userType === 'admin' || userType === 'facility' || 
                                 userId === 'admin_wallet' || userId.startsWith('admin');
      
      if (!isAdminOrFacility) {
        console.log(`📊 Calculating escrow for ${userType.toUpperCase()} (${userId})...`);
        
        // For service providers (doctors, CHWs), subtract escrow (pending payments)
        const pendingPaymentsQuery = await admin.firestore().collection('pendingPayments')
          .where('providerId', '==', userId)
          .where('status', '==', 'held')
          .get();
        
        console.log(`🔍 Found ${pendingPaymentsQuery.docs.length} pending payment documents`);
        
        let totalEscrow = 0;
        pendingPaymentsQuery.forEach(doc => {
          const data = doc.data();
          const providerShare = data.providerShare || 0;
          console.log(`📋 Pending payment ${doc.id}: ₦${providerShare} (status: ${data.status})`);
          totalEscrow += providerShare;
        });
        
        availableBalance = currentBalance - totalEscrow;
        console.log(`🔒 ${userType.toUpperCase()} - Total Balance: ₦${currentBalance}`);
        console.log(`🔒 ${userType.toUpperCase()} - Escrow amount: ₦${totalEscrow}`);
        console.log(`🔒 ${userType.toUpperCase()} - Available: ₦${availableBalance}`);
        
        if (isAdminApproval) {
          console.log(`👑 Admin approving withdrawal for ${userType.toUpperCase()} - checking ${userType}'s available balance`);
        }
      } else {
        console.log(`👑 ${userType.toUpperCase()} user - using full balance: ₦${availableBalance}`);
      }
      
      if (availableBalance < amount) {
        console.error(`❌ INSUFFICIENT BALANCE:`);
        console.error(`   - User ID: ${userId}`);
        console.error(`   - User Type: ${userType.toUpperCase()}`);
        console.error(`   - Current Balance: ₦${currentBalance}`);
        console.error(`   - Available Balance: ₦${availableBalance}`);
        console.error(`   - Requested Amount: ₦${amount}`);
        console.error(`   - Is Admin Approval? ${isAdminApproval} (type: ${typeof isAdminApproval})`);
        
        const errorMessage = isAdminApproval 
          ? `${userType.toUpperCase()} does not have sufficient balance. Available: ₦${availableBalance}, Requested: ₦${amount}`
          : `Your balance is not enough to fulfil this request. Available: ₦${availableBalance}, Requested: ₦${amount}`;
        
        console.error(`❌ Error message to be thrown: "${errorMessage}"`);
        throw new functions.https.HttpsError('failed-precondition', errorMessage);
      }
    } else {
      console.log(`✅ Amount already deducted during request - skipping balance check and deduction`);
    }
    
    // 2. Create or get recipient code (with account verification)
    const recipientCode = await getOrCreateRecipient({ accountNumber, bankCode, accountName });
    console.log(`✅ Recipient code obtained: ${recipientCode}`);
    
    // 3. Deduct from wallet only if not already deducted during request
    if (!amountAlreadyDeducted) {
      console.log(`💸 Deducting ₦${amount} from wallet (legacy withdrawal)`);
      await admin.firestore().runTransaction(async (transaction) => {
        const walletSnapshot = await transaction.get(userWalletRef);
        const balance = walletSnapshot.data()?.balance || 0;
        
        if (balance < amount) {
          throw new Error('Insufficient balance at transaction time');
        }
        
        const transactionDescription = isAdminApproval 
          ? `Withdrawal to ${accountName} (${accountNumber}) - Admin Approved`
          : `Withdrawal to ${accountName} (${accountNumber})`;
        
        transaction.update(userWalletRef, {
          balance: balance - amount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactions: admin.firestore.FieldValue.arrayUnion({
            type: 'withdrawal',
            amount: amount,
            description: transactionDescription,
            timestamp: new Date().toISOString(),
            withdrawalId: withdrawalId,
            status: 'processing',
            userType: userType, // Add user type for better tracking
          }),
        });
        
        console.log(`💸 Deducted ₦${amount} from ${userType.toUpperCase()} wallet ${userId} (${balance} → ${balance - amount})`);
      });
      
      console.log(`✅ Deducted ₦${amount} from wallet`);
    } else {
      console.log(`✅ Skipping wallet deduction - amount already deducted during request`);
      
      // Update the existing withdrawal_request transaction to show it's now processing
      await admin.firestore().runTransaction(async (transaction) => {
        const walletSnapshot = await transaction.get(userWalletRef);
        const walletData = walletSnapshot.data() || {};
        const transactions = walletData.transactions || [];
        
        // Find the withdrawal_request transaction and update it
        const updatedTransactions = transactions.map(tx => {
          if (tx.withdrawalId === withdrawalId && tx.type === 'withdrawal_request') {
            return {
              ...tx,
              type: 'withdrawal',
              status: 'processing',
              description: `Withdrawal to ${accountName} (${accountNumber}) - Processing`
            };
          }
          return tx;
        });
        
        transaction.update(userWalletRef, {
          transactions: updatedTransactions,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        console.log(`📝 Updated withdrawal transaction status to processing`);
      });
    }
    
    // 4. Initiate PIN-free transfer with enhanced configuration
    const transferResp = await fetch('https://api.paystack.co/transfer', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        'X-Transfer-Type': 'auto', // Signal for automatic processing
      },
      body: JSON.stringify({
        source: 'balance',
        amount: Math.round(amount * 100), // Paystack expects kobo
        recipient: recipientCode,
        reason: `LifeCare ${userType.toUpperCase()} withdrawal - ${withdrawalId}`,
        currency: 'NGN',
        reference: `lifecare_${withdrawalId}_${Date.now()}`,
        metadata: {
          withdrawal_id: withdrawalId,
          user_id: userId,
          user_type: userType,
          app_name: 'LifeCare Connect',
          auto_approved: true,
          pin_bypass_enabled: true,
          timestamp: new Date().toISOString()
        }
      }),
    });
    
    const transferData = await transferResp.json();
    console.log('📦 Paystack transfer response:', transferData);
    
    if (transferData.status) {
      // Transfer successful - mark as completed
      await admin.firestore().collection('withdrawals').doc(withdrawalId).update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        paystackTransfer: transferData.data,
        transferCode: transferData.data?.transfer_code,
        transferReference: transferData.data?.reference,
      });
      
      console.log(`✅ Withdrawal ${withdrawalId} completed successfully`);
      
      return { 
        success: true, 
        transfer: transferData.data,
        message: 'Withdrawal processed successfully',
        walletDeducted: true
      };
    } else {
      // Transfer failed - refund the wallet only if amount was deducted
      console.error('❌ Paystack transfer failed:', transferData.message);
      
      if (amountAlreadyDeducted || !amountAlreadyDeducted) {
        // Always refund because either:
        // 1. Amount was deducted during request (new flow)
        // 2. Amount was deducted during transfer (legacy flow)
        console.log(`🔄 Refunding ₦${amount} due to transfer failure`);
        
        await admin.firestore().runTransaction(async (transaction) => {
          const walletSnapshot = await transaction.get(userWalletRef);
          const balance = walletSnapshot.data()?.balance || 0;
          
          transaction.update(userWalletRef, {
            balance: balance + amount, // Refund
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            transactions: admin.firestore.FieldValue.arrayUnion({
              type: 'refund',
              amount: amount,
              description: `Withdrawal refund - Transfer failed: ${transferData.message}`,
              timestamp: new Date().toISOString(),
              withdrawalId: withdrawalId,
            }),
          });
          
          console.log(`✅ Refunded ₦${amount} to ${userType.toUpperCase()} wallet ${userId} (${balance} → ${balance + amount})`);
        });
      } else {
        console.log(`ℹ️ No refund needed - amount was not deducted`);
      }
      
      await admin.firestore().collection('withdrawals').doc(withdrawalId).update({
        status: 'failed',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        failureReason: transferData.message || 'Transfer failed',
      });
      
      console.log('✅ Wallet refunded due to transfer failure');
      
      throw new functions.https.HttpsError('internal', transferData.message || 'Transfer failed');
    }
  } catch (err) {
    console.error('❌ Withdrawal error:', err.message);
    
    // If error occurred after wallet deduction, try to refund
    // Check if we need to refund based on whether amount was deducted
    try {
      const withdrawalDoc = await admin.firestore().collection('withdrawals').doc(withdrawalId).get();
      const amountAlreadyDeducted = withdrawalDoc.data()?.amountDeducted === true;
      
      if (amountAlreadyDeducted) {
        console.log(`🔄 Refunding ₦${amount} due to error (amount was deducted during request)`);
        
        const userWalletRef = admin.firestore().collection('wallets').doc(userId);
        const walletDoc = await userWalletRef.get();
        if (walletDoc.exists) {
          await admin.firestore().runTransaction(async (transaction) => {
            const walletSnapshot = await transaction.get(userWalletRef);
            const balance = walletSnapshot.data()?.balance || 0;
            
            transaction.update(userWalletRef, {
              balance: balance + amount, // Refund
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              transactions: admin.firestore.FieldValue.arrayUnion({
                type: 'refund',
                amount: amount,
                description: `Withdrawal refund - Error: ${err.message}`,
                timestamp: new Date().toISOString(),
                withdrawalId: withdrawalId,
              }),
            });
          });
          
          console.log('✅ Wallet refunded due to error');
        }
      } else {
        console.log(`ℹ️ No refund needed - amount was not deducted during request`);
      }
      
      await admin.firestore().collection('withdrawals').doc(withdrawalId).update({
        status: 'failed',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        failureReason: err.message,
      });
    } catch (refundErr) {
      console.error('❌ Failed to refund wallet:', refundErr);
    }
    
    throw new functions.https.HttpsError('internal', err.message || 'Withdrawal processing failed');
  }
});
