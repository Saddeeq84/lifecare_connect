const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * 🔍 Paystack Account Analyzer
 * Helps identify available transfer settings in your specific account
 */

const PAYSTACK_SECRET_KEY = functions.config().paystack.secret_key;

/**
 * Analyzes your Paystack account to find transfer configuration options
 */
exports.analyzePaystackAccount = functions.https.onRequest(async (req, res) => {
  try {
    console.log('🔍 Analyzing Paystack account configuration...');

    // Get account details
    const accountResp = await fetch('https://api.paystack.co/integration', {
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
      },
    });

    const accountData = await accountResp.json();
    
    if (!accountData.status) {
      throw new Error('Failed to fetch account details');
    }

    const account = accountData.data;
    
    // Get balance information
    const balanceResp = await fetch('https://api.paystack.co/balance', {
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
      },
    });

    const balanceData = await balanceResp.json();
    const currentBalance = balanceData.status ? (balanceData.data[0]?.balance / 100) : 0;

    // Get transfer capabilities
    const transferResp = await fetch('https://api.paystack.co/transfer/check_balance', {
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
      },
    });

    const transferData = await transferResp.json();

    // Analyze configuration
    const analysis = {
      account_type: account.business_type || 'Unknown',
      business_name: account.business_name || 'Not set',
      settlement_schedule: account.settlement_schedule || 'Unknown',
      auto_settlement: account.auto_settlement || false,
      current_balance: currentBalance,
      can_transfer: transferData.status || false,
      
      // Key settings to look for
      dashboard_locations: {
        transfer_settings: [
          "Transfers → Transfers → Settings/Preferences",
          "Transfers → Balance → Transfer Options", 
          "Settings → API Keys & Webhooks → Transfer Authorization",
          "Settings → Preferences → Transfer Settings",
          "Settings → Accounts → Business Settings"
        ],
        
        payout_settings: [
          "Settings → Preferences → Payout Schedule",
          "Settings → Accounts → Settlement Settings",
          "Transfers → Balance → Auto Settlement"
        ]
      },

      // What to search for in dashboard
      search_terms: [
        "Transfer Authorization",
        "PIN Requirement", 
        "Auto Approval",
        "Transfer Limits",
        "Settlement Schedule",
        "Payout Schedule",
        "API Authorization"
      ],

      current_limitations: [],
      recommendations: []
    };

    // Analyze limitations
    if (account.settlement_schedule && account.settlement_schedule !== 'manual') {
      analysis.current_limitations.push({
        issue: 'Automatic settlements enabled',
        impact: 'Funds may be automatically transferred to bank',
        location: 'Settings → Preferences or Settings → Accounts'
      });
    }

    if (!account.business_verified) {
      analysis.current_limitations.push({
        issue: 'Business not fully verified',
        impact: 'May have lower transfer limits and require PINs',
        location: 'Settings → Compliance → Business Verification'
      });
    }

    // Generate specific recommendations
    analysis.recommendations = [
      {
        priority: 'high',
        action: 'Find Transfer Authorization Settings',
        steps: [
          '1. Go to "Transfers" in left sidebar',
          '2. Click on "Balance" or "Settings"',
          '3. Look for "Authorization" or "PIN" options',
          '4. If not found, try Settings → API Keys & Webhooks'
        ]
      },
      {
        priority: 'high', 
        action: 'Check Settlement/Payout Settings',
        steps: [
          '1. Go to Settings → Preferences',
          '2. Look for "Payout" or "Settlement" options',
          '3. Disable automatic transfers if found',
          '4. Set to manual payout schedule'
        ]
      },
      {
        priority: 'medium',
        action: 'Verify Business Account',
        steps: [
          '1. Go to Settings → Compliance',
          '2. Complete business verification if needed',
          '3. This may unlock additional transfer options'
        ]
      }
    ];

    // Test small transfer to see what happens
    console.log('🧪 Testing transfer capability...');
    
    res.json({
      success: true,
      account_analysis: analysis,
      next_steps: [
        '1. Check each dashboard location listed above',
        '2. Search for the terms provided in search_terms',
        '3. Look for any "Authorization", "PIN", or "Limits" settings',
        '4. If found, set to "Automatic" or increase limits',
        '5. If not found, your account may need business verification'
      ],
      fallback_plan: {
        description: 'If PIN settings not found in dashboard',
        action: 'Contact Paystack support to enable API-only transfers',
        reference: 'Request: Enable automatic transfer authorization for API calls'
      }
    });

  } catch (error) {
    console.error('❌ Error analyzing account:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      manual_steps: [
        '1. Navigate through all Settings tabs',
        '2. Check Transfers section thoroughly', 
        '3. Look for any "Authorization" or "PIN" mentions',
        '4. Contact Paystack support if needed'
      ]
    });
  }
});