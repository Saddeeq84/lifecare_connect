const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Helper: delete documents returned by a query in chunks
async function deleteQueryBatch(db, query, batchSize = 400) {
  const snapshot = await query.get();
  if (snapshot.empty) return 0;

  let deleted = 0;
  let batch = db.batch();
  let ops = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    ops++;
    deleted++;

    if (ops >= batchSize) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) await batch.commit();
  return deleted;
}

exports.deleteAccount = functions.https.onCall(async (data, context) => {
  console.log('deleteAccount called with:', { data, authUid: context.auth?.uid });
  
  let callerUid = null;
  let targetUid = null;
  let isAdmin = false;

  // Check if authenticated via Firebase Auth (for Firebase Auth users)
  if (context.auth) {
    callerUid = context.auth.uid;
    const callerClaims = context.auth.token || {};
    isAdmin = callerClaims.admin === true || callerClaims.role === 'admin';
    targetUid = (isAdmin && data && data.targetUid) ? data.targetUid : callerUid;
  } 
  // Check if authenticated via phone number (Termii users)
  else if (data && data.userId) {
    // For Termii users, the Flutter app must pass userId explicitly
    callerUid = data.userId;
    targetUid = data.userId; // Termii users can only delete their own account
    console.log('Phone-authenticated user deletion:', targetUid);
  } 
  else {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated or with userId for phone users.');
  }

  console.log('Deleting account for UID:', targetUid, 'by caller:', callerUid);

  const db = admin.firestore();
  const result = { deleted: [], warnings: [], errors: [] };

  // Capture user email for audit
  let userEmail = null;
  try {
    const rec = await admin.auth().getUser(targetUid);
    userEmail = rec.email || null;
  } catch (e) {
    // user may not exist in Auth
    result.warnings.push(`Auth user lookup failed: ${e.message}`);
  }

  try {
    // 1) Delete direct profile documents (if present)
    const directCollections = ['users', 'chw_profiles', 'wallets'];
    for (const col of directCollections) {
      try {
        const ref = db.collection(col).doc(targetUid);
        const snap = await ref.get();
        if (snap.exists) {
          await ref.delete();
          result.deleted.push(`${col}/${targetUid}`);
        }
      } catch (e) {
        result.errors.push(`Failed to delete ${col}/${targetUid}: ${e.message}`);
      }
    }

    // 2) Delete documents referencing the user (queries)
    const queriesToDelete = [
      { collection: 'withdrawals', field: 'userId' },
      { collection: 'withdrawals', field: 'providerId' },
      { collection: 'pendingPayments', field: 'providerId' },
      { collection: 'wallet_transactions', field: 'userId' },
      { collection: 'notifications', field: 'userId' },
      { collection: 'patients', field: 'ownerId' },
      { collection: 'appointments', field: 'providerId' },
      { collection: 'appointments', field: 'patientId' },
      { collection: 'medical_records', field: 'patientId' },
      { collection: 'medical_records', field: 'doctorId' },
    ];

    for (const q of queriesToDelete) {
      try {
        const query = db.collection(q.collection).where(q.field, '==', targetUid);
        const deletedCount = await deleteQueryBatch(db, query, 400);
        if (deletedCount > 0) result.deleted.push(`${deletedCount} docs from ${q.collection} where ${q.field}==${targetUid}`);
      } catch (e) {
        // If the collection doesn't exist it's fine
        result.warnings.push(`Query delete for ${q.collection}.${q.field} failed: ${e.message}`);
      }
    }

    // 3) Remove auth user (if exists)
    try {
      await admin.auth().deleteUser(targetUid);
      result.deleted.push(`auth/${targetUid}`);
    } catch (e) {
      // If deletion fails, record it
      result.warnings.push(`Auth delete failed: ${e.message}`);
    }

    // 4) Audit log the deletion (keeps minimal record)
    try {
      await db.collection('deletedUsers').add({
        uid: targetUid,
        email: userEmail,
        deletedBy: callerUid,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      result.deleted.push('deletedUsers/logged');
    } catch (e) {
      result.warnings.push(`Failed to write audit log: ${e.message}`);
    }

    return { success: true, result };
  } catch (err) {
    console.error('deleteAccount error:', err);
    throw new functions.https.HttpsError('internal', 'Failed to delete account');
  }
});
