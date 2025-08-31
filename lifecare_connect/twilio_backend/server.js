require('dotenv').config();
const express = require('express');
const cors = require('cors');
const twilio = require('twilio');
const app = express();
app.use(express.json());
app.use(cors());
// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const client = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

app.post('/send-otp', async (req, res) => {
  let { phone } = req.body;
  // Normalize Nigerian phone numbers starting with '0'
  if (/^0[789][01]\d{8}$/.test(phone)) {
    phone = '+234' + phone.substring(1);
  }
  // Firestore check for existing user
  const {Firestore} = require('@google-cloud/firestore');
  const firestore = new Firestore();
  try {
    const snapshot = await firestore.collection('users').where('phone', '==', phone).limit(1).get();
    if (!snapshot.empty) {
      return res.status(400).json({ error: 'Phone number already registered.' });
    }
    await client.verify.v2.services(process.env.TWILIO_VERIFY_SERVICE_SID)
      .verifications.create({ to: phone, channel: 'sms' });
    res.json({ success: true });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.post('/verify-otp', async (req, res) => {
  const { phone, code } = req.body;
  try {
    const check = await client.verify.v2.services(process.env.TWILIO_VERIFY_SERVICE_SID)
      .verificationChecks.create({ to: phone, code });
    res.json({ success: check.status === 'approved' });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

app.listen(process.env.PORT || 8080, () => console.log('Twilio OTP server running'));
