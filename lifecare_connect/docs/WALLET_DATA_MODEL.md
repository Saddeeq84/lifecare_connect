// Firestore Wallet Data Model (for documentation)
// Collection: wallets
// Document ID: userId (same as Firebase Auth UID)
// Fields:
//   - balance: number (default 0)
//   - currency: string (e.g., 'NGN')
//   - updatedAt: timestamp
//   - transactions: array of maps (optional, for simple history)
//      - type: 'fund' | 'deduct' | 'refund'
//      - amount: number
//      - timestamp: timestamp
//      - description: string
//
// Example document:
// wallets/{userId} = {
//   balance: 5000,
//   currency: 'NGN',
//   updatedAt: <timestamp>,
//   transactions: [
//     { type: 'fund', amount: 5000, timestamp: <timestamp>, description: 'Funded via card' },
//     { type: 'deduct', amount: 2000, timestamp: <timestamp>, description: 'Appointment payment' }
//   ]
// }
