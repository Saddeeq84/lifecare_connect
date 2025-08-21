const functions = require('firebase-functions');
const admin = require('firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp();
}

// Send FCM notification to a user by userId
exports.sendNotificationToUser = functions.https.onCall(async (data, context) => {
  const { userId, title, body } = data;
  if (!userId || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'userId, title, and body are required.');
  }
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  if (!userDoc.exists || !userDoc.data().fcmToken) {
    throw new functions.https.HttpsError('not-found', 'User or FCM token not found.');
  }
  const fcmToken = userDoc.data().fcmToken;
  // Check notification preferences
  let notificationsEnabled = true;
  let appointmentReminders = true;
  let healthTipNotifications = true;
  let emailNotifications = true;
  let smsNotifications = true;
  // Patient: settings/preferences subcollection
  const settingsDoc = await admin.firestore().collection('users').doc(userId).collection('settings').doc('preferences').get();
  if (settingsDoc.exists) {
    const prefs = settingsDoc.data();
    notificationsEnabled = prefs.notificationsEnabled ?? true;
    appointmentReminders = prefs.appointmentReminders ?? true;
    healthTipNotifications = prefs.healthTipNotifications ?? true;
  }
  // CHW/Doctor/Admin: main doc fields
  notificationsEnabled = userDoc.data().notificationsEnabled ?? notificationsEnabled;
  emailNotifications = userDoc.data().emailNotifications ?? emailNotifications;
  smsNotifications = userDoc.data().smsNotifications ?? smsNotifications;
  // Only send notification if enabled
  if (!notificationsEnabled) {
    return { success: false, reason: 'User has disabled notifications.' };
  }
  // Optionally, filter by event type (title/body)
  // Example: skip appointment reminders if disabled
  if (title && title.toLowerCase().includes('appointment') && appointmentReminders === false) {
    return { success: false, reason: 'User has disabled appointment reminders.' };
  }
  if (title && title.toLowerCase().includes('health tip') && healthTipNotifications === false) {
    return { success: false, reason: 'User has disabled health tip notifications.' };
  }
  const message = {
    token: fcmToken,
    notification: {
      title,
      body,
    },
    data: {
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
  };
  try {
    await admin.messaging().send(message);
    return { success: true };
  } catch (err) {
    throw new functions.https.HttpsError('internal', err.message || 'Failed to send notification');
  }
});
