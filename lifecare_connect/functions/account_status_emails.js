require('dotenv').config();
const functions = require('firebase-functions');
const admin = require('firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp();
}
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_KEY);

exports.sendAdminApprovalEmail = functions.https.onRequest(async (req, res) => {
  const { email, name } = req.body;
  const msg = {
    to: email,
    from: 'admin@lifecare.rhemn.org.ng',
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

exports.sendAccountApprovedEmail = functions.https.onRequest(async (req, res) => {
  const { email, name, userId } = req.body;
  const msg = {
    to: email,
    from: 'admin@lifecare.rhemn.org.ng',
    subject: 'Account Approved',
    text: `Hello ${name}, your account has been approved and is now active. You can now login and start using the platform at https://lifecare-connect.web.app/`,
  };
  try {
    await sgMail.send(msg);
    // Send push notification
    if (userId) {
      const admin = require('firebase-admin');
      const notificationFn = require('./sendNotification').sendNotificationToUser;
      await notificationFn({ userId, title: 'Account Approved', body: 'Your account has been approved and is now active.' }, { auth: null });
    }
    res.status(200).send('Approval email sent');
  } catch (err) {
    res.status(500).send('Failed to send approval email');
  }
});

exports.sendAccountRejectedEmail = functions.https.onRequest(async (req, res) => {
  const { email, name, reason, userId } = req.body;
  const msg = {
    to: email,
    from: 'admin@lifecare.rhemn.org.ng',
    subject: 'Account Rejected',
    text: `Hello ${name}, your account was rejected for the following reason: ${reason}`,
  };
  try {
    await sgMail.send(msg);
    // Send push notification
    if (userId) {
      const admin = require('firebase-admin');
      const notificationFn = require('./sendNotification').sendNotificationToUser;
      await notificationFn({ userId, title: 'Account Rejected', body: `Your account was rejected: ${reason}` }, { auth: null });
    }
    res.status(200).send('Rejection email sent');
  } catch (err) {
    res.status(500).send('Failed to send rejection email');
  }
});
