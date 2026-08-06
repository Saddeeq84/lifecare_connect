const functions = require('firebase-functions');
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.key);

const ADMIN_EMAIL = 'admin@lifecare.rhemn.org.ng'; // Admin email for notifications  
const NO_REPLY_EMAIL = 'noreply@lifecare.rhemn.org.ng'; // Verified no-reply email for sending

/**
 * Send email notification to admin when a new user requires approval
 */
exports.sendAdminNewUserNotification = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  const { email, name, role, userId, registrationDate } = req.body;
  
  const roleDisplayName = {
    'doctor': 'Doctor',
    'chw': 'Community Health Worker',
    'facility': 'Healthcare Facility'
  }[role] || role.toUpperCase();

  const msg = {
    to: ADMIN_EMAIL,
    from: NO_REPLY_EMAIL,
    subject: `New ${roleDisplayName} Registration Requires Approval`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
          <h2 style="color: #28a745; margin: 0;">New User Registration</h2>
          <p style="color: #6c757d; margin: 5px 0;">A new ${roleDisplayName.toLowerCase()} has registered and requires approval</p>
        </div>
        
        <div style="background-color: white; padding: 20px; border: 1px solid #e9ecef; border-radius: 8px;">
          <h3 style="color: #343a40; margin-top: 0;">Registration Details</h3>
          
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Name:</td>
              <td style="padding: 8px 0; color: #6c757d;">${name}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Email:</td>
              <td style="padding: 8px 0; color: #6c757d;">${email}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Role:</td>
              <td style="padding: 8px 0; color: #6c757d;">${roleDisplayName}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">User ID:</td>
              <td style="padding: 8px 0; color: #6c757d; font-family: monospace;">${userId}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Registration Date:</td>
              <td style="padding: 8px 0; color: #6c757d;">${registrationDate}</td>
            </tr>
          </table>
        </div>
        
        <div style="background-color: #fff3cd; padding: 15px; border-radius: 8px; margin-top: 20px; border-left: 4px solid #ffc107;">
          <h4 style="color: #856404; margin-top: 0;">Action Required</h4>
          <p style="color: #856404; margin-bottom: 0;">
            Please log in to the admin dashboard to review and approve this registration.
            The user will receive an email notification once their account is approved.
          </p>
        </div>
        
        <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e9ecef;">
          <a href="https://lifecare-connect.web.app/admin" 
             style="background-color: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
            Go to Admin Dashboard
          </a>
        </div>
        
        <div style="text-align: center; margin-top: 20px; font-size: 12px; color: #6c757d;">
          <p>This is an automated notification from LifeCare Connect</p>
        </div>
      </div>
    `,
    text: `
      New ${roleDisplayName} Registration Requires Approval
      
      Registration Details:
      - Name: ${name}
      - Email: ${email}
      - Role: ${roleDisplayName}
      - User ID: ${userId}
      - Registration Date: ${registrationDate}
      
      Action Required:
      Please log in to the admin dashboard to review and approve this registration.
      The user will receive an email notification once their account is approved.
      
      Admin Dashboard: https://lifecare-connect.web.app/admin
    `
  };

  try {
    await sgMail.send(msg);
    console.log(`Admin notification sent for new ${role} registration: ${email}`);
    res.status(200).send('Admin notification sent successfully');
  } catch (error) {
    console.error('Failed to send admin notification:', error);
    res.status(500).send('Failed to send admin notification');
  }
});

/**
 * Send email notification to admin when a service provider requests withdrawal
 */
exports.sendAdminWithdrawalNotification = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  const { 
    userId, 
    userName, 
    userEmail, 
    role, 
    amount, 
    bankName, 
    accountNumber, 
    accountName, 
    requestDate, 
    withdrawalId 
  } = req.body;
  
  const roleDisplayName = {
    'doctor': 'Doctor',
    'chw': 'Community Health Worker',
    'admin': 'Administrator'
  }[role] || role.toUpperCase();

  const formattedAmount = parseFloat(amount).toLocaleString('en-NG', {
    style: 'currency',
    currency: 'NGN'
  });

  const msg = {
    to: ADMIN_EMAIL,
    from: NO_REPLY_EMAIL,
    subject: `Withdrawal Request from ${roleDisplayName} - ${formattedAmount}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
          <h2 style="color: #dc3545; margin: 0;">Withdrawal Request</h2>
          <p style="color: #6c757d; margin: 5px 0;">A ${roleDisplayName.toLowerCase()} has requested a withdrawal</p>
        </div>
        
        <div style="background-color: white; padding: 20px; border: 1px solid #e9ecef; border-radius: 8px; margin-bottom: 20px;">
          <h3 style="color: #343a40; margin-top: 0;">Provider Details</h3>
          
          <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Name:</td>
              <td style="padding: 8px 0; color: #6c757d;">${userName}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Email:</td>
              <td style="padding: 8px 0; color: #6c757d;">${userEmail}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Role:</td>
              <td style="padding: 8px 0; color: #6c757d;">${roleDisplayName}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">User ID:</td>
              <td style="padding: 8px 0; color: #6c757d; font-family: monospace;">${userId}</td>
            </tr>
          </table>
        </div>
        
        <div style="background-color: white; padding: 20px; border: 1px solid #e9ecef; border-radius: 8px; margin-bottom: 20px;">
          <h3 style="color: #343a40; margin-top: 0;">Withdrawal Details</h3>
          
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Amount:</td>
              <td style="padding: 8px 0; color: #dc3545; font-weight: bold; font-size: 18px;">${formattedAmount}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Bank:</td>
              <td style="padding: 8px 0; color: #6c757d;">${bankName}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Account Number:</td>
              <td style="padding: 8px 0; color: #6c757d; font-family: monospace;">${accountNumber}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Account Name:</td>
              <td style="padding: 8px 0; color: #6c757d;">${accountName}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Request Date:</td>
              <td style="padding: 8px 0; color: #6c757d;">${requestDate}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: bold; color: #495057;">Withdrawal ID:</td>
              <td style="padding: 8px 0; color: #6c757d; font-family: monospace;">${withdrawalId}</td>
            </tr>
          </table>
        </div>
        
        <div style="background-color: #d1ecf1; padding: 15px; border-radius: 8px; margin-top: 20px; border-left: 4px solid #17a2b8;">
          <h4 style="color: #0c5460; margin-top: 0;">Action Required</h4>
          <p style="color: #0c5460; margin-bottom: 0;">
            Please log in to the admin dashboard to review and process this withdrawal request.
            Ensure all bank details are correct before approving the payment.
          </p>
        </div>
        
        <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e9ecef;">
          <a href="https://lifecare-connect.web.app/admin/withdrawals" 
             style="background-color: #dc3545; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">
            Review Withdrawal Request
          </a>
        </div>
        
        <div style="text-align: center; margin-top: 20px; font-size: 12px; color: #6c757d;">
          <p>This is an automated notification from LifeCare Connect</p>
        </div>
      </div>
    `,
    text: `
      Withdrawal Request from ${roleDisplayName}
      
      Provider Details:
      - Name: ${userName}
      - Email: ${userEmail}
      - Role: ${roleDisplayName}
      - User ID: ${userId}
      
      Withdrawal Details:
      - Amount: ${formattedAmount}
      - Bank: ${bankName}
      - Account Number: ${accountNumber}
      - Account Name: ${accountName}
      - Request Date: ${requestDate}
      - Withdrawal ID: ${withdrawalId}
      
      Action Required:
      Please log in to the admin dashboard to review and process this withdrawal request.
      Ensure all bank details are correct before approving the payment.
      
      Admin Dashboard: https://lifecare-connect.web.app/admin/withdrawals
    `
  };

  try {
    await sgMail.send(msg);
    console.log(`Admin withdrawal notification sent for ${role} ${userName}: ${formattedAmount}`);
    res.status(200).send('Admin withdrawal notification sent successfully');
  } catch (error) {
    console.error('Failed to send admin withdrawal notification:', error);
    res.status(500).send('Failed to send admin withdrawal notification');
  }
});