const functions = require('firebase-functions');
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.key);

const NO_REPLY_EMAIL = 'noreply@lifecare.rhemn.org.ng'; // Verified no-reply email

// Sends staff password reset email (simpler version without password in email)
exports.sendStaffPasswordResetSimple = functions.https.onRequest(async (req, res) => {
  // Set CORS headers to allow requests from the app
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Extract data from request body
  const { email, name, staffId, setupLink } = req.body;

  // Validate required fields
  if (!email || !name || !staffId || !setupLink) {
    console.error('Missing required fields:', { 
      email: !!email, 
      name: !!name, 
      staffId: !!staffId, 
      setupLink: !!setupLink
    });
    res.status(400).json({ 
      error: 'Missing required fields',
      required: ['email', 'name', 'staffId', 'setupLink']
    });
    return;
  }

  const msg = {
    to: email,
    from: {
      email: NO_REPLY_EMAIL,
      name: 'LifeCare Connect'
    },
    replyTo: {
      email: 'support@lifecare.rhemn.org.ng',
      name: 'LifeCare Support'
    },
    subject: 'Reset Your Password - LifeCare Connect',
    categories: ['staff-password-reset', 'authentication'],
    customArgs: {
      staffId: staffId,
      type: 'password-reset-email'
    },
    trackingSettings: {
      clickTracking: {
        enable: true,
        enableText: false
      },
      openTracking: {
        enable: true
      }
    },
    mailSettings: {
      bypassListManagement: {
        enable: false
      },
      footer: {
        enable: false
      },
      sandboxMode: {
        enable: false
      }
    },
    text: `Hello ${name},

We received a request to reset your password for your staff account.

Staff ID: ${staffId}

Click the link below to create a new password:
${setupLink}

This link will allow you to set up a new password for your account.

If you did not request this password reset, please ignore this email or contact your facility administrator.

For security purposes, this link will expire after a certain period of time.

Best regards,
LifeCare Connect Team`,
    html: `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Password Reset</title>
      </head>
      <body style="margin: 0; padding: 0; background-color: #f4f4f4;">
      <div style="font-family: Arial, Helvetica, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #ffffff;">
        <div style="background-color: #009688; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0;">
          <h1 style="margin: 0; font-size: 24px;">LifeCare Connect</h1>
        </div>
        
        <div style="background-color: #f5f5f5; padding: 30px; border-radius: 0 0 10px 10px;">
          <h2 style="color: #009688; margin-top: 0; font-size: 20px;">Password Reset Request</h2>
          
          <p style="font-size: 16px; line-height: 1.6;">
            Hello ${name},
          </p>
          
          <p style="font-size: 16px; line-height: 1.6;">
            We received a request to reset your password for your staff account.
          </p>
          
          <div style="background-color: white; padding: 15px; border-radius: 5px; margin: 20px 0; border: 2px solid #009688;">
            <strong style="color: #009688;">Staff ID:</strong>
            <div style="background-color: #f5f5f5; padding: 10px; border-radius: 3px; margin-top: 5px; font-family: monospace; font-size: 16px;">
              ${staffId}
            </div>
          </div>
          
          <p style="font-size: 16px; line-height: 1.6;">
            Click the button below to create a new password:
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${setupLink}" 
               target="_blank"
               rel="noopener noreferrer"
               style="background-color: #009688; 
                      color: white; 
                      padding: 15px 30px; 
                      text-decoration: none; 
                      border-radius: 5px; 
                      display: inline-block;
                      font-weight: bold;
                      font-size: 16px;">
              🔐 Reset Password
            </a>
          </div>
          
          <p style="font-size: 13px; color: #666; line-height: 1.6; margin-top: 20px;">
            If the button doesn't work, copy and paste this link:<br>
            <a href="${setupLink}" target="_blank" rel="noopener noreferrer" style="color: #009688; word-break: break-all;">${setupLink}</a>
          </p>
          
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          
          <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
            <p style="margin: 0; font-size: 14px; color: #856404;">
              <strong>⚠️ Security Notice:</strong> If you did not request this password reset, please ignore this email or contact your facility administrator immediately.
            </p>
          </div>
          
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          
          <p style="font-size: 14px; color: #999; margin-top: 30px;">
            For security purposes, this link will expire after a certain period of time.
          </p>
        </div>
        
        <div style="text-align: center; padding: 20px; color: #999; font-size: 12px; border-top: 1px solid #e0e0e0; margin-top: 20px;">
          <p style="margin: 5px 0;">LifeCare Connect</p>
          <p style="margin: 5px 0;">Healthcare Management Platform</p>
          <p style="margin: 5px 0;">&copy; 2025 All rights reserved.</p>
        </div>
      </div>
      </body>
      </html>
    `,
  };

  try {
    console.log(`[PasswordReset] Attempting to send email to: ${email}`);
    console.log(`[PasswordReset] Staff ID: ${staffId}`);
    console.log(`[PasswordReset] From: ${NO_REPLY_EMAIL}`);
    console.log(`[PasswordReset] Subject: Reset Your Password`);
    
    const response = await sgMail.send(msg);
    
    console.log(`[PasswordReset] ✅ Email sent successfully!`);
    console.log(`[PasswordReset] Response status: ${response[0].statusCode}`);
    console.log(`[PasswordReset] Message ID: ${response[0].headers['x-message-id']}`);
    
    res.status(200).json({ 
      success: true, 
      message: 'Password reset email sent successfully',
      email: email,
      staffId: staffId,
      messageId: response[0].headers['x-message-id']
    });
  } catch (err) {
    console.error('[PasswordReset] ❌ Failed to send email');
    console.error('[PasswordReset] Error code:', err.code);
    console.error('[PasswordReset] Error message:', err.message);
    
    if (err.response) {
      console.error('[PasswordReset] SendGrid error body:', JSON.stringify(err.response.body, null, 2));
      console.error('[PasswordReset] SendGrid status code:', err.response.statusCode);
    }
    
    // Return detailed error for debugging
    res.status(500).json({ 
      success: false, 
      error: 'Failed to send password reset email',
      details: err.message,
      code: err.code,
      sendgridError: err.response?.body?.errors || null
    });
  }
});
