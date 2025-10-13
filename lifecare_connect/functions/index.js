const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
// Atomic wallet payment split function
exports.walletPayment = functions.https.onCall(async (data, context) => {
  const { patientId, providerId, adminId, totalFee, providerType } = data;
  if (!patientId || !providerId || !adminId || !totalFee) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');
  }
  const providerShare = Math.round(totalFee * 0.7);
  const adminShare = totalFee - providerShare;

  const walletsRef = admin.firestore().collection('wallets');
  const patientRef = walletsRef.doc(patientId);
  const providerRef = walletsRef.doc(providerId);
  const adminRef = walletsRef.doc(adminId);

  return admin.firestore().runTransaction(async (txn) => {
    // Patient wallet
    const patientDoc = await txn.get(patientRef);
    let patientBal = 0;
    if (patientDoc.exists && typeof patientDoc.data().balance === 'number') {
      patientBal = patientDoc.data().balance;
    }
    if (patientBal < totalFee) {
      throw new functions.https.HttpsError('failed-precondition', 'Insufficient patient wallet balance.');
    }
    // Deduct from patient
    txn.set(patientRef, {
      balance: patientBal - totalFee,
      currency: 'NGN',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      transactions: admin.firestore.FieldValue.arrayUnion({
        type: 'deduct',
        amount: totalFee,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Appointment payment',
      }),
    }, { merge: true });

    // Provider wallet
    const providerDoc = await txn.get(providerRef);
    let providerBal = 0;
    if (providerDoc.exists && typeof providerDoc.data().balance === 'number') {
      providerBal = providerDoc.data().balance;
    }
    txn.set(providerRef, {
      balance: providerBal + providerShare,
      currency: 'NGN',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      transactions: admin.firestore.FieldValue.arrayUnion({
        type: providerType === 'doctor' ? 'doctor_earning' : 'chw_earning',
        amount: providerShare,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Appointment earning',
      }),
    }, { merge: true });

    // Admin wallet
    const adminDoc = await txn.get(adminRef);
    let adminBal = 0;
    if (adminDoc.exists && typeof adminDoc.data().balance === 'number') {
      adminBal = adminDoc.data().balance;
    }
    txn.set(adminRef, {
      balance: adminBal + adminShare,
      currency: 'NGN',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      transactions: admin.firestore.FieldValue.arrayUnion({
        type: 'admin_commission',
        amount: adminShare,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Admin commission from appointment',
      }),
    }, { merge: true });

    return { success: true, providerShare, adminShare };
  });
});
exports.paystackTransfer = require('./paystack_transfer').paystackTransfer;
exports.paystackInitialize = require('./paystack_initialize').paystackInitialize;
exports.paystackVerify = require('./paystack_verify').paystackVerify;
exports.sendStaffSetupPasswordEmail = require('./send_staff_setup_password').sendStaffSetupPasswordEmail;
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.key);

exports.sendAdminApprovalEmail = functions.https.onRequest(async (req, res) => {
  const { email, name } = req.body;
  const msg = {
    to: email,
    from: 'admin@lifecare.rhemn.org.ng', // Use your verified sender
    subject: 'Admin Approval Required',
    text: `Hello ${name}, your account requires admin approval.`,
  };
  try {
    await sgMail.send(msg);
    res.status(200).send('Email sent');
  } catch (err) {
    res.status(500).send('Failed to send email');
  }
});

exports.sendAccountApprovedEmail = require('./account_status_emails').sendAccountApprovedEmail;
exports.sendAccountRejectedEmail = require('./account_status_emails').sendAccountRejectedEmail;

exports.setPdfInlineDisposition = require('./setPdfInlineDisposition').setPdfInlineDisposition;

const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

// Use Firebase environment config for secrets
const APP_ID = functions.config().agora.app_id;
const APP_CERTIFICATE = functions.config().agora.app_certificate;

exports.agoraToken = functions.https.onRequest((req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  const channelName = req.query.channelName;
  const uid = req.query.uid || 0;
  const role = RtcRole.PUBLISHER;
  const expireTimeInSeconds = 3600; // 1 hour

  if (!APP_ID || !APP_CERTIFICATE) {
    return res.status(500).json({ error: 'Agora credentials not set' });
  }
  if (!channelName) {
    return res.status(400).json({ error: 'Missing channelName' });
  }

  // Calculate the actual expiration timestamp
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const expireTimestamp = currentTimestamp + expireTimeInSeconds;

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID, APP_CERTIFICATE, channelName, uid, role, expireTimestamp
    );
    
    res.json({ 
      token,
      expireTime: expireTimestamp,
      currentTime: currentTimestamp 
    });
  } catch (error) {
    console.error('Error generating Agora token:', error);
    res.status(500).json({ error: 'Failed to generate token', details: error.message });
  }
});
