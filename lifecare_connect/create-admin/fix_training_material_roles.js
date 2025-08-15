const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

async function fixTrainingMaterialTargetRole(docId, correctRole) {
  const docRef = db.collection('training_materials').doc(docId);
  await docRef.update({ targetRole: correctRole });
  console.log(`Updated ${docId} to targetRole: ${correctRole}`);
}

async function bulkFixTargetRoles(updates) {
  for (const { docId, correctRole } of updates) {
    await fixTrainingMaterialTargetRole(docId, correctRole);
  }
  console.log('Bulk update complete.');
}

// Example usage:
// bulkFixTargetRoles([
//   { docId: 'yourDocId1', correctRole: 'doctor' },
//   { docId: 'yourDocId2', correctRole: 'chw' },
// ]);

module.exports = { fixTrainingMaterialTargetRole, bulkFixTargetRoles };
