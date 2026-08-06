const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Deletes Firebase Auth user when staff is deleted from Firestore
exports.deleteFirebaseAuthUser = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed. Use POST.' });
    return;
  }

  try {
    const { email } = req.body;

    if (!email) {
      res.status(400).json({ error: 'Email is required' });
      return;
    }

    console.log(`[DeleteAuthUser] Attempting to delete Firebase Auth user: ${email}`);

    // Get user by email
    let user;
    try {
      user = await admin.auth().getUserByEmail(email);
      console.log(`[DeleteAuthUser] Found user: ${user.uid}`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log(`[DeleteAuthUser] User not found in Firebase Auth: ${email}`);
        res.status(200).json({ 
          success: true, 
          message: 'User does not exist in Firebase Auth (already deleted or never created)',
          email: email
        });
        return;
      }
      throw error;
    }

    // Delete the user
    await admin.auth().deleteUser(user.uid);
    console.log(`[DeleteAuthUser] ✅ Successfully deleted Firebase Auth user: ${user.uid}`);

    res.status(200).json({ 
      success: true, 
      message: 'Firebase Auth user deleted successfully',
      email: email,
      uid: user.uid
    });

  } catch (error) {
    console.error('[DeleteAuthUser] ❌ Error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to delete Firebase Auth user',
      details: error.message 
    });
  }
});
