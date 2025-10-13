const functions = require('firebase-functions');
const fetch = require('node-fetch');
const admin = require('firebase-admin');
const cors = require('cors')({
  origin: ['https://lifecare-connect.web.app'],
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true,
});

const PAYSTACK_SECRET_KEY = functions.config().paystack.secret_key;

// Helper: Create or get Paystack recipient code for a provider
async function getOrCreateRecipient({ accountNumber, bankCode, accountName }) {
  // In production, cache recipientCode in Firestore for each provider
  const response = await fetch('https://api.paystack.co/transferrecipient', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      type: 'nuban',
      name: accountName,
      account_number: accountNumber,
      bank_code: bankCode,
      currency: 'NGN',
    }),
  });
  const data = await response.json();
  if (data.status && data.data && data.data.recipient_code) {
    return data.data.recipient_code;
  } else {
    throw new Error(data.message || 'Failed to create recipient');
  }
}

exports.paystackTransfer = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method === 'OPTIONS') {
      return res.status(204).send('');
    }
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }
    const { userId, amount, accountNumber, bankCode, accountName, withdrawalId } = req.body;
    if (!userId || !amount || !accountNumber || !bankCode || !accountName || !withdrawalId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    try {
      // 1. Create or get recipient code
      const recipientCode = await getOrCreateRecipient({ accountNumber, bankCode, accountName });
      // 2. Initiate transfer
      const transferResp = await fetch('https://api.paystack.co/transfer', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          source: 'balance',
          amount: Math.round(amount * 100), // Paystack expects kobo
          recipient: recipientCode,
          reason: 'Wallet withdrawal',
        }),
      });
      const transferData = await transferResp.json();
      if (transferData.status) {
        // 3. Mark withdrawal as completed in Firestore
        await admin.firestore().collection('withdrawals').doc(withdrawalId).update({
          status: 'completed',
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          paystackTransfer: transferData.data,
        });
        res.status(200).json({ success: true, transfer: transferData.data });
      } else {
        res.status(500).json({ error: transferData.message || 'Transfer failed' });
      }
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
});
