# CarryGo

CarryGo is a Flutter mobile app for Nigeria that connects customers who want to send items or run errands within a city to verified bike riders.

## Features

- Customer, rider, and admin roles
- Customer registration and login with Firebase Authentication
- Rider registration with document links, bike plate details, and admin approval
- Rider profile photo, ID card, bike details, license/required document links, and bank account details
- Pick-up and drop-off locations with GPS coordinates
- Sender and receiver contact details
- Parcel description
- Informal parcel size: Small, Medium, Large, Extra Large
- Informal parcel weight: Light, Medium, Heavy
- Fragility: Not fragile, Fragile, Very fragile
- Item type: Documents, Food, Groceries, Clothes, Medicine, Electronics, Other
- Delivery cost estimate based on distance, size, weight, urgency, and city
- City selection includes the 36 Nigerian state capitals
- Paystack payment initialization records in Firestore
- Rider accept/reject flow
- Rider online/offline availability, earnings, completed jobs, and ratings
- Live order status tracking through Firestore streams
- In-app call/WhatsApp contact prompts
- Delivery confirmation OTP
- Ratings and reviews
- Admin dashboard for users, riders, orders, payments, complaints, and pricing settings

## Stack

- Flutter for the mobile app
- Firebase Authentication for login
- Cloud Firestore for users, rider verification, orders, payments, reviews, and admin data
- Firebase Cloud Messaging can be added for push notifications
- Google Maps and Geolocator for location/GPS coordinates
- Paystack for payment initialization and verification through a backend or Cloud Function

## Setup

1. Ensure Flutter is installed: `flutter --version`
2. Agree to Xcode license (macOS): `sudo xcodebuild -license`
3. Navigate to the project: `cd CarryGo`
4. Install dependencies: `flutter pub get`
5. Set up Firebase:
   - Create a Firebase project
   - Add Android/iOS apps
   - Download google-services.json (Android) and GoogleService-Info.plist (iOS)
   - Place them in android/app/ and ios/Runner/ respectively
6. Enable Authentication and Firestore in Firebase console
7. Run the app: `flutter run`

## Cost Calculation

Formula:

`total = round_up_to_50((city base fare + max(distanceKm, 1) * 180 + size fee + weight fee) * urgency multiplier * weather/traffic multiplier)`

`platform commission = round_up_to_50(total * 15%)`

`rider payout = total - platform commission`

Size examples:

- Small: envelope, documents, medicine
- Medium: food pack, small bag, shoes
- Large: grocery bag, small carton
- Extra Large: big carton or bulky item

Weight feel:

- Light: can be carried with one hand
- Medium: needs two hands but easy to carry
- Heavy: difficult to carry or needs extra care

Fragility:

- Not fragile
- Fragile
- Very fragile

Item type:

- Documents
- Food
- Groceries
- Clothes
- Medicine
- Electronics
- Other

Warning shown to customers:

Riders may reject wrongly described items or request admin review.

Pricing inputs:

- City base fare: default NGN 850, with configured city overrides such as Lagos NGN 900, Port Harcourt NGN 950, Ibadan NGN 800, Kano NGN 850, Kaduna NGN 850
- Distance rate: NGN 180 per km, minimum billable distance 1 km
- Size fees: Small NGN 0, Medium NGN 250, Large NGN 500, Extra Large NGN 850
- Weight fees: Light NGN 0, Medium NGN 300, Heavy NGN 650
- Urgency: Normal 1.0x, Express 1.35x
- Weather/traffic: Clear 1.0x, Rain 1.15x, Heavy traffic 1.2x, Rain + heavy traffic 1.35x
- Platform commission: 15%

Example prices:

- Lagos, 3 km, Small documents, Light, Normal, Clear: total NGN 1,450, platform NGN 250, rider payout NGN 1,200
- Ibadan, 5 km, Medium food pack, Medium weight, Express, Clear: total NGN 3,050, platform NGN 500, rider payout NGN 2,550
- Port Harcourt, 8 km, Extra Large bulky item, Heavy, Express, Rain + heavy traffic: total NGN 7,100, platform NGN 1,100, rider payout NGN 6,000

Edge cases:

- Distance below 1 km is billed as 1 km.
- Unknown city uses the default city base fare.
- Unknown size, weight, urgency, or condition falls back to the safest default fee/multiplier.
- Very bulky or unsafe items should be handled by manual support/admin pricing.
- Real Paystack verification should be completed server-side before moving the order into rider matching.

## Location System

- Customers can use current GPS for pick-up.
- Customers can type/search an address manually and save it with coordinates.
- Customers can move a pin on Google Maps for both pick-up and drop-off.
- Pick-up and drop-off latitude/longitude are used for distance, duration, and pricing.
- Riders and admins can open a route view with pick-up/drop-off markers and a route line.
- Estimated duration uses an in-city bike speed assumption plus a small pickup buffer; production can replace this with Google Directions API duration.

Order location fields stored in Firestore:

- `pickup_address`
- `pickup_latitude`
- `pickup_longitude`
- `dropoff_address`
- `dropoff_latitude`
- `dropoff_longitude`
- `distance_km`
- `estimated_duration_minutes`

## Paystack Payment Flow

CarryGo keeps Paystack secrets on the backend only.

Flow:

1. Customer creates an order.
2. App calculates delivery fee, platform commission, and rider payout.
3. App requests Paystack initialization from the backend.
4. Backend calls Paystack `/transaction/initialize`.
5. Customer pays before rider assignment.
6. App/backend verifies the transaction with Paystack `/transaction/verify/:reference`.
7. Webhook `charge.success` also marks payment as paid if verification happens asynchronously.
8. Order changes to `searching_rider`, so riders can receive the job request.
9. After OTP delivery confirmation, a `payouts/{orderId}` record is created for rider settlement.
10. Platform keeps the commission.

Payment states:

- `initialized`
- `paid`
- `failed`
- `refund_requested`
- `refund_processing`

Failed payments keep the order in `pending_payment` so the customer can retry.

Refund/dispute flow:

- Customer submits a dispute/refund reason.
- App creates a `complaints` record and marks payment as `refund_requested`.
- Backend can call Paystack `/refund` and update payment to `refund_processing`.

Optional Paystack split payment:

- Create rider subaccounts in Paystack.
- Send `riderSubaccount` to the backend initialize endpoint.
- Backend passes `subaccount`, `transaction_charge`, and `bearer` to Paystack.

Backend example:

- See `backend/paystack_backend_example.js` for initialize, verify, webhook, refund, and optional split-payment handling.

## Firestore Schema

See `docs/firestore_schema.md` for the full CarryGo Firestore database structure, including field names, data types, purpose, example values, and order statuses.

## Project Structure

- lib/
  - main.dart: App entry point
  - providers/: State management
    - auth_provider.dart: Authentication
    - order_provider.dart: Orders
  - screens/: UI screens
    - login_screen.dart: Login/Signup
    - home_screen.dart: Role-based home
    - customer_home.dart: Customer dashboard
    - delivery_home.dart: Delivery dashboard
    - admin_dashboard.dart: Admin dashboard
    - create_order_screen.dart: Order creation
  - models/: Data models
    - app_user.dart: Role/profile model
    - order.dart: Order model

## Dependencies

- firebase_core
- firebase_auth
- cloud_firestore
- google_maps_flutter
- geolocator
- provider
