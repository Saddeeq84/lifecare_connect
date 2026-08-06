const functions = require('firebase-functions');
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.key);

// Using verified no-reply email for professional appearance
const NO_REPLY_EMAIL = 'noreply@lifecare.rhemn.org.ng';

exports.sendAdminApprovalEmail = functions.https.onRequest(async (req, res) => {
  const { email, name } = req.body;
  const msg = {
    to: email,
    from: VERIFIED_SENDER_EMAIL,
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
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const { email, name } = req.body;
  const msg = {
    to: email,
    from: NO_REPLY_EMAIL,
    subject: '✅ LifeCare Connect - Account Approved',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background-color: #28a745; color: white; padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">
          <h2 style="margin: 0;">Account Approved!</h2>
        </div>
        
        <div style="background-color: white; padding: 30px; border: 1px solid #e9ecef; border-radius: 0 0 8px 8px;">
          <p style="font-size: 16px; margin-bottom: 20px;">Hello <strong>${name}</strong>,</p>
          
          <p style="font-size: 16px; line-height: 1.6; margin-bottom: 20px;">
            Great news! Your LifeCare Connect account has been <strong>approved</strong> and is now active. 
            You can now log in and start using the platform.
          </p>
          
          <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px;">
            <h4 style="color: #28a745; margin-top: 0;">Next Steps:</h4>
            <ul style="margin: 0; padding-left: 20px;">
              <li>Visit <a href="https://lifecare-connect.web.app" style="color: #007bff;">LifeCare Connect</a></li>
              <li>Log in with your registered email and password</li>
              <li>Complete your profile setup if needed</li>
              <li>Start providing healthcare services</li>
            </ul>
          </div>
          
          <p style="font-size: 14px; color: #6c757d; margin-bottom: 0;">
            Thank you for joining LifeCare Connect. If you have any questions, please don't reply to this email as it's from a no-reply address.
          </p>
        </div>
      </div>
    `,
  };
  try {
    await sgMail.send(msg);
    res.status(200).send('Approval email sent');
  } catch (err) {
    res.status(500).send('Failed to send approval email');
  }
});

exports.sendAccountRejectedEmail = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const { email, name, reason } = req.body;
  const msg = {
    to: email,
    from: NO_REPLY_EMAIL,
    subject: '❌ LifeCare Connect - Account Registration Update',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background-color: #dc3545; color: white; padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">
          <h2 style="margin: 0;">Registration Update</h2>
        </div>
        
        <div style="background-color: white; padding: 30px; border: 1px solid #e9ecef; border-radius: 0 0 8px 8px;">
          <p style="font-size: 16px; margin-bottom: 20px;">Hello <strong>${name}</strong>,</p>
          
          <p style="font-size: 16px; line-height: 1.6; margin-bottom: 20px;">
            Thank you for your interest in joining LifeCare Connect. After reviewing your registration, 
            we were unable to approve your account at this time.
          </p>
          
          <div style="background-color: #f8d7da; color: #721c24; padding: 15px; border-radius: 5px; margin-bottom: 20px; border-left: 4px solid #dc3545;">
            <h4 style="margin-top: 0; color: #721c24;">Reason for rejection:</h4>
            <p style="margin: 0; font-weight: 500;">${reason}</p>
          </div>
          
          <div style="background-color: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin-bottom: 20px; border-left: 4px solid #28a745;">
            <h4 style="margin-top: 0; color: #155724;">What you can do:</h4>
            <ul style="margin: 0; padding-left: 20px;">
              <li>Review the rejection reason above</li>
              <li>Gather the required documents or information</li>
              <li>Create a new registration with the correct details</li>
              <li>Contact support if you need clarification</li>
            </ul>
          </div>
          
          <p style="font-size: 14px; color: #6c757d; margin-bottom: 0;">
            We appreciate your interest in LifeCare Connect. Please don't reply to this email as it's from a no-reply address.
          </p>
        </div>
      </div>
    `,
  };
  try {
    await sgMail.send(msg);
    res.status(200).send('Rejection email sent');
  } catch (err) {
    res.status(500).send('Failed to send rejection email');
  }
});
