// Export FCM notification sender
exports.sendNotificationToUser = require('./sendNotification').sendNotificationToUser;
require('dotenv').config();
const functions = require('firebase-functions');
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_KEY);

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
// Callable function: send bulk email to all approved users for a role
exports.sendBulkEmail = functions.region('europe-west2').https.onCall(async (data, context) => {
  try {
    // Only allow admin users
    if (!context.auth || !context.auth.token || !context.auth.token.admin) {
      console.error('Permission denied: User does not have admin claim.', context.auth);
      throw new functions.https.HttpsError('permission-denied', 'Only admins can send bulk emails.');
    }
    const { role, subject, message } = data;
    if (!role || !subject || !message) {
      console.error('Invalid arguments:', data);
      throw new functions.https.HttpsError('invalid-argument', 'Role, subject, and message are required.');
    }
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      admin.initializeApp();
    }
    const sgMail = require('@sendgrid/mail');
    sgMail.setApiKey(process.env.SENDGRID_KEY);
    let query = admin.firestore().collection('users').where('isApproved', '==', true);
    if (role !== 'all') {
      query = query.where('role', '==', role);
    }
    const snapshot = await query.get();
    const emails = snapshot.docs.map(doc => doc.data().email).filter(Boolean);
    if (emails.length === 0) {
      console.error('No approved users found for role:', role);
      throw new functions.https.HttpsError('not-found', 'No approved users found for this role.');
    }
    const fromEmail = 'admin@lifecare.rhemn.org.ng'; // Must be verified in SendGrid
    let sent = 0;
    let failed = 0;
    let errors = [];
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const to = data.email;
      const userId = doc.id;
      const msg = {
        to,
        from: fromEmail,
        subject,
        text: message,
      };
      try {
        await sgMail.send(msg);
        // Send push notification
        if (data.fcmToken) {
          const notificationFn = require('./sendNotification').sendNotificationToUser;
          await notificationFn({ userId, title: subject, body: message }, { auth: null });
        }
        sent++;
      } catch (err) {
        failed++;
        errors.push({ to, error: err.message });
        console.error(`Failed to send email to ${to}:`, err);
      }
    }
    return { sent, failed, errors };
  } catch (err) {
    console.error('sendBulkEmail crashed:', err);
    throw new functions.https.HttpsError('internal', err.message || 'Unknown error occurred in sendBulkEmail.');
  }
});

// Export approval/rejection email functions for deployment
exports.sendAccountApprovedEmail = require('./account_status_emails').sendAccountApprovedEmail;
exports.sendAccountRejectedEmail = require('./account_status_emails').sendAccountRejectedEmail;

// Callable function: send invitation email to patient registered by CHW
exports.sendPatientInviteEmail = functions.region('europe-west2').https.onCall(async (data, context) => {
  const admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  const sgMail = require('@sendgrid/mail');
  sgMail.setApiKey(process.env.SENDGRID_KEY);
  const { email, name } = data;
  if (!email || !name) {
    throw new functions.https.HttpsError('invalid-argument', 'Email and name are required.');
  }
  // Ensure the user exists in Firebase Auth before generating password reset link
  let link;
  try {
    let user;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (err) {
      // If user does not exist, create them
      if (err.code === 'auth/user-not-found') {
        user = await admin.auth().createUser({
          email,
          displayName: name,
        });
      } else {
        throw err;
      }
    }
    link = await admin.auth().generatePasswordResetLink(email, {
      url: 'https://lifecare-connect.web.app/login',
      handleCodeInApp: true,
    });
  } catch (err) {
    console.error('Error generating password reset link:', err);
    throw new functions.https.HttpsError('internal', 'Failed to generate password setup link.');
  }
  // Send invitation email with setup link
  const msg = {
    to: email,
    from: 'admin@lifecare.rhemn.org.ng',
    subject: 'Welcome to LifeCare! Set up your account',
    text: `Hello ${name},\n\nYou have been registered as a patient in LifeCare. Please set up your account by clicking the link below to choose your password:\n\n${link}\n\nIf you did not expect this email, please ignore it.`,
  };
  try {
    await sgMail.send(msg);
    // Send push notification
    if (user && user.uid) {
      const notificationFn = require('./sendNotification').sendNotificationToUser;
      await notificationFn({ userId: user.uid, title: 'Welcome to LifeCare!', body: 'You have been registered as a patient. Please set up your account.' }, { auth: null });
    }
    return { success: true };
  } catch (err) {
    console.error('Error sending invite email:', err);
    throw new functions.https.HttpsError('internal', 'Failed to send invitation email.');
  }
});

// Automatically set Content-Disposition:inline for all future PDF uploads
exports.setPdfInlineDisposition = require('./setPdfInlineDisposition').setPdfInlineDisposition;

// Firestore trigger: send approval email when user is approved
exports.sendApprovalEmailOnUserUpdate = functions.region('europe-west2').firestore.document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    // Only send email if isApproved changed from false to true
    if (!before.isApproved && after.isApproved) {
      const email = after.email;
      const name = after.fullName || after.name || after.displayName || '';
      const userId = context.params.userId;
      const sgMail = require('@sendgrid/mail');
      sgMail.setApiKey(process.env.SENDGRID_KEY);
      const msg = {
        to: email,
        from: 'admin@lifecare.rhemn.org.ng',
        subject: 'Account Approved',
        text: `Hello ${name}, your account has been approved and is now active. You can now login and start using the platform.`,
      };
      try {
        await sgMail.send(msg);
        // Send push notification
        if (after.fcmToken) {
          const notificationFn = require('./sendNotification').sendNotificationToUser;
          await notificationFn({ userId, title: 'Account Approved', body: 'Your account has been approved and is now active.' }, { auth: null });
        }
        console.log('Approval email sent to', email);
      } catch (err) {
        console.error('Failed to send approval email:', err);
      }
    }
    // Send rejection email if isRejected changed from false to true
    if (!before.isRejected && after.isRejected) {
      const email = after.email;
      const name = after.fullName || after.name || after.displayName || '';
      const reason = after.rejectionReason || 'No reason provided.';
      const userId = context.params.userId;
      const sgMail = require('@sendgrid/mail');
      sgMail.setApiKey(process.env.SENDGRID_KEY);
      const msg = {
        to: email,
        from: 'admin@lifecare.rhemn.org.ng',
        subject: 'Account Rejected',
        text: `Hello ${name}, your account was rejected for the following reason: ${reason}`,
      };
      try {
        await sgMail.send(msg);
        // Send push notification
        if (after.fcmToken) {
          const notificationFn = require('./sendNotification').sendNotificationToUser;
          await notificationFn({ userId, title: 'Account Rejected', body: `Your account was rejected: ${reason}` }, { auth: null });
        }
        console.log('Rejection email sent to', email);
      } catch (err) {
        console.error('Failed to send rejection email:', err);
      }
    }
    // Firestore trigger: send email when appointment is booked
exports.sendAppointmentBookedEmail = functions.region('europe-west2').firestore.document('appointments/{appointmentId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const email = data.patientEmail || data.userEmail || '';
    const name = data.patientName || data.userName || '';
    const date = data.date || data.appointmentDate || '';
    const userId = data.patientId || data.userId || '';
    const sgMail = require('@sendgrid/mail');
    sgMail.setApiKey(process.env.SENDGRID_KEY);
    const msg = {
      to: email,
      from: 'admin@lifecare.rhemn.org.ng',
      subject: 'Appointment Booked',
      text: `Hello ${name}, your appointment has been booked for ${date}. We will notify you when it is approved.`,
    };
    try {
      await sgMail.send(msg);
      // Send push notification
      if (data.fcmToken && userId) {
        const notificationFn = require('./sendNotification').sendNotificationToUser;
        await notificationFn({ userId, title: 'Appointment Booked', body: `Your appointment for ${date} has been booked.` }, { auth: null });
      }
      console.log('Appointment booked email sent to', email);
    } catch (err) {
      console.error('Failed to send appointment booked email:', err);
    }
    return null;
  });
});

// Firestore trigger: notify patient when appointment is approved
exports.sendAppointmentApprovedEmail = functions.region('europe-west2').firestore.document('appointments/{appointmentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    // Only send email if status changed to 'approved'
    if (before.status !== 'approved' && after.status === 'approved') {
      const email = after.patientEmail || after.userEmail || '';
      const name = after.patientName || after.userName || '';
      const date = after.date || after.appointmentDate || '';
      const userId = after.patientId || after.userId || '';
      const sgMail = require('@sendgrid/mail');
      sgMail.setApiKey(process.env.SENDGRID_KEY);
      const msg = {
        to: email,
        from: 'admin@lifecare.rhemn.org.ng',
        subject: 'Appointment Approved',
        text: `Hello ${name}, your appointment for ${date} has been approved. Please check your dashboard for details.`,
      };
      try {
        await sgMail.send(msg);
        // Send push notification
        if (after.fcmToken && userId) {
          const notificationFn = require('./sendNotification').sendNotificationToUser;
          await notificationFn({ userId, title: 'Appointment Approved', body: `Your appointment for ${date} has been approved.` }, { auth: null });
        }
        console.log('Appointment approved email sent to', email);
      } catch (err) {
        console.error('Failed to send appointment approved email:', err);
      }
    }
    return null;
  });
// Firestore trigger: send email to doctor when patient is referred
exports.sendReferralToDoctorEmail = functions.region('europe-west2').firestore.document('referrals/{referralId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (data.toProviderType === 'DOCTOR' && data.doctorEmail) {
      const email = data.doctorEmail;
      const doctorName = data.toProviderName || '';
      const patientName = data.patientName || '';
      const reason = data.reason || '';
      const doctorId = data.doctorId || '';
      const sgMail = require('@sendgrid/mail');
      sgMail.setApiKey(process.env.SENDGRID_KEY);
      const msg = {
        to: email,
        from: 'admin@lifecare.rhemn.org.ng',
        subject: 'New Patient Referral',
        text: `Hello Dr. ${doctorName}, you have a new patient referral: ${patientName}. Reason: ${reason}. Please review in your dashboard.`,
      };
      try {
        await sgMail.send(msg);
        // Send push notification
        if (data.doctorFcmToken && doctorId) {
          const notificationFn = require('./sendNotification').sendNotificationToUser;
          await notificationFn({ userId: doctorId, title: 'New Patient Referral', body: `You have a new referral for patient ${patientName}.` }, { auth: null });
        }
        console.log('Referral email sent to doctor:', email);
      } catch (err) {
        console.error('Failed to send referral email to doctor:', err);
      }
    }
    return null;
  });

// Firestore trigger: send email to CHW when doctor accepts referral
exports.sendReferralAcceptedToCHWEmail = functions.region('europe-west2').firestore.document('referrals/{referralId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (
      before.status !== 'Accepted' &&
      after.status === 'Accepted' &&
      after.fromProviderType === 'CHW' &&
      after.chwEmail
    ) {
      const email = after.chwEmail;
      const chwName = after.fromProviderName || '';
      const doctorName = after.toProviderName || '';
      const patientName = after.patientName || '';
      const chwId = after.chwId || '';
      const sgMail = require('@sendgrid/mail');
      sgMail.setApiKey(process.env.SENDGRID_KEY);
      const msg = {
        to: email,
        from: 'admin@lifecare.rhemn.org.ng',
        subject: 'Referral Accepted',
        text: `Hello ${chwName}, your referral for patient ${patientName} has been accepted by Dr. ${doctorName}.`,
      };
      try {
        await sgMail.send(msg);
        // Send push notification
        if (after.chwFcmToken && chwId) {
          const notificationFn = require('./sendNotification').sendNotificationToUser;
          await notificationFn({ userId: chwId, title: 'Referral Accepted', body: `Your referral for patient ${patientName} has been accepted by Dr. ${doctorName}.` }, { auth: null });
        }
        console.log('Referral accepted email sent to CHW:', email);
      } catch (err) {
        console.error('Failed to send referral accepted email to CHW:', err);
      }
    }
    return null;
  });