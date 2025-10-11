// Script to automatically fix unreadCounts for all patient messages
// Run with: node fix_unread_counts.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // <-- Make sure this file exists or use your own credentials

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function fixUnreadCounts() {
  const messagesRef = db.collection('messages');
  const snapshot = await messagesRef.get();
  let updated = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    // Only fix if this is a referral notification or missing unreadCounts
    if (
      data.type === 'referral_notification' ||
      !data.unreadCounts ||
      typeof data.unreadCounts !== 'object'
    ) {
      const receiverId = data.receiverId;
      if (!receiverId) continue;
      // Patch unreadCounts
      const unreadCounts = {};
      unreadCounts[receiverId] = 1;
      await doc.ref.update({ unreadCounts });
      updated++;
      console.log(`Fixed unreadCounts for message ${doc.id}`);
    }
  }
  console.log(`\nDone. Updated ${updated} message(s).`);
}

fixUnreadCounts().catch(console.error);
