# CarryGo Firestore Database Structure

This schema is designed for a Nigerian errand delivery app with Customer, Rider, and Admin roles.

## Order Statuses

Use these values in `orders.status`:

| Status | Purpose | Example transition |
|---|---|---|
| `draft` | Order has been created locally or saved before payment initialization. | Customer starts request |
| `pending_payment` | Paystack transaction is initialized, but not verified as paid. | Order awaits payment |
| `paid` | Payment has been verified, before rider search starts. | Optional short-lived status |
| `searching_rider` | Paid order is visible to eligible nearby riders. | Rider matching starts |
| `accepted` | A rider accepted the job. | Rider assigned |
| `picked_up` | Rider confirmed item pick-up. | Item collected |
| `in_transit` | Rider is moving to drop-off. | Live delivery stage |
| `delivered` | Receiver OTP confirmed delivery. | Job complete |
| `cancelled` | Customer/admin cancelled before completion. | Cancelled request |
| `disputed` | Customer, rider, or admin opened a complaint/refund review. | Dispute open |
| `refunded` | Refund completed. | Payment reversed |

## `users`

General account records for customers, riders, and admins.

Recommended core shape:

| Field | Type | Purpose | Example |
|---|---|---|---|
| `name` | string | User display name. | `Ada Okafor` |
| `phone` | string | User phone number. | `08012345678` |
| `email` | string | User email if provided. | `ada@example.com` |
| `role` | string | App role. | `customer`, `rider`, `admin` |
| `isApproved` | boolean | Whether the account can use role-specific protected features. | `true` |
| `createdAt` | timestamp | Account creation time. | `2026-06-26T12:00:00Z` |

| Field | Type | Purpose | Example |
|---|---|---|---|
| `id` | string | Firebase Auth UID, also document ID. | `uid_abc123` |
| `name` | string | Simple display-name alias for backend/admin tooling. | `Ada Okafor` |
| `email` | string | User email if provided. | `ada@example.com` |
| `authEmail` | string | Firebase-compatible auth email, including phone-only generated email. | `phone-2348012345678@phone.carrygo.local` |
| `authMethod` | string | Signup method. | `phone` |
| `fullName` | string | User display name. | `Ada Okafor` |
| `phone` | string | User phone number as entered/displayed. | `08012345678` |
| `phoneNormalized` | string | Normalized phone for lookup/login. | `+2348012345678` |
| `role` | string | User role. | `customer`, `rider`, `admin` |
| `isApproved` | boolean | Simple approval flag. Customers/admins are normally true; riders become true after verification. | `true` |
| `city` | string | Primary operating city. | `Lagos` |
| `riderStatus` | string | Rider verification state. | `pending`, `approved`, `rejected`, `not_applicable` |
| `profilePhotoUrl` | string | Rider profile photo URL. | `https://.../profile.jpg` |
| `idCardUrl` | string | Rider ID card upload URL. | `https://.../nin.jpg` |
| `bikePlateNumber` | string | Rider bike plate, if applicable. | `KJA-123-QA` |
| `bikeModel` | string | Rider bike make/model. | `Bajaj Boxer` |
| `bikeColor` | string | Rider bike color. | `Red` |
| `riderLicenseUrl` | string | Rider license or required document URL. | `https://.../license.jpg` |
| `bankName` | string | Rider settlement bank. | `GTBank` |
| `bankAccountNumber` | string | Rider account number. | `0123456789` |
| `bankAccountName` | string | Rider account name. | `Musa Bello` |
| `documentUrls` | array<string> | Rider document links. | `["https://.../license.jpg"]` |
| `createdAt` | timestamp | Account creation time. | `2026-06-26T12:00:00Z` |
| `updatedAt` | timestamp | Last profile update. | `2026-06-26T12:20:00Z` |

## `riders`

Rider operational profile. Use document ID equal to rider UID. This can mirror rider fields from `users` but keeps dispatch/verification data separate.

Recommended core shape:

| Field | Type | Purpose | Example |
|---|---|---|---|
| `bikeNumber` | string | Bike or plate identifier. | `KJA-123-QA` |
| `city` | string | Rider operating city. | `Lagos` |
| `isVerified` | boolean | Whether admin has verified the rider. | `true` |
| `isOnline` | boolean | Whether rider is currently available. | `false` |
| `currentLatitude` | number/null | Last known rider latitude. | `6.5244` |
| `currentLongitude` | number/null | Last known rider longitude. | `3.3792` |

| Field | Type | Purpose | Example |
|---|---|---|---|
| `userId` | string | Link to `users/{userId}`. | `uid_rider123` |
| `bikeNumber` | string | Simple bike identifier alias. | `KJA-123-QA` |
| `fullName` | string | Rider name for admin/dispatch. | `Musa Bello` |
| `phone` | string | Rider contact phone. | `+2348030000000` |
| `city` | string | Rider operating city. | `Lagos` |
| `status` | string | Availability status. | `offline`, `available`, `busy`, `suspended` |
| `isOnline` | boolean | Simple online/offline flag. | `true` |
| `verificationStatus` | string | Admin verification status. | `pending`, `approved`, `rejected` |
| `isVerified` | boolean | Simple verification flag. | `true` |
| `profilePhotoUrl` | string | Rider profile photo URL. | `https://.../profile.jpg` |
| `idCardUrl` | string | Rider ID card upload URL. | `https://.../nin.jpg` |
| `bikePlateNumber` | string | Bike identifier. | `APP-456-XY` |
| `bikeModel` | string | Bike make/model. | `Bajaj Boxer` |
| `bikeColor` | string | Bike color. | `Red` |
| `riderLicenseUrl` | string | Rider license or required document URL. | `https://.../license.jpg` |
| `documentUrls` | array<string> | Uploaded/linked documents. | `["https://.../nin.pdf"]` |
| `bankName` | string | Settlement bank. | `GTBank` |
| `bankAccountNumber` | string | Settlement account number. | `0123456789` |
| `bankAccountName` | string | Settlement account name. | `Musa Bello` |
| `currentLatitude` | number | Last known rider latitude. | `6.5244` |
| `currentLongitude` | number | Last known rider longitude. | `3.3792` |
| `paystackSubaccount` | string | Optional Paystack split subaccount. | `ACCT_abc123` |
| `ratingAverage` | number | Average rider rating. | `4.7` |
| `completedOrders` | number | Completed job count. | `128` |
| `createdAt` | timestamp | Rider profile creation time. | `2026-06-26T12:00:00Z` |
| `approvedAt` | timestamp | Admin approval time. | `2026-06-27T09:00:00Z` |

## `orders`

Delivery/errand request records.

CarryGo writes the following required snake_case fields on every order:

| Field | Type | Example |
|---|---|---|
| `customer_id` | string | `uid_customer123` |
| `rider_id` | string/null | `uid_rider123` |
| `pickup_address` | string | `Shoprite, Ikeja City Mall` |
| `pickup_latitude` | number | `6.6146` |
| `pickup_longitude` | number | `3.3580` |
| `dropoff_address` | string | `Yaba Bus Stop` |
| `dropoff_latitude` | number | `6.5170` |
| `dropoff_longitude` | number | `3.3841` |
| `parcel_size` | string | `Small` |
| `parcel_weight` | string | `Light` |
| `distance_km` | number | `8.4` |
| `delivery_fee` | number | `2500` |
| `payment_status` | string | `paid` |
| `order_status` | string | `searching_rider` |
| `created_at` | timestamp | `2026-06-26T12:00:00Z` |

| Field | Type | Purpose | Example |
|---|---|---|---|
| `customerId` | string | Customer UID. | `uid_customer123` |
| `riderId` | string/null | Assigned rider UID. | `uid_rider123` |
| `city` | string | Order city. | `Lagos` |
| `status` | string | Order lifecycle status. | `searching_rider` |
| `paymentStatus` | string | Payment state. | `paid` |
| `paymentReference` | string | Paystack reference. | `CG-1780000000-orderId` |
| `pickup_address` | string | Pick-up address/landmark. | `Shoprite, Ikeja City Mall` |
| `pickup_latitude` | number | Pick-up latitude. | `6.6146` |
| `pickup_longitude` | number | Pick-up longitude. | `3.3580` |
| `dropoff_address` | string | Drop-off address/landmark. | `Yaba Bus Stop` |
| `dropoff_latitude` | number | Drop-off latitude. | `6.5170` |
| `dropoff_longitude` | number | Drop-off longitude. | `3.3841` |
| `distance_km` | number | Estimated distance in km. | `8.4` |
| `estimated_duration_minutes` | number | Estimated travel time. | `28` |
| `senderName` | string | Sender name. | `Ada` |
| `senderPhone` | string | Sender contact. | `08012345678` |
| `receiverName` | string | Receiver name. | `Tunde` |
| `receiverPhone` | string | Receiver contact. | `08123456789` |
| `parcelDescription` | string | Plain item description. | `Small bag with medicine` |
| `itemType` | string | Item category. | `Medicine` |
| `parcelSize` | string | Simple size category. | `Small` |
| `parcelWeight` | string | Weight feel category. | `Light` |
| `fragility` | string | Fragility category. | `Fragile` |
| `urgency` | string | Delivery urgency. | `Normal`, `Express` |
| `condition` | string | Weather/traffic multiplier label. | `Heavy traffic` |
| `cost` | number | Total customer charge in NGN. | `2500` |
| `platformCommission` | number | Platform commission in NGN. | `400` |
| `riderPayout` | number | Rider payout in NGN. | `2100` |
| `otp` | string | Receiver delivery confirmation code. | `4921` |
| `pickupOtp` | string | Sender pick-up confirmation code. | `1842` |
| `rejectedRiderIds` | array<string> | Riders that rejected this request. | `["uid_rider456"]` |
| `createdAt` | timestamp | Order creation time. | `2026-06-26T12:00:00Z` |
| `acceptedAt` | timestamp | Rider acceptance time. | `2026-06-26T12:05:00Z` |
| `pickupConfirmedAt` | timestamp | Pick-up confirmation time. | `2026-06-26T12:15:00Z` |
| `inTransitAt` | timestamp | Transit start time. | `2026-06-26T12:18:00Z` |
| `deliveredAt` | timestamp | Delivery completion time. | `2026-06-26T12:45:00Z` |

## `payments`

Paystack and settlement records.

| Field | Type | Purpose | Example |
|---|---|---|---|
| `orderId` | string | Related order ID. | `order_123` |
| `customerId` | string | Paying customer UID. | `uid_customer123` |
| `email` | string | Paystack customer email. | `ada@example.com` |
| `provider` | string | Payment provider. | `paystack` |
| `reference` | string | Paystack reference, usually document ID. | `CG-1780000000-orderId` |
| `amountKobo` | number | Amount charged in kobo. | `250000` |
| `currency` | string | Payment currency. | `NGN` |
| `status` | string | Payment status. | `initialized`, `paid`, `failed`, `refund_requested`, `refund_processing`, `refunded` |
| `authorizationUrl` | string | Paystack checkout URL. | `https://checkout.paystack.com/...` |
| `accessCode` | string | Paystack access code. | `access_abc123` |
| `verificationStatus` | string | Paystack verification result. | `success` |
| `failureReason` | string | Failed payment reason. | `Insufficient funds` |
| `platformCommission` | number | Platform commission in NGN. | `400` |
| `riderPayout` | number | Rider payout in NGN. | `2100` |
| `split.enabled` | boolean | Whether Paystack split is used. | `true` |
| `split.riderSubaccount` | string/null | Rider Paystack subaccount. | `ACCT_abc123` |
| `createdAt` | timestamp | Payment initialization time. | `2026-06-26T12:00:00Z` |
| `paidAt` | timestamp | Payment success time. | `2026-06-26T12:02:00Z` |
| `refundRequestedAt` | timestamp | Refund request time. | `2026-06-26T13:00:00Z` |

## `pricing_rules`

Admin-controlled pricing rules.

| Field | Type | Purpose | Example |
|---|---|---|---|
| `name` | string | Rule name. | `Default Lagos Pricing` |
| `city` | string | City this rule applies to. | `Lagos` |
| `baseFare` | number | City base fare in NGN. | `900` |
| `distanceRatePerKm` | number | Per-km rate in NGN. | `180` |
| `minimumBillableDistanceKm` | number | Minimum billable distance. | `1` |
| `sizeFees` | map<string, number> | Fees by size category. | `{Small: 0, Medium: 250}` |
| `weightFees` | map<string, number> | Fees by weight feel. | `{Light: 0, Heavy: 650}` |
| `urgencyMultipliers` | map<string, number> | Urgency multipliers. | `{Normal: 1, Express: 1.35}` |
| `conditionMultipliers` | map<string, number> | Weather/traffic multipliers. | `{Rain: 1.15}` |
| `platformCommissionRate` | number | Commission rate. | `0.15` |
| `isActive` | boolean | Whether rule is active. | `true` |
| `updatedBy` | string | Admin UID that changed rule. | `uid_admin123` |
| `updatedAt` | timestamp | Last change time. | `2026-06-26T12:00:00Z` |

## `cities`

Supported cities and dispatch settings.

| Field | Type | Purpose | Example |
|---|---|---|---|
| `name` | string | City display name. | `Lagos` |
| `state` | string | Nigerian state. | `Lagos` |
| `isActive` | boolean | Whether CarryGo operates there. | `true` |
| `baseFare` | number | Default city base fare. | `900` |
| `centerLatitude` | number | City center latitude. | `6.5244` |
| `centerLongitude` | number | City center longitude. | `3.3792` |
| `serviceRadiusKm` | number | Dispatch radius. | `35` |
| `createdAt` | timestamp | City setup time. | `2026-06-26T12:00:00Z` |

## `ratings`

Ratings and reviews, separate from orders for analytics.

| Field | Type | Purpose | Example |
|---|---|---|---|
| `orderId` | string | Related order. | `order_123` |
| `customerId` | string | Reviewer UID. | `uid_customer123` |
| `riderId` | string | Reviewed rider UID. | `uid_rider123` |
| `rating` | number | Rating value. | `5` |
| `review` | string | Review text. | `Fast and polite` |
| `createdAt` | timestamp | Review time. | `2026-06-26T13:00:00Z` |

## `complaints`

Disputes, refund requests, wrong item description reports, and admin reviews.

| Field | Type | Purpose | Example |
|---|---|---|---|
| `orderId` | string | Related order. | `order_123` |
| `paymentReference` | string | Paystack reference. | `CG-1780000000-orderId` |
| `customerId` | string | Customer UID. | `uid_customer123` |
| `riderId` | string/null | Rider UID if assigned. | `uid_rider123` |
| `type` | string | Complaint type. | `refund`, `wrong_item`, `damaged_item`, `late_delivery` |
| `reason` | string | User/admin explanation. | `Item was not delivered` |
| `status` | string | Complaint status. | `open`, `admin_review`, `refund_requested`, `resolved`, `rejected` |
| `amountKobo` | number | Refund amount requested. | `250000` |
| `adminId` | string/null | Admin handling case. | `uid_admin123` |
| `createdAt` | timestamp | Complaint creation time. | `2026-06-26T13:00:00Z` |
| `resolvedAt` | timestamp/null | Resolution time. | `2026-06-27T10:00:00Z` |

## `notifications`

In-app and push notification records.

| Field | Type | Purpose | Example |
|---|---|---|---|
| `userId` | string/null | Target user UID, or null for role-wide notifications. | `uid_customer123` |
| `role` | string | Target role. | `customer` |
| `title` | string | Notification title. | `Rider assigned` |
| `body` | string | Notification message. | `Musa accepted your delivery` |
| `type` | string | Notification type. | `order_status`, `payment`, `complaint` |
| `orderId` | string/null | Related order. | `order_123` |
| `isRead` | boolean | Read/unread state. | `false` |
| `createdAt` | timestamp | Creation time. | `2026-06-26T12:05:00Z` |

## `admin_logs`

Auditable admin actions.

| Field | Type | Purpose | Example |
|---|---|---|---|
| `adminId` | string | Admin UID. | `uid_admin123` |
| `action` | string | Action performed. | `approve_rider` |
| `entityType` | string | Affected collection/entity. | `riders` |
| `entityId` | string | Affected document ID. | `uid_rider123` |
| `before` | map | Previous values. | `{verificationStatus: "pending"}` |
| `after` | map | New values. | `{verificationStatus: "approved"}` |
| `ipAddress` | string | Admin IP, if available. | `102.89.0.1` |
| `createdAt` | timestamp | Log time. | `2026-06-26T12:00:00Z` |

## Work Needed Outside Flutter

You will need to configure these outside the app:

- Firebase project configuration for Android, iOS, and Web.
- Firestore security rules so customers, riders, and admins only access allowed documents.
- Firestore composite indexes for queries such as `orders.status`, `orders.customerId`, `payments.createdAt`, and role-based user/rider lists.
- Backend or Firebase Cloud Functions for Paystack secret-key operations: initialize, verify, webhook, refund, and optional split subaccounts.
- Firebase Cloud Messaging setup if you want real push notifications from `notifications`.
- Admin account creation from backend/custom claims, not public frontend signup.
