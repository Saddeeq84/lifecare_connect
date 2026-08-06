const functions = require('firebase-functions');
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.key);

const NO_REPLY_EMAIL = 'noreply@lifecare.rhemn.org.ng'; // Verified no-reply email

// Sends staff setup password email
exports.sendStaffSetupPasswordEmail = functions.https.onRequest(async (req, res) => {
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
  // setupLink parameter now contains password|||verificationLink
  const { email, name, staffId, setupLink } = req.body;
  const [password, verificationLink] = (setupLink || '').split('|||');

  // Validate required fields
  if (!email || !name || !staffId || !password || !verificationLink) {
    console.error('Missing required fields:', { 
      email: !!email, 
      name: !!name, 
      staffId: !!staffId, 
      password: !!password,
      verificationLink: !!verificationLink
    });
    res.status(400).json({ 
      error: 'Missing required fields',
      required: ['email', 'name', 'staffId', 'setupLink (password|||verificationLink)']
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
    subject: 'Your Staff Account Login Credentials - LifeCare Connect',
    categories: ['staff-credentials', 'authentication'],
    customArgs: {
      staffId: staffId,
      type: 'credentials-email'
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

Your staff account has been created successfully by your facility administrator.

Below are your login credentials:

Staff ID: ${staffId}
Password: ${password}

IMPORTANT: You must verify your email address before you can login.

Click here to verify your email: ${verificationLink}

After verification, you can log in at: https://lifecare-connect.web.app

For security purposes, you can change your password after your first login.

If you did not request this account or have any questions, please contact your facility administrator.

Best regards,
LifeCare Connect Team`,
    html: `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Your Login Credentials</title>
      </head>
      <body style="margin: 0; padding: 0; background-color: #f4f4f4;">
      <div style="font-family: Arial, Helvetica, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #ffffff;">
        <div style="background-color: #009688; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0;">
          <h1 style="margin: 0; font-size: 24px;">LifeCare Connect</h1>
        </div>
        
        <div style="background-color: #f5f5f5; padding: 30px; border-radius: 0 0 10px 10px;">
          <h2 style="color: #009688; margin-top: 0; font-size: 20px;">Welcome, ${name}!</h2>
          
          <p style="font-size: 16px; line-height: 1.6;">
            Your staff account has been created successfully by your facility administrator.
          </p>
          
          <p style="font-size: 16px; line-height: 1.6; margin-bottom: 10px;">
            <strong>Your login credentials:</strong>
          </p>
          
          <div style="background-color: white; padding: 20px; border-radius: 5px; margin: 20px 0; border: 2px solid #009688;">
            <div style="margin-bottom: 12px;">
              <strong style="color: #009688;">Staff ID:</strong>
              <div style="background-color: #f5f5f5; padding: 10px; border-radius: 3px; margin-top: 5px; font-family: monospace; font-size: 16px;">
                ${staffId}
              </div>
            </div>
            <div>
              <strong style="color: #009688;">Password:</strong>
              <div style="background-color: #f5f5f5; padding: 10px; border-radius: 3px; margin-top: 5px; font-family: monospace; font-size: 16px;">
                ${password}
              </div>
            </div>
          </div>
          
          <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0;">
            <p style="margin: 0; font-size: 14px; color: #856404;">
              <strong>⚠️ Important:</strong> You must verify your email before you can login.
            </p>
          </div>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${verificationLink}" 
               target="_blank"
               rel="noopener noreferrer"
               style="background-color: #ff9800; 
                      color: white; 
                      padding: 15px 30px; 
                      text-decoration: none; 
                      border-radius: 5px; 
                      display: inline-block;
                      font-weight: bold;
                      font-size: 16px;">
              ✓ Verify Email Address
            </a>
          </div>
          
          <p style="font-size: 13px; color: #666; line-height: 1.6; margin-top: 20px;">
            If the button doesn't work, copy and paste this link:<br>
            <a href="${verificationLink}" target="_blank" rel="noopener noreferrer" style="color: #009688; word-break: break-all;">${verificationLink}</a>
          </p>
          
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          
          <div style="background-color: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin: 20px 0;">
            <p style="margin: 0; font-size: 14px; color: #1565c0;">
              <strong>After Email Verification:</strong>
            </p>
            <p style="margin: 10px 0 0 0; font-size: 13px; color: #1565c0;">
              You can login at: <a href="https://lifecare-connect.web.app" target="_blank" style="color: #1565c0;">https://lifecare-connect.web.app</a><br>
              You can also change your password after your first login.
            </p>
          </div>
          
          <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
          
          <p style="font-size: 14px; color: #999; margin-top: 30px;">
            If you did not request this account or have any questions, please contact your facility administrator immediately.
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
    console.log(`[StaffCredentials] Attempting to send email to: ${email}`);
    console.log(`[StaffCredentials] Staff ID: ${staffId}`);
    console.log(`[StaffCredentials] From: ${NO_REPLY_EMAIL}`);
    console.log(`[StaffCredentials] Subject: Your Staff Account Login Credentials`);
    
    const response = await sgMail.send(msg);
    
    console.log(`[StaffCredentials] ✅ Email sent successfully!`);
    console.log(`[StaffCredentials] Response status: ${response[0].statusCode}`);
    console.log(`[StaffCredentials] Message ID: ${response[0].headers['x-message-id']}`);
    
    res.status(200).json({ 
      success: true, 
      message: 'Staff credentials email sent successfully',
      email: email,
      staffId: staffId,
      messageId: response[0].headers['x-message-id']
    });
  } catch (err) {
    console.error('[StaffCredentials] ❌ Failed to send email');
    console.error('[StaffCredentials] Error code:', err.code);
    console.error('[StaffCredentials] Error message:', err.message);
    
    if (err.response) {
      console.error('[StaffCredentials] SendGrid error body:', JSON.stringify(err.response.body, null, 2));
      console.error('[StaffCredentials] SendGrid status code:', err.response.statusCode);
    }
    
    // Return detailed error for debugging
    res.status(500).json({ 
      success: false, 
      error: 'Failed to send staff credentials email',
      details: err.message,
      code: err.code,
      sendgridError: err.response?.body?.errors || null
    });
  }
});
