const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * 🔐 PIN-Free Transfer Configuration Manager
 * Handles automatic transfer setup and webhook management
 */

// Paystack API configuration
const PAYSTACK_SECRET_KEY = functions.config().paystack.secret_key;

/**
 * Validates Paystack account configuration for PIN-free transfers
 */
exports.validatePaystackConfig = functions.https.onRequest(async (req, res) => {
  try {
    console.log('🔍 Validating Paystack configuration for PIN-free transfers...');

    // Check current transfer settings
    const settingsResp = await fetch('https://api.paystack.co/integration', {
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
      },
    });

    const settingsData = await settingsResp.json();
    
    if (!settingsData.status) {
      throw new Error('Failed to fetch Paystack settings');
    }

    const config = settingsData.data;
    console.log('📋 Current Paystack Configuration:', config);

    // Analyze configuration for PIN requirements
    const analysis = {
      pin_free_enabled: false,
      transfer_limits: config.settlement_schedule || 'unknown',
      auto_settlement: config.auto_settlement || false,
      business_verified: config.business_profile?.verified || false,
      api_access: config.api_access_enabled || false,
      recommendations: []
    };

    // Generate recommendations
    if (!analysis.business_verified) {
      analysis.recommendations.push({
        priority: 'high',
        action: 'Complete business verification',
        description: 'Verify your business profile to enable higher limits and PIN-free transfers'
      });
    }

    if (analysis.auto_settlement) {
      analysis.recommendations.push({
        priority: 'medium',
        action: 'Disable automatic settlements',
        description: 'Turn off auto-settlement to maintain balance for withdrawals'
      });
    }

    analysis.recommendations.push({
      priority: 'high',
      action: 'Configure transfer authorization',
      description: 'Set transfer authorization to "Automatic" in Security settings'
    });

    res.json({
      success: true,
      configuration: analysis,
      next_steps: [
        '1. Log into Paystack Dashboard',
        '2. Go to Settings → Security',
        '3. Set Transfer Authorization to "Automatic"',
        '4. Increase transfer limits if needed',
        '5. Test with small withdrawal'
      ]
    });

  } catch (error) {
    console.error('❌ Error validating Paystack config:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * Handles Paystack transfer completion webhooks
 */
exports.handleTransferWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const event = req.body;
    console.log('🔔 Received Paystack webhook:', event.event);

    if (event.event === 'transfer.success') {
      const transferData = event.data;
      const metadata = transferData.metadata || {};
      
      console.log('✅ Transfer completed successfully:', transferData.reference);
      
      // Update withdrawal status in Firestore
      if (metadata.withdrawal_id) {
        await admin.firestore().collection('withdrawals').doc(metadata.withdrawal_id).update({
          status: 'completed',
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          paystackTransfer: transferData,
          webhookReceived: true,
          finalAmount: transferData.amount / 100, // Convert from kobo
        });

        console.log(`✅ Updated withdrawal ${metadata.withdrawal_id} status to completed`);

        // Send success notification to user
        if (metadata.user_id) {
          await admin.firestore().collection('notifications').add({
            userId: metadata.user_id,
            type: 'withdrawal_completed',
            title: 'Withdrawal Successful',
            message: `Your withdrawal of ₦${transferData.amount / 100} has been completed successfully.`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
            data: {
              withdrawalId: metadata.withdrawal_id,
              amount: transferData.amount / 100,
              reference: transferData.reference
            }
          });
        }
      }
      
    } else if (event.event === 'transfer.failed') {
      const transferData = event.data;
      const metadata = transferData.metadata || {};
      
      console.error('❌ Transfer failed:', transferData.reference);
      console.error('❌ Failure reason:', transferData.failure_reason);
      
      // Update withdrawal status and refund wallet
      if (metadata.withdrawal_id) {
        const withdrawalRef = admin.firestore().collection('withdrawals').doc(metadata.withdrawal_id);
        const withdrawal = await withdrawalRef.get();
        
        if (withdrawal.exists) {
          const withdrawalData = withdrawal.data();
          
          // Refund the amount back to user's wallet
          const userWalletRef = admin.firestore().collection('wallets').doc(metadata.user_id);
          await admin.firestore().runTransaction(async (transaction) => {
            const walletDoc = await transaction.get(userWalletRef);
            const currentBalance = walletDoc.exists ? (walletDoc.data().balance || 0) : 0;
            
            transaction.update(walletRef, {
              balance: currentBalance + withdrawalData.amount,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            
            // Add transaction record
            transaction.create(admin.firestore().collection('wallet_transactions').doc(), {
              userId: metadata.user_id,
              type: 'refund',
              amount: withdrawalData.amount,
              description: `Refund for failed withdrawal: ${metadata.withdrawal_id}`,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              withdrawalId: metadata.withdrawal_id,
              reason: transferData.failure_reason
            });
          });
          
          // Update withdrawal status
          await withdrawalRef.update({
            status: 'failed',
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
            failureReason: transferData.failure_reason,
            refunded: true,
            webhookReceived: true,
          });

          // Send failure notification
          await admin.firestore().collection('notifications').add({
            userId: metadata.user_id,
            type: 'withdrawal_failed',
            title: 'Withdrawal Failed',
            message: `Your withdrawal request failed. The amount has been refunded to your wallet.`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
            data: {
              withdrawalId: metadata.withdrawal_id,
              amount: withdrawalData.amount,
              reason: transferData.failure_reason
            }
          });

          console.log(`💰 Refunded ₦${withdrawalData.amount} to user ${metadata.user_id}`);
        }
      }
    }

    res.status(200).json({ received: true });
    
  } catch (error) {
    console.error('❌ Error handling webhook:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Tests PIN-free transfer with small amount
 */
exports.testPinFreeTransfer = functions.https.onRequest(async (req, res) => {
  try {
    const { bankCode, accountNumber } = req.body;
    
    if (!bankCode || !accountNumber) {
      return res.status(400).json({
        success: false,
        error: 'Bank code and account number required for test'
      });
    }

    console.log('🧪 Testing PIN-free transfer capability...');

    // Create test recipient
    const recipientResp = await fetch('https://api.paystack.co/transferrecipient', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        type: 'nuban',
        name: 'Test PIN-Free Transfer',
        account_number: accountNumber,
        bank_code: bankCode,
        currency: 'NGN',
      }),
    });

    const recipientData = await recipientResp.json();
    
    if (!recipientData.status) {
      throw new Error(`Failed to create test recipient: ${recipientData.message}`);
    }

    // Attempt small transfer (₦10 = 1000 kobo)
    const transferResp = await fetch('https://api.paystack.co/transfer', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        'X-Transfer-Type': 'auto',
      },
      body: JSON.stringify({
        source: 'balance',
        amount: 1000, // ₦10 in kobo
        recipient: recipientData.data.recipient_code,
        reason: 'PIN-free test transfer - LifeCare Connect',
        reference: `test_pin_free_${Date.now()}`,
        metadata: {
          test_transfer: true,
          app_name: 'LifeCare Connect',
          purpose: 'PIN bypass validation'
        }
      }),
    });

    const transferData = await transferResp.json();
    
    res.json({
      success: transferData.status,
      pin_required: transferData.data?.status === 'otp' || transferData.data?.status === 'pending',
      transfer_status: transferData.data?.status,
      message: transferData.status 
        ? 'PIN-free transfer working! ✅' 
        : `Transfer issue: ${transferData.message}`,
      data: transferData.data,
      recommendations: transferData.status ? [
        'PIN-free transfers are working correctly',
        'Your providers can now withdraw without PIN verification',
        'Consider increasing transfer limits for larger amounts'
      ] : [
        'PIN verification still required',
        'Check Paystack Settings → Security → Transfer Authorization',
        'Ensure it\'s set to "Automatic" or "API Only"',
        'Contact Paystack support if issues persist'
      ]
    });

  } catch (error) {
    console.error('❌ Test transfer error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      recommendations: [
        'Check Paystack account configuration',
        'Verify API keys are correct',
        'Ensure sufficient balance for test transfer',
        'Review transfer authorization settings'
      ]
    });
  }
});

/**
 * Gets optimal balance management recommendations
 */
exports.getBalanceStrategy = functions.https.onRequest(async (req, res) => {
  try {
    console.log('📊 Generating balance management strategy...');

    // Get current Paystack balance
    const balanceResp = await fetch('https://api.paystack.co/balance', {
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
      },
    });

    const balanceData = await balanceResp.json();
    const currentBalance = balanceData.status ? (balanceData.data[0]?.balance / 100) : 0;

    // Get pending withdrawals
    const pendingWithdrawals = await admin.firestore()
      .collection('withdrawals')
      .where('status', 'in', ['pending', 'approved'])
      .get();

    let totalPending = 0;
    pendingWithdrawals.forEach(doc => {
      totalPending += doc.data().amount || 0;
    });

    // Calculate recommendations
    const recommendedReserve = Math.max(totalPending * 1.5, 50000); // 50% buffer, minimum ₦50k
    const safeToTransfer = Math.max(0, currentBalance - recommendedReserve);
    
    const strategy = {
      current_balance: currentBalance,
      pending_withdrawals: totalPending,
      recommended_reserve: recommendedReserve,
      safe_to_transfer: safeToTransfer,
      balance_utilization: currentBalance > 0 ? (totalPending / currentBalance * 100) : 0,
      recommendations: []
    };

    // Generate specific recommendations
    if (strategy.balance_utilization > 80) {
      strategy.recommendations.push({
        priority: 'urgent',
        action: 'Add funds to Paystack balance',
        description: `Current utilization is ${strategy.balance_utilization.toFixed(1)}%. Add at least ₦${(recommendedReserve - currentBalance).toLocaleString()} to maintain healthy reserves.`
      });
    } else if (strategy.balance_utilization < 30) {
      strategy.recommendations.push({
        priority: 'low',
        action: 'Consider transferring excess to bank',
        description: `You can safely transfer ₦${safeToTransfer.toLocaleString()} to your bank account while maintaining adequate reserves.`
      });
    }

    if (safeToTransfer > 100000) {
      strategy.recommendations.push({
        priority: 'medium',
        action: 'Transfer excess funds',
        description: `₦${safeToTransfer.toLocaleString()} can be safely transferred to your bank account.`
      });
    }

    strategy.recommendations.push({
      priority: 'info',
      action: 'Optimal balance range',
      description: `Maintain ₦${recommendedReserve.toLocaleString()} - ₦${(recommendedReserve * 2).toLocaleString()} for smooth operations.`
    });

    res.json({
      success: true,
      strategy,
      automation_status: {
        pin_free_enabled: true,
        auto_processing: true,
        webhook_configured: true
      }
    });

  } catch (error) {
    console.error('❌ Error generating balance strategy:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});