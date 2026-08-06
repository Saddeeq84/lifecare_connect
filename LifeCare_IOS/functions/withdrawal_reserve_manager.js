const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

// Withdrawal Reserve Management
// This function helps calculate and manage the balance reserve needed for pending withdrawals

/**
 * Calculate total amount needed as reserve for pending/approved withdrawals
 */
async function calculateWithdrawalReserve() {
  try {
    const pendingWithdrawals = await admin.firestore()
      .collection('withdrawals')
      .where('status', 'in', ['pending', 'approved'])
      .get();
    
    let totalReserveNeeded = 0;
    let withdrawalDetails = [];
    
    pendingWithdrawals.forEach(doc => {
      const data = doc.data();
      const amount = data.amount || 0;
      totalReserveNeeded += amount;
      
      withdrawalDetails.push({
        id: doc.id,
        userId: data.userId,
        amount: amount,
        status: data.status,
        accountName: data.accountName,
        requestedAt: data.requestedAt?.toDate() || null
      });
    });
    
    return {
      totalReserveNeeded,
      pendingCount: pendingWithdrawals.size,
      withdrawalDetails
    };
  } catch (error) {
    console.error('Error calculating withdrawal reserve:', error);
    throw error;
  }
}

/**
 * Get current Paystack balance
 */
async function getPaystackBalance() {
  const PAYSTACK_SECRET_KEY = functions.config().paystack.secret_key;
  
  try {
    const response = await fetch('https://api.paystack.co/balance', {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
    });
    
    const data = await response.json();
    
    if (data.status) {
      // Paystack returns balance in kobo, convert to naira
      return {
        balance: data.data[0]?.balance / 100 || 0,
        currency: data.data[0]?.currency || 'NGN',
        available: data.data[0]?.balance / 100 || 0
      };
    } else {
      throw new Error(data.message || 'Failed to fetch Paystack balance');
    }
  } catch (error) {
    console.error('Error fetching Paystack balance:', error);
    throw error;
  }
}

/**
 * Check if withdrawal can be processed based on available balance
 */
async function checkWithdrawalFeasibility(withdrawalAmount) {
  try {
    const [paystackBalance, reserveInfo] = await Promise.all([
      getPaystackBalance(),
      calculateWithdrawalReserve()
    ]);
    
    // Calculate how much is available after accounting for existing pending withdrawals
    const availableForNewWithdrawals = paystackBalance.available - reserveInfo.totalReserveNeeded;
    
    return {
      canProcess: availableForNewWithdrawals >= withdrawalAmount,
      paystackBalance: paystackBalance.available,
      reserveNeeded: reserveInfo.totalReserveNeeded,
      availableForWithdrawal: availableForNewWithdrawals,
      shortfall: Math.max(0, withdrawalAmount - availableForNewWithdrawals),
      pendingWithdrawalsCount: reserveInfo.pendingCount
    };
  } catch (error) {
    console.error('Error checking withdrawal feasibility:', error);
    throw error;
  }
}

/**
 * Generate balance report for admin dashboard
 */
exports.getBalanceReport = functions.https.onCall(async (data, context) => {
  try {
    // Verify admin access
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    
    const [paystackBalance, reserveInfo] = await Promise.all([
      getPaystackBalance(),
      calculateWithdrawalReserve()
    ]);
    
    const availableForPayout = Math.max(0, paystackBalance.available - reserveInfo.totalReserveNeeded);
    
    return {
      success: true,
      timestamp: new Date().toISOString(),
      paystack: {
        totalBalance: paystackBalance.available,
        currency: paystackBalance.currency
      },
      withdrawals: {
        reserveNeeded: reserveInfo.totalReserveNeeded,
        pendingCount: reserveInfo.pendingCount,
        details: reserveInfo.withdrawalDetails
      },
      recommendations: {
        safeToTransferToBank: availableForPayout,
        shouldHoldInPaystack: reserveInfo.totalReserveNeeded,
        status: availableForPayout > 0 ? 'safe_to_payout' : 'hold_for_withdrawals'
      }
    };
  } catch (error) {
    console.error('Error generating balance report:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Check if a specific withdrawal can be processed (Callable version)
 */
exports.checkWithdrawalStatus = functions.https.onCall(async (data, context) => {
  const { withdrawalId, amount } = data;
  
  if (!withdrawalId || !amount) {
    throw new functions.https.HttpsError('invalid-argument', 'Withdrawal ID and amount required');
  }
  
  try {
    const feasibility = await checkWithdrawalFeasibility(amount);
    
    return {
      success: true,
      withdrawalId,
      amount,
      feasibility,
      recommendation: feasibility.canProcess 
        ? 'Withdrawal can be processed immediately'
        : `Need ₦${feasibility.shortfall.toFixed(2)} more in Paystack balance to process this withdrawal`
    };
  } catch (error) {
    console.error('Error checking withdrawal status:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Check if a specific withdrawal can be processed (HTTP version with CORS)
 * Updated for deployment
 */
exports.checkWithdrawalStatusHTTP = functions.https.onRequest(async (req, res) => {
  try {
    // Handle CORS
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    const { withdrawalId, amount } = req.method === 'GET' ? req.query : req.body;
    
    if (!withdrawalId || !amount) {
      res.status(400).json({ 
        success: false, 
        error: 'Withdrawal ID and amount required' 
      });
      return;
    }
    
    const feasibility = await checkWithdrawalFeasibility(parseFloat(amount));
    
    res.json({
      success: true,
      withdrawalId,
      amount: parseFloat(amount),
      feasibility,
      recommendation: feasibility.canProcess 
        ? 'Withdrawal can be processed immediately'
        : `Need ₦${feasibility.shortfall.toFixed(2)} more in Paystack balance to process this withdrawal`
    });
    
  } catch (error) {
    console.error('Error checking withdrawal status:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

/**
 * Helper function to fund Paystack balance from bank (manual process guidance)
 */
exports.getFundingGuidance = functions.https.onCall(async (data, context) => {
  try {
    // Verify admin access
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    
    const reserveInfo = await calculateWithdrawalReserve();
    const paystackBalance = await getPaystackBalance();
    
    const shortfall = Math.max(0, reserveInfo.totalReserveNeeded - paystackBalance.available);
    
    return {
      success: true,
      currentSituation: {
        paystackBalance: paystackBalance.available,
        pendingWithdrawals: reserveInfo.totalReserveNeeded,
        shortfall: shortfall
      },
      guidance: shortfall > 0 ? {
        action: 'FUNDING_REQUIRED',
        message: `You need to add ₦${shortfall.toFixed(2)} to your Paystack balance`,
        steps: [
          '1. Log in to your Paystack Dashboard',
          '2. Go to Settings > Preferences > Payouts',
          '3. Manually transfer funds from your bank to Paystack balance',
          `4. Transfer at least ₦${shortfall.toFixed(2)} to cover pending withdrawals`,
          '5. Return to this app and approve pending withdrawals'
        ]
      } : {
        action: 'SUFFICIENT_BALANCE',
        message: 'Your Paystack balance is sufficient for all pending withdrawals',
        availableForPayout: paystackBalance.available - reserveInfo.totalReserveNeeded
      }
    };
  } catch (error) {
    console.error('Error generating funding guidance:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

module.exports = {
  calculateWithdrawalReserve,
  getPaystackBalance,
  checkWithdrawalFeasibility
};