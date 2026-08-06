const functions = require('firebase-functions');
const fetch = require('node-fetch');
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

// Use Firebase environment config for secrets
const PAYSTACK_SECRET_KEY = functions.config().paystack.secret_key;

exports.paystackInitialize = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method === 'OPTIONS') {
      return res.status(204).send('');
    }
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }
    const { email, amount, reference } = req.body;
    if (!email || !amount || !reference) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    try {
      const response = await fetch('https://api.paystack.co/transaction/initialize', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${PAYSTACK_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email,
          amount,
          reference,
        }),
      });
      const data = await response.json();
      res.status(response.status).json(data);
    } catch (err) {
      res.status(500).json({ error: 'Failed to initialize payment', details: err.message });
    }
  });
});
