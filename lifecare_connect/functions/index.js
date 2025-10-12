exports.paystackInitialize = require('./paystack_initialize').paystackInitialize;
exports.paystackVerify = require('./paystack_verify').paystackVerify;
exports.sendStaffSetupPasswordEmail = require('./send_staff_setup_password').sendStaffSetupPasswordEmail;
const functions = require('firebase-functions');
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
  const channelName = req.query.channelName;
  const uid = req.query.uid || 0;
  const role = RtcRole.PUBLISHER;
  const expireTime = 3600; // 1 hour

  if (!APP_ID || !APP_CERTIFICATE) {
    return res.status(500).json({ error: 'Agora credentials not set' });
  }
  if (!channelName) {
    return res.status(400).json({ error: 'Missing channelName' });
  }

  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID, APP_CERTIFICATE, channelName, uid, role, expireTime
  );
  res.json({ token });
});
