const functions = require('firebase-functions');
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.key);

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
  const { email, name } = req.body;
  const msg = {
    to: email,
    from: 'admin@lifecare.rhemn.org.ng',
    subject: 'Account Approved',
    text: `Hello ${name}, your account has been approved and is now active. You can now login and start using the platform.`,
  };
  try {
    await sgMail.send(msg);
    res.status(200).send('Approval email sent');
  } catch (err) {
    res.status(500).send('Failed to send approval email');
  }
});

exports.sendAccountRejectedEmail = functions.https.onRequest(async (req, res) => {
  const { email, name, reason } = req.body;
  const msg = {
    to: email,
    from: 'admin@lifecare.rhemn.org.ng',
    subject: 'Account Rejected',
    text: `Hello ${name}, your account was rejected for the following reason: ${reason}`,
  };
  try {
    await sgMail.send(msg);
    res.status(200).send('Rejection email sent');
  } catch (err) {
    res.status(500).send('Failed to send rejection email');
  }
});
