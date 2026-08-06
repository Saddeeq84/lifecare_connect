// Firebase Environment Configuration Loader
// This script loads Firebase configuration from environment variables
// Place your actual API keys in environment variables, never in code!

(function() {
  // Load configuration from environment or set defaults
  window.ENV_FIREBASE_API_KEY = process.env.FIREBASE_API_KEY || 'YOUR_API_KEY_HERE';
  window.ENV_FIREBASE_SENDER_ID = process.env.FIREBASE_SENDER_ID || 'YOUR_SENDER_ID_HERE';
  window.ENV_FIREBASE_APP_ID = process.env.FIREBASE_APP_ID || 'YOUR_APP_ID_HERE';
  window.ENV_FIREBASE_MEASUREMENT_ID = process.env.FIREBASE_MEASUREMENT_ID || 'YOUR_MEASUREMENT_ID_HERE';
  
  // For local development, you can temporarily set these here (but never commit!)
  // window.ENV_FIREBASE_API_KEY = 'your_actual_key_for_local_testing';
  
  console.log('🔐 Firebase environment configuration loaded');
})();