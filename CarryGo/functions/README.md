# CarryGo Cloud Functions

This backend keeps payment, rider matching, delivery OTP, and payout logic off the mobile app.

## Functions

- `calculateDeliveryFee`
- `initializeMvpCollections`
- `initializePhase2Collections`
- `initializePhase3Collections`
- `initializePaystackPayment`
- `verifyPaystackPayment`
- `handlePaystackWebhook`
- `assignNearbyRiders`
- `sendOrderNotification`
- `confirmDeliveryOtp`
- `updateRiderEarnings`

## Required Environment Variables

Set these before deployment:

```bash
firebase functions:secrets:set PAYSTACK_SECRET_KEY
```

For local emulator or shell deployment environments, also make sure `PAYSTACK_SECRET_KEY` is available to Functions runtime.

Optional:

```bash
firebase functions:secrets:set ALLOWED_ORIGIN
```

## Deploy

```bash
cd functions
npm install
cd ..
firebase deploy --only functions,firestore:rules,firestore:indexes
```

After deployment, set the Flutter backend base URL in:

```text
lib/constants/payment_config.dart
```

Example:

```dart
static const paystackBackendBaseUrl =
    'https://us-central1-carrygo.cloudfunctions.net';
```

## Paystack Webhook URL

In the Paystack dashboard, set webhook URL to:

```text
https://us-central1-carrygo.cloudfunctions.net/handlePaystackWebhook
```

Payment status should be changed only by these Cloud Functions.
