const functions = require('firebase-functions');
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.key);

// Sends staff setup password email
exports.sendStaffSetupPasswordEmail = functions.https.onRequest(async (req, res) => {
  const { email, name, staffId, setupLink } = req.body;
  const msg = {
    to: email,
    from: 'admin@lifecare.rhemn.org.ng',
    subject: 'Set Up Your Staff Account Password',
    text: `Hello ${name},\n\nYour staff account (ID: ${staffId}) has been created by your facility admin.\n\nPlease set up your login password using the following link:\n${setupLink}\n\nOnce set, you can log in using your staff ID and password.`,
  };
  try {
    await sgMail.send(msg);
    res.status(200).send('Setup password email sent');
  } catch (err) {
    res.status(500).send('Failed to send setup password email');
  }
});
