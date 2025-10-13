// Firebase Cloud Function for atomic wallet payment split
// Place this in your functions directory and deploy with `firebase deploy --only functions`

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Callable function: client calls this to pay for appointment
exports.walletPayment = functions.https.onCall(async (data, context) => {
  // Input validation
  const { patientId, providerId, adminId, totalFee, providerType } = data;
  if (!patientId || !providerId || !adminId || !totalFee) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields.');
  }
  const providerShare = Math.round(totalFee * 0.7);
  const adminShare = totalFee - providerShare;

  const walletsRef = admin.firestore().collection('wallets');
  const patientRef = walletsRef.doc(patientId);
  const providerRef = walletsRef.doc(providerId);
  const adminRef = walletsRef.doc(adminId);

  return admin.firestore().runTransaction(async (txn) => {
    // Patient wallet
    const patientDoc = await txn.get(patientRef);
    let patientBal = 0;
    if (patientDoc.exists && typeof patientDoc.data().balance === 'number') {
      patientBal = patientDoc.data().balance;
    }
    if (patientBal < totalFee) {
      throw new functions.https.HttpsError('failed-precondition', 'Insufficient patient wallet balance.');
    }
    // Deduct from patient
    txn.set(patientRef, {
      balance: patientBal - totalFee,
      currency: 'NGN',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      transactions: admin.firestore.FieldValue.arrayUnion({
        type: 'deduct',
        amount: totalFee,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Appointment payment',
      }),
    }, { merge: true });

    // Provider wallet
    const providerDoc = await txn.get(providerRef);
    let providerBal = 0;
    if (providerDoc.exists && typeof providerDoc.data().balance === 'number') {
      providerBal = providerDoc.data().balance;
    }
    txn.set(providerRef, {
      balance: providerBal + providerShare,
      currency: 'NGN',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      transactions: admin.firestore.FieldValue.arrayUnion({
        type: providerType === 'doctor' ? 'doctor_earning' : 'chw_earning',
        amount: providerShare,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Appointment earning',
      }),
    }, { merge: true });

    // Admin wallet
    const adminDoc = await txn.get(adminRef);
    let adminBal = 0;
    if (adminDoc.exists && typeof adminDoc.data().balance === 'number') {
      adminBal = adminDoc.data().balance;
    }
    txn.set(adminRef, {
      balance: adminBal + adminShare,
      currency: 'NGN',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      transactions: admin.firestore.FieldValue.arrayUnion({
        type: 'admin_commission',
        amount: adminShare,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: 'Admin commission from appointment',
      }),
    }, { merge: true });

    return { success: true, providerShare, adminShare };
  });
});
