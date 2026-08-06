const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { defineSecret } = require('firebase-functions/params');

// Define secrets for Termii SMS
const TERMII_API_KEY = defineSecret('TERMII_API_KEY');
const TERMII_SENDER_ID = defineSecret('TERMII_SENDER_ID');

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
exports.sendStaffPasswordResetSimple = require('./send_staff_password_reset').sendStaffPasswordResetSimple;
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

// ============ TERMII OTP FUNCTIONS FOR PATIENT REGISTRATION ============

/**
 * Send OTP via Termii SMS for patient phone verification
 */
exports.sendPatientOTP = functions.https.onCall(async (data, context) => {
  try {
    const { phoneNumber } = data;
    
    if (!phoneNumber) {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
    }
    
    // Validate phone number format (+234XXXXXXXXXX)
    if (!/^\+234\d{10}$/.test(phoneNumber)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number. Use format: +234XXXXXXXXXX');
    }
    
    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Store OTP in Firestore with 30-minute expiry (as per Termii registration template)
    await admin.firestore().collection('patient_otp').doc(phoneNumber).set({
      code: otpCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 60 * 1000)),
      verified: false,
      attempts: 0,
    });
    
    // Get Termii credentials from environment
    const termiiApiKey = process.env.TERMII_API_KEY;
    const senderId = process.env.TERMII_SENDER_ID || 'N-Alert';
    
    if (!termiiApiKey) {
      console.error('Termii API key not configured');
      throw new functions.https.HttpsError('failed-precondition', 'SMS service not configured');
    }
    
    // Send SMS via Termii using approved registration template
    const message = `Lifecare connect registration PIN is ${otpCode}. It expires in 30 minutes`;
    
    try {
      const response = await axios.post('https://api.ng.termii.com/api/sms/send', {
        to: phoneNumber,
        from: senderId,
        sms: message,
        type: 'plain',
        channel: 'dnd',
        api_key: termiiApiKey,
      });
      
      console.log(`OTP sent to ${phoneNumber}:`, response.data);
      
      return { 
        success: true, 
        message: 'OTP sent successfully',
      };
      
    } catch (smsError) {
      console.error('Error sending SMS via Termii:', smsError.response?.data || smsError.message);
      throw new functions.https.HttpsError('internal', 'Failed to send SMS. Please try again.');
    }
    
  } catch (error) {
    console.error('Error in sendPatientOTP:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'An error occurred');
  }
});

/**
 * Verify OTP code for patient phone verification
 */
exports.verifyPatientOTP = functions.https.onCall(async (data, context) => {
  try {
    const { phoneNumber, code, userData } = data;
    
    if (!phoneNumber || !code) {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number and code are required');
    }
    
    const otpDoc = await admin.firestore().collection('patient_otp').doc(phoneNumber).get();
    
    if (!otpDoc.exists) {
      return { success: false, valid: false, message: 'No OTP found. Please request a new code.' };
    }
    
    const otpData = otpDoc.data();
    
    // Check if already verified
    if (otpData.verified) {
      return { success: false, valid: false, message: 'OTP already used. Please request a new code.' };
    }
    
    // Check expiry
    const now = admin.firestore.Timestamp.now();
    if (now.toMillis() > otpData.expiresAt.toMillis()) {
      return { success: false, valid: false, message: 'OTP expired. Please request a new code.' };
    }
    
    // Check max attempts (5 attempts)
    if (otpData.attempts >= 5) {
      return { success: false, valid: false, message: 'Too many failed attempts. Please request a new code.' };
    }
    
    // Verify code
    if (otpData.code === code.trim()) {
      // Mark as verified
      await admin.firestore().collection('patient_otp').doc(phoneNumber).update({
        verified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // If userData is provided, create user document (for registration)
      let userId = null;
      if (userData) {
        const userRef = admin.firestore().collection('users').doc();
        userId = userRef.id;
        
        await userRef.set({
          uid: userId,
          fullName: userData.fullName || '',
          phone: phoneNumber,
          phoneNumber: phoneNumber,
          role: 'patient',
          createdBy: 'self',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isApproved: true,
          isActive: true,
          registrationMethod: 'phone',
          loginMethod: 'termii_otp',
          address: userData.address || '',
          emergencyContact: userData.emergencyContact || '',
          gender: userData.gender || '',
          dateOfBirth: userData.dateOfBirth ? admin.firestore.Timestamp.fromDate(new Date(userData.dateOfBirth)) : null,
        });
        
        console.log(`Patient account created: ${userId} for phone: ${phoneNumber}`);
      }
      
      return { 
        success: true, 
        valid: true, 
        message: 'Phone number verified successfully',
        userId: userId 
      };
    } else {
      // Increment failed attempts
      await admin.firestore().collection('patient_otp').doc(phoneNumber).update({
        attempts: admin.firestore.FieldValue.increment(1),
      });
      
      const remainingAttempts = 5 - (otpData.attempts + 1);
      return { 
        success: false, 
        valid: false, 
        message: `Invalid code. ${remainingAttempts} attempt${remainingAttempts !== 1 ? 's' : ''} remaining.` 
      };
    }
    
  } catch (error) {
    console.error('Error in verifyPatientOTP:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'An error occurred');
  }
});

/**
 * Send Login OTP via Termii SMS
 */
exports.sendLoginOTP = functions
  .runWith({ secrets: [TERMII_API_KEY, TERMII_SENDER_ID] })
  .https.onCall(async (data, context) => {
  try {
    const { phoneNumber } = data;
    
    if (!phoneNumber) {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
    }
    
    // Validate phone number format (+234XXXXXXXXXX)
    if (!/^\+234\d{10}$/.test(phoneNumber)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number. Use format: +234XXXXXXXXXX');
    }
    
    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Store OTP in Firestore with 10-minute expiry (as per Termii login template)
    await admin.firestore().collection('login_otp').doc(phoneNumber).set({
      code: otpCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000)),
      verified: false,
      attempts: 0,
    });
    
    // Get Termii credentials from environment
    const termiiApiKey = process.env.TERMII_API_KEY;
    const senderId = process.env.TERMII_SENDER_ID || 'N-Alert';
    
    if (!termiiApiKey) {
      console.error('Termii API key not configured');
      throw new functions.https.HttpsError('failed-precondition', 'SMS service not configured');
    }
    
    // Send SMS via Termii using approved login template
    const message = `Your Lifecare connect login PIN is ${otpCode}. It expires in 10 minutes`;
    
    try {
      const response = await axios.post('https://api.ng.termii.com/api/sms/send', {
        to: phoneNumber,
        from: senderId,
        sms: message,
        type: 'plain',
        channel: 'dnd',
        api_key: termiiApiKey,
      });
      
      console.log(`Login OTP sent to ${phoneNumber}:`, response.data);
      
      return { 
        success: true, 
        message: 'Login OTP sent successfully',
      };
      
    } catch (smsError) {
      console.error('Error sending Login SMS via Termii:', smsError.response?.data || smsError.message);
      throw new functions.https.HttpsError('internal', 'Failed to send SMS. Please try again.');
    }
    
  } catch (error) {
    console.error('Error in sendLoginOTP:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'An error occurred');
  }
});

/**
 * Verify Login OTP code
 */
exports.verifyLoginOTP = functions.https.onCall(async (data, context) => {
  try {
    const { phoneNumber, code } = data;
    
    if (!phoneNumber || !code) {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number and code are required');
    }
    
    const otpDoc = await admin.firestore().collection('login_otp').doc(phoneNumber).get();
    
    if (!otpDoc.exists) {
      return { success: false, valid: false, message: 'No OTP found. Please request a new code.' };
    }
    
    const otpData = otpDoc.data();
    
    // Check if already verified
    if (otpData.verified) {
      return { success: false, valid: false, message: 'OTP already used. Please request a new code.' };
    }
    
    // Check expiry
    const now = admin.firestore.Timestamp.now();
    if (now.toMillis() > otpData.expiresAt.toMillis()) {
      return { success: false, valid: false, message: 'OTP expired. Please request a new code.' };
    }
    
    // Check max attempts (5 attempts)
    if (otpData.attempts >= 5) {
      return { success: false, valid: false, message: 'Too many failed attempts. Please request a new code.' };
    }
    
    // Verify code
    if (otpData.code === code.trim()) {
      // Mark as verified
      await admin.firestore().collection('login_otp').doc(phoneNumber).update({
        verified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return { success: true, valid: true, message: 'Login verified successfully' };
    } else {
      // Increment failed attempts
      await admin.firestore().collection('login_otp').doc(phoneNumber).update({
        attempts: admin.firestore.FieldValue.increment(1),
      });
      
      const remainingAttempts = 5 - (otpData.attempts + 1);
      return { 
        success: false, 
        valid: false, 
        message: `Invalid code. ${remainingAttempts} attempt${remainingAttempts !== 1 ? 's' : ''} remaining.` 
      };
    }
    
  } catch (error) {
    console.error('Error in verifyLoginOTP:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'An error occurred');
  }
});

/**
 * Send Transaction Verification OTP via Termii SMS
 */
exports.sendTransactionOTP = functions.https.onCall(async (data, context) => {
  try {
    const { phoneNumber, transactionType } = data;
    
    if (!phoneNumber) {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
    }
    
    // Validate phone number format (+234XXXXXXXXXX)
    if (!/^\+234\d{10}$/.test(phoneNumber)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number. Use format: +234XXXXXXXXXX');
    }
    
    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Store OTP in Firestore with 30-minute expiry (as per Termii transaction template)
    await admin.firestore().collection('transaction_otp').doc(phoneNumber).set({
      code: otpCode,
      transactionType: transactionType || 'general',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 60 * 1000)),
      verified: false,
      attempts: 0,
    });
    
    // Get Termii credentials from environment
    const termiiApiKey = process.env.TERMII_API_KEY;
    const senderId = process.env.TERMII_SENDER_ID || 'N-Alert';
    
    if (!termiiApiKey) {
      console.error('Termii API key not configured');
      throw new functions.https.HttpsError('failed-precondition', 'SMS service not configured');
    }
    
    // Send SMS via Termii using approved transaction template
    const message = `Your Lifecare connect verification PIN is ${otpCode}. It expires in 30 minutes`;
    
    try {
      const response = await axios.post('https://api.ng.termii.com/api/sms/send', {
        to: phoneNumber,
        from: senderId,
        sms: message,
        type: 'plain',
        channel: 'dnd',
        api_key: termiiApiKey,
      });
      
      console.log(`Transaction OTP sent to ${phoneNumber}:`, response.data);
      
      return { 
        success: true, 
        message: 'Transaction OTP sent successfully',
      };
      
    } catch (smsError) {
      console.error('Error sending Transaction SMS via Termii:', smsError.response?.data || smsError.message);
      throw new functions.https.HttpsError('internal', 'Failed to send SMS. Please try again.');
    }
    
  } catch (error) {
    console.error('Error in sendTransactionOTP:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'An error occurred');
  }
});

/**
 * Verify Transaction OTP code
 */
exports.verifyTransactionOTP = functions.https.onCall(async (data, context) => {
  try {
    const { phoneNumber, code } = data;
    
    if (!phoneNumber || !code) {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number and code are required');
    }
    
    const otpDoc = await admin.firestore().collection('transaction_otp').doc(phoneNumber).get();
    
    if (!otpDoc.exists) {
      return { success: false, valid: false, message: 'No OTP found. Please request a new code.' };
    }
    
    const otpData = otpDoc.data();
    
    // Check if already verified
    if (otpData.verified) {
      return { success: false, valid: false, message: 'OTP already used. Please request a new code.' };
    }
    
    // Check expiry
    const now = admin.firestore.Timestamp.now();
    if (now.toMillis() > otpData.expiresAt.toMillis()) {
      return { success: false, valid: false, message: 'OTP expired. Please request a new code.' };
    }
    
    // Check max attempts (5 attempts)
    if (otpData.attempts >= 5) {
      return { success: false, valid: false, message: 'Too many failed attempts. Please request a new code.' };
    }
    
    // Verify code
    if (otpData.code === code.trim()) {
      // Mark as verified
      await admin.firestore().collection('transaction_otp').doc(phoneNumber).update({
        verified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return { success: true, valid: true, message: 'Transaction verified successfully' };
    } else {
      // Increment failed attempts
      await admin.firestore().collection('transaction_otp').doc(phoneNumber).update({
        attempts: admin.firestore.FieldValue.increment(1),
      });
      
      const remainingAttempts = 5 - (otpData.attempts + 1);
      return { 
        success: false, 
        valid: false, 
        message: `Invalid code. ${remainingAttempts} attempt${remainingAttempts !== 1 ? 's' : ''} remaining.` 
      };
    }
    
  } catch (error) {
    console.error('Error in verifyTransactionOTP:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'An error occurred');
  }
});

/**
 * Send Withdrawal Authorization OTP via Termii SMS
 */
exports.sendWithdrawalOTP = functions.https.onCall(async (data, context) => {
  try {
    const { phoneNumber, otpCode, amount } = data;
    
    if (!phoneNumber) {
      throw new functions.https.HttpsError('invalid-argument', 'Phone number is required');
    }
    
    if (!otpCode) {
      throw new functions.https.HttpsError('invalid-argument', 'OTP code is required');
    }
    
    // Validate phone number format (+234XXXXXXXXXX)
    if (!/^\+234\d{10}$/.test(phoneNumber)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number. Use format: +234XXXXXXXXXX');
    }
    
    // Get Termii credentials from environment
    const termiiApiKey = process.env.TERMII_API_KEY;
    const senderId = process.env.TERMII_SENDER_ID || 'N-Alert';
    
    if (!termiiApiKey) {
      console.error('Termii API key not configured');
      throw new functions.https.HttpsError('failed-precondition', 'SMS service not configured');
    }
    
    // Send SMS via Termii using approved withdrawal template
    const message = `Your Lifecare connect withdrawal authorization PIN is ${otpCode}. It expires in 30 minutes`;
    
    try {
      const response = await axios.post('https://api.ng.termii.com/api/sms/send', {
        to: phoneNumber,
        from: senderId,
        sms: message,
        type: 'plain',
        channel: 'dnd',
        api_key: termiiApiKey,
      });
      
      console.log(`Withdrawal OTP sent to ${phoneNumber}:`, response.data);
      
      return { 
        success: true, 
        message: 'Withdrawal OTP sent successfully',
      };
      
    } catch (smsError) {
      console.error('Error sending Withdrawal SMS via Termii:', smsError.response?.data || smsError.message);
      throw new functions.https.HttpsError('internal', 'Failed to send SMS. Please try again.');
    }
    
  } catch (error) {
    console.error('Error in sendWithdrawalOTP:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'An error occurred');
  }
});

/**
 * Verify Withdrawal OTP code
 * NOTE: This function is deprecated. OTP verification is now handled client-side
 * in the Flutter app by reading from the withdrawal_otps collection.
 * This function is kept for backward compatibility but should not be used.
 */
exports.verifyWithdrawalOTP = functions.https.onCall(async (data, context) => {
  console.warn('verifyWithdrawalOTP called - this function is deprecated. Use client-side verification instead.');
  return { 
    success: false, 
    valid: false, 
    message: 'This function is deprecated. Please update your app to use client-side OTP verification.' 
  };
});

// CHW Appointment Reminders
const appointmentReminders = require('./appointment_reminders');
exports.sendAppointmentReminders = appointmentReminders.sendAppointmentReminders;
exports.onAppointmentCreated = appointmentReminders.onAppointmentCreated;
exports.onAppointmentUpdated = appointmentReminders.onAppointmentUpdated;
exports.onAppointmentReminderStatusChange = appointmentReminders.onAppointmentStatusChange;

// Appointment SMS Notifications (booking, approval, referrals)
const appointmentNotifications = require('./appointment_notifications');
exports.onAppointmentBooked = appointmentNotifications.onAppointmentBooked;
exports.onAppointmentApproved = appointmentNotifications.onAppointmentApproved;
exports.onAppointmentDenied = appointmentNotifications.onAppointmentDenied;
exports.onAppointmentRescheduled = appointmentNotifications.onAppointmentRescheduled;
exports.sendReferralNotificationSMS = appointmentNotifications.sendReferralNotification;

// CHW Patient Wallet Management
// const resetCHWPatientWallets = require('./reset_chw_patient_wallets');
// exports.resetCHWPatientWallets = resetCHWPatientWallets.resetCHWPatientWallets;
// exports.resetCHWPatientWalletsHTTP = resetCHWPatientWallets.resetCHWPatientWalletsHTTP;

// Account Deletion
const deleteAccountModule = require('./delete_account');
exports.deleteAccount = deleteAccountModule.deleteAccount;

// Subscription Management
const subscriptionManager = require('./subscription_manager');
exports.processMonthlySubscriptions = subscriptionManager.processMonthlySubscriptions;
exports.sendSubscriptionWarnings = subscriptionManager.sendSubscriptionWarnings;
exports.processSpecificSubscription = subscriptionManager.processSpecificSubscription;
exports.reactivateFacility = subscriptionManager.reactivateFacility;

// Automatic Ward Billing
const automaticWardBilling = require('./automatic_ward_billing');
exports.processAutomaticWardBilling = automaticWardBilling.processAutomaticWardBilling;
exports.triggerManualWardBilling = automaticWardBilling.triggerManualWardBilling;
exports.chargePendingBills = automaticWardBilling.chargePendingBills;

// Escrow Payment Release (for regular patient appointments)
const releaseEscrowPayments = require('./release_escrow_payments');
exports.onAppointmentStatusChange = releaseEscrowPayments.onAppointmentStatusChange;
exports.releaseEscrowPaymentManually = releaseEscrowPayments.releaseEscrowPaymentManually;

// Compatibility exports for functions already deployed in production.
const adminNotifications = require('./admin_notifications');
exports.sendAdminNewUserNotification = adminNotifications.sendAdminNewUserNotification;
exports.sendAdminWithdrawalNotification = adminNotifications.sendAdminWithdrawalNotification;

const deleteFirebaseAuthUserModule = require('./delete_firebase_auth_user');
exports.deleteFirebaseAuthUser = deleteFirebaseAuthUserModule.deleteFirebaseAuthUser;

const wardAdmissionBilling = require('./ward_admission_billing');
exports.processWardBillingDaily = wardAdmissionBilling.processWardBillingDaily;
exports.chargeAdmissionNow = wardAdmissionBilling.chargeAdmissionNow;
exports.getAdmissionBillingSummary = wardAdmissionBilling.getAdmissionBillingSummary;

const walletRefundManager = require('./wallet_refund_manager');
exports.verifyBankAccountName = walletRefundManager.verifyBankAccountName;
exports.processRefundApproval = walletRefundManager.processRefundApproval;
exports.rejectRefundApplication = walletRefundManager.rejectRefundApplication;
exports.createTransferRecipient = walletRefundManager.createTransferRecipient;

const patientWalletRefundManager = require('./patient_wallet_refund_manager');
exports.processPatientRefundApproval =
  patientWalletRefundManager.processPatientRefundApproval;
exports.rejectPatientRefundApplication =
  patientWalletRefundManager.rejectPatientRefundApplication;

const subscriptionAutoBilling = require('./subscription_auto_billing');
exports.processSubscriptionBilling =
  subscriptionAutoBilling.processSubscriptionBilling;
exports.triggerSubscriptionBilling =
  subscriptionAutoBilling.triggerSubscriptionBilling;

const pinFreeManager = require('./pin_free_manager');
exports.validatePaystackConfig = pinFreeManager.validatePaystackConfig;
exports.handleTransferWebhook = pinFreeManager.handleTransferWebhook;
exports.testPinFreeTransfer = pinFreeManager.testPinFreeTransfer;
exports.getBalanceStrategy = pinFreeManager.getBalanceStrategy;

const withdrawalReserveManager = require('./withdrawal_reserve_manager');
exports.checkWithdrawalStatusHTTP =
  withdrawalReserveManager.checkWithdrawalStatusHTTP;
