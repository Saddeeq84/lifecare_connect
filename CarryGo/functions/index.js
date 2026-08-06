const crypto = require("crypto");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const PAYSTACK_SECRET_KEY = defineSecret("PAYSTACK_SECRET_KEY");
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || "*";

const orderStatuses = {
  pendingPayment: "pending_payment",
  searchingRider: "searching_rider",
  accepted: "accepted",
  pickedUp: "picked_up",
  inTransit: "in_transit",
  delivered: "delivered",
};

const conditionMultipliers = {
  Clear: 1,
  Rain: 1.15,
  "Heavy traffic": 1.2,
  "Rain + heavy traffic": 1.35,
};

function cors(req, res) {
  res.set("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return true;
  }
  return false;
}

async function requireUser(req) {
  const header = req.get("Authorization") || "";
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    throw Object.assign(new Error("Missing Firebase auth token"), {code: 401});
  }
  return admin.auth().verifyIdToken(match[1]);
}

async function requireAdmin(req) {
  const user = await requireUser(req);
  if (user.admin === true || user.role === "admin") {
    return user;
  }
  const profile = await db.collection("users").doc(user.uid).get();
  if (profile.data()?.role !== "admin") {
    throw Object.assign(new Error("Admin access required"), {code: 403});
  }
  return user;
}

async function requireApprovedRider(req) {
  const user = await requireUser(req);
  const profile = await db.collection("users").doc(user.uid).get();
  const data = profile.data() || {};
  if (
    data.role !== "rider" ||
    (data.riderStatus !== "approved" && data.isApproved !== true)
  ) {
    throw Object.assign(new Error("Approved rider access required"), {
      code: 403,
    });
  }
  return user;
}

function sendError(res, error) {
  logger.error(error);
  res.status(error.code || 400).json({message: error.message});
}

function roundUp(value, step = 50) {
  return Math.ceil(value / step) * step;
}

function haversineKm(startLat, startLng, endLat, endLng) {
  const radiusKm = 6371;
  const toRad = (value) => (value * Math.PI) / 180;
  const dLat = toRad(endLat - startLat);
  const dLng = toRad(endLng - startLng);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(startLat)) *
      Math.cos(toRad(endLat)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  return radiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function getPricingRule(city) {
  const rule = await db.collection("pricing_rules").doc(city).get();
  if (!rule.exists) {
    throw new Error(`Pricing is not configured for ${city}`);
  }
  const data = rule.data() || {};
  return {
    baseFare: Number(data.baseFare || 0),
    perKmRate: Number(data.perKmRate || data.distanceRatePerKm || 0),
    minimumBillableDistanceKm: Number(data.minimumBillableDistanceKm || 1),
    roundingStep: Number(data.roundingStep || 50),
    commissionRate: Number(
      data.commissionRate || data.platformCommissionRate || 0,
    ),
    sizeFees: data.sizeFees || {},
    weightFees: data.weightFees || {},
    urgencyMultipliers: data.urgencyMultipliers || {},
  };
}

async function calculateFee(payload) {
  const city = payload.city || "Lagos";
  const pickupLat = Number(payload.pickup_latitude ?? payload.pickupLatitude);
  const pickupLng = Number(payload.pickup_longitude ?? payload.pickupLongitude);
  const dropoffLat = Number(
    payload.dropoff_latitude ?? payload.dropoffLatitude,
  );
  const dropoffLng = Number(
    payload.dropoff_longitude ?? payload.dropoffLongitude,
  );
  const distanceKm =
    Number(payload.distance_km) ||
    haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
  const rule = await getPricingRule(city);
  const parcelSize = payload.parcel_size || payload.parcelSize || "Small";
  const parcelWeight =
    payload.parcel_weight || payload.parcelWeight || "Light";
  const urgency = payload.urgency || "Normal";
  const condition = payload.condition || "Clear";
  const subtotal =
    rule.baseFare +
    Math.max(distanceKm, rule.minimumBillableDistanceKm) * rule.perKmRate +
    Number(rule.sizeFees[parcelSize] || 0) +
    Number(rule.weightFees[parcelWeight] || 0);
  const distanceFee =
    Math.max(distanceKm, rule.minimumBillableDistanceKm) * rule.perKmRate;
  const sizeFee = Number(rule.sizeFees[parcelSize] || 0);
  const weightFee = Number(rule.weightFees[parcelWeight] || 0);
  const urgencyMultiplier = Number(rule.urgencyMultipliers[urgency] || 1);
  const conditionMultiplier = Number(conditionMultipliers[condition] || 1);
  const total = roundUp(
    subtotal * urgencyMultiplier * conditionMultiplier,
    rule.roundingStep,
  );
  const platformCommission = roundUp(total * rule.commissionRate, rule.roundingStep);
  const riderPayout = Math.max(0, total - platformCommission);
  return {
    city,
    baseFare: rule.baseFare,
    distance_km: Number(distanceKm.toFixed(2)),
    distanceFee,
    sizeFee,
    weightFee,
    urgencyMultiplier,
    conditionMultiplier,
    subtotal,
    estimated_duration_minutes: Math.max(1, Math.round(distanceKm * 4)),
    delivery_fee: total,
    platformCommission,
    riderPayout,
    commissionRate: rule.commissionRate,
  };
}

async function paystack(path, options = {}) {
  const secretKey = PAYSTACK_SECRET_KEY.value();
  if (!secretKey) {
    throw new Error("PAYSTACK_SECRET_KEY is not configured");
  }
  const response = await fetch(`https://api.paystack.co${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  const body = await response.json();
  if (!response.ok || body.status === false) {
    throw new Error(body.message || "Paystack request failed");
  }
  return body.data;
}

async function notifyRole(role, title, body, orderId = "") {
  await db.collection("notifications").add({
    userId: null,
    role,
    title,
    body,
    type: "order_status",
    orderId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function assignNearbyRidersForOrder(orderId) {
  const orderRef = db.collection("orders").doc(orderId);
  const orderDoc = await orderRef.get();
  if (!orderDoc.exists) throw new Error("Order not found");
  const order = orderDoc.data();
  if (order.payment_status !== "paid" && order.paymentStatus !== "paid") {
    throw new Error("Order must be paid before rider matching");
  }

  const riders = await db
    .collection("riders")
    .where("city", "==", order.city || "Lagos")
    .where("isOnline", "==", true)
    .where("isVerified", "==", true)
    .limit(25)
    .get();

  const pickupLat = Number(order.pickup_latitude || order.pickupLat || 0);
  const pickupLng = Number(order.pickup_longitude || order.pickupLng || 0);
  const candidates = riders.docs
    .map((doc) => {
      const rider = doc.data();
      const distanceKm = haversineKm(
        pickupLat,
        pickupLng,
        Number(rider.currentLatitude || pickupLat),
        Number(rider.currentLongitude || pickupLng),
      );
      return {id: doc.id, distanceKm};
    })
    .filter((candidate) => candidate.distanceKm <= 10)
    .sort((a, b) => a.distanceKm - b.distanceKm)
    .slice(0, 10);

  await orderRef.set(
    {
      nearby_rider_ids: candidates.map((candidate) => candidate.id),
      matchingStartedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await Promise.all(
    candidates.map((candidate) =>
      db.collection("notifications").add({
        userId: candidate.id,
        role: "rider",
        title: "New CarryGo request",
        body: "A paid delivery request is available near you.",
        type: "order_status",
        orderId,
        distanceKm: Number(candidate.distanceKm.toFixed(2)),
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      }),
    ),
  );

  return {matchedRiders: candidates};
}

async function markPaymentSuccess(reference, paystackData = {}) {
  const paymentRef = db.collection("payments").doc(reference);
  const paymentDoc = await paymentRef.get();
  const payment = paymentDoc.data() || {};
  const orderId = payment.orderId || paystackData.metadata?.orderId;
  if (!orderId) throw new Error("Payment is missing orderId");

  await paymentRef.set(
    {
      status: "paid",
      verificationStatus: paystackData.status || "success",
      verificationMessage: paystackData.gateway_response || "Payment verified",
      paidAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await recordAdminCommission(reference, payment, "card");

  await db.collection("orders").doc(orderId).set(
    {
      paymentStatus: "paid",
      payment_status: "paid",
      status: orderStatuses.searchingRider,
      order_status: orderStatuses.searchingRider,
      matchingStartedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await assignNearbyRidersForOrder(orderId);
  await notifyRole("rider", "New paid request", "A paid CarryGo request is ready.", orderId);
  return orderId;
}

async function recordAdminCommission(reference, payment, paymentMethod = "card") {
  const commission = Number(payment.platformCommission || 0);
  if (commission <= 0) return;
  await db.collection("admin_wallet").doc(reference).set(
    {
      paymentReference: reference,
      orderId: payment.orderId || "",
      customerId: payment.customerId || "",
      amount: commission,
      amountKobo: Math.round(commission * 100),
      currency: payment.currency || "NGN",
      paymentMethod,
      status: paymentMethod === "cash" ? "cash_due" : "available",
      type: "platform_commission",
      createdAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function markPaymentFailed(reference, reason, paystackData = {}) {
  const paymentRef = db.collection("payments").doc(reference);
  const paymentDoc = await paymentRef.get();
  const payment = paymentDoc.data() || {};
  const orderId = payment.orderId || paystackData.metadata?.orderId;
  await paymentRef.set(
    {
      status: "failed",
      failureReason: reason,
      failedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  if (orderId) {
    await db.collection("orders").doc(orderId).set(
      {
        paymentStatus: "failed",
        payment_status: "failed",
        status: orderStatuses.pendingPayment,
        order_status: orderStatuses.pendingPayment,
      },
      {merge: true},
    );
  }
}

exports.calculateDeliveryFee = onRequest(async (req, res) => {
  if (cors(req, res)) return;
  try {
    await requireUser(req);
    const result = await calculateFee(req.body || {});
    res.json(result);
  } catch (error) {
    sendError(res, error);
  }
});

exports.initializeMvpCollections = onRequest(async (req, res) => {
  if (cors(req, res)) return;
  try {
    const adminUser = await requireAdmin(req);
    const now = FieldValue.serverTimestamp();
    const batch = db.batch();
    const collections = {
      users: {
        name: "string",
        phone: "string",
        email: "string",
        role: "customer | rider | admin",
        isApproved: "boolean",
        createdAt: "timestamp",
      },
      riders: {
        bikeNumber: "string",
        city: "string",
        isVerified: "boolean",
        isOnline: "boolean",
        currentLatitude: "number | null",
        currentLongitude: "number | null",
      },
      orders: {
        customer_id: "string",
        rider_id: "string | null",
        pickup_address: "string",
        pickup_latitude: "number",
        pickup_longitude: "number",
        dropoff_address: "string",
        dropoff_latitude: "number",
        dropoff_longitude: "number",
        parcel_size: "Small | Medium | Large | Extra Large",
        parcel_weight: "Light | Medium | Heavy",
        distance_km: "number",
        delivery_fee: "number",
        payment_status: "pending_payment | paid | failed | refunded",
        order_status: "draft | pending_payment | searching_rider | accepted | picked_up | in_transit | delivered | cancelled | disputed | refunded",
        created_at: "timestamp",
      },
      payments: {
        orderId: "string",
        customerId: "string",
        amountKobo: "number",
        currency: "NGN",
        provider: "paystack",
        status: "initialized | paid | failed | refunded",
        createdAt: "timestamp",
      },
    };

    Object.entries(collections).forEach(([collection, fields]) => {
      batch.set(
        db.collection(collection).doc("_schema"),
        {
          is_schema_placeholder: true,
          phase: "phase_1_mvp",
          collection,
          fields,
          initializedBy: adminUser.uid,
          createdAt: now,
          updatedAt: now,
        },
        {merge: true},
      );
    });

    await batch.commit();
    res.json({
      ok: true,
      phase: "phase_1_mvp",
      collections: Object.keys(collections),
    });
  } catch (error) {
    sendError(res, error);
  }
});

exports.initializePhase2Collections = onRequest(async (req, res) => {
  if (cors(req, res)) return;
  try {
    const adminUser = await requireAdmin(req);
    const now = FieldValue.serverTimestamp();
    const batch = db.batch();
    const collections = {
      ratings: {
        orderId: "string",
        customerId: "string",
        riderId: "string",
        rating: "number",
        review: "string",
        createdAt: "timestamp",
      },
      notifications: {
        userId: "string | null",
        role: "customer | rider | admin | all",
        title: "string",
        body: "string",
        type: "order_status | payment | complaint | admin_broadcast",
        orderId: "string | null",
        isRead: "boolean",
        createdAt: "timestamp",
      },
      complaints: {
        orderId: "string",
        paymentReference: "string",
        customerId: "string",
        riderId: "string | null",
        type: "refund | wrong_item | damaged_item | late_delivery | other",
        reason: "string",
        status: "open | under_review | resolved | rejected | refunded",
        amountKobo: "number",
        adminNote: "string",
        createdAt: "timestamp",
        resolvedAt: "timestamp | null",
      },
    };

    Object.entries(collections).forEach(([collection, fields]) => {
      batch.set(
        db.collection(collection).doc("_schema"),
        {
          is_schema_placeholder: true,
          phase: "phase_2_mvp",
          collection,
          fields,
          initializedBy: adminUser.uid,
          createdAt: now,
          updatedAt: now,
        },
        {merge: true},
      );
    });

    await batch.commit();
    res.json({
      ok: true,
      phase: "phase_2_mvp",
      collections: Object.keys(collections),
    });
  } catch (error) {
    sendError(res, error);
  }
});

exports.initializePhase3Collections = onRequest(async (req, res) => {
  if (cors(req, res)) return;
  try {
    const adminUser = await requireAdmin(req);
    const now = FieldValue.serverTimestamp();
    const batch = db.batch();
    const collections = {
      pricing_rules: {
        city: "string",
        baseFare: "number",
        perKmRate: "number",
        minimumBillableDistanceKm: "number",
        commissionRate: "number",
        roundingStep: "number",
        currency: "NGN",
        sizeFees: "map<string, number>",
        weightFees: "map<string, number>",
        urgencyMultipliers: "map<string, number>",
        conditionMultipliers: "map<string, number>",
        isActive: "boolean",
        updatedBy: "string",
        updatedAt: "timestamp",
      },
      cities: {
        name: "string",
        state: "string",
        isActive: "boolean",
        baseFare: "number",
        centerLatitude: "number | null",
        centerLongitude: "number | null",
        serviceRadiusKm: "number",
        createdAt: "timestamp",
        updatedAt: "timestamp",
      },
      admin_logs: {
        adminId: "string",
        action: "string",
        entityType: "string",
        entityId: "string",
        before: "map",
        after: "map",
        createdAt: "timestamp",
      },
      admin_wallet: {
        orderId: "string",
        paymentReference: "string",
        customerId: "string",
        amount: "number",
        amountKobo: "number",
        currency: "NGN",
        paymentMethod: "card | wallet | cash",
        status: "available | cash_due",
        type: "platform_commission",
        createdAt: "timestamp",
      },
      wallet_transactions: {
        userId: "string",
        role: "customer | rider | admin",
        amount: "number",
        currency: "NGN",
        type: "topup | cash_commission",
        direction: "credit | debit",
        status: "initialized | available | due | paid | failed",
        reference: "string",
        createdAt: "timestamp",
      },
      withdrawal_requests: {
        userId: "string",
        role: "rider | admin",
        amount: "number",
        bankName: "string",
        accountNumber: "string",
        accountName: "string",
        status: "pending | paid | rejected",
        createdAt: "timestamp",
      },
    };

    Object.entries(collections).forEach(([collection, fields]) => {
      batch.set(
        db.collection(collection).doc("_schema"),
        {
          is_schema_placeholder: true,
          phase: "phase_3_mvp",
          collection,
          fields,
          initializedBy: adminUser.uid,
          createdAt: now,
          updatedAt: now,
        },
        {merge: true},
      );
    });

    await batch.commit();
    res.json({
      ok: true,
      phase: "phase_3_mvp",
      collections: Object.keys(collections),
    });
  } catch (error) {
    sendError(res, error);
  }
});

exports.initializePaystackPayment = onRequest(
  {secrets: [PAYSTACK_SECRET_KEY]},
  async (req, res) => {
    if (cors(req, res)) return;
    try {
      const user = await requireUser(req);
      const {orderId, email, riderSubaccount} = req.body || {};
      if (!orderId || !email) throw new Error("orderId and email are required");

      const orderRef = db.collection("orders").doc(orderId);
      const orderDoc = await orderRef.get();
      if (!orderDoc.exists) throw new Error("Order not found");
      const order = orderDoc.data();
      if (order.customer_id !== user.uid && order.customerId !== user.uid) {
        throw Object.assign(new Error("You can only pay for your own order"), {
          code: 403,
        });
      }

      const fee = await calculateFee(order);
      const reference = `CG-${Date.now()}-${orderId}`;
      const amountKobo = Math.round(fee.delivery_fee * 100);
      const platformCommissionKobo = Math.round(fee.platformCommission * 100);
      const riderPayoutKobo = Math.round(fee.riderPayout * 100);
      const payload = {
        email,
        amount: amountKobo,
        reference,
        metadata: {
          orderId,
          customerId: user.uid,
          platformCommissionKobo,
          riderPayoutKobo,
        },
      };

      if (riderSubaccount) {
        payload.subaccount = riderSubaccount;
        payload.transaction_charge = platformCommissionKobo;
        payload.bearer = "subaccount";
      }

      const data = await paystack("/transaction/initialize", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      await db.collection("payments").doc(reference).set({
        orderId,
        customerId: user.uid,
        email,
        amountKobo,
        currency: "NGN",
        provider: "paystack",
        status: "initialized",
        authorizationUrl: data.authorization_url,
        accessCode: data.access_code,
        platformCommission: fee.platformCommission,
        riderPayout: fee.riderPayout,
        split: {
          enabled: Boolean(riderSubaccount),
          riderSubaccount: riderSubaccount || null,
        },
        createdAt: FieldValue.serverTimestamp(),
      });

      await orderRef.set(
        {
          distance_km: fee.distance_km,
          estimated_duration_minutes: fee.estimated_duration_minutes,
          delivery_fee: fee.delivery_fee,
          cost: fee.delivery_fee,
          platformCommission: fee.platformCommission,
          riderPayout: fee.riderPayout,
          paymentReference: reference,
          paymentStatus: "initialized",
          payment_status: "initialized",
          status: orderStatuses.pendingPayment,
          order_status: orderStatuses.pendingPayment,
        },
        {merge: true},
      );

      res.json({
        reference,
        authorizationUrl: data.authorization_url,
        accessCode: data.access_code,
      });
    } catch (error) {
      sendError(res, error);
    }
  },
);

exports.initializeWalletTopup = onRequest(
  {secrets: [PAYSTACK_SECRET_KEY]},
  async (req, res) => {
    if (cors(req, res)) return;
    try {
      const user = await requireUser(req);
      const {amount, email, walletRole} = req.body || {};
      const amountNumber = Number(amount || 0);
      if (amountNumber <= 0) throw new Error("amount is required");
      if (!email) throw new Error("email is required");
      const reference = `CGW-${Date.now()}-${user.uid}`;
      const amountKobo = Math.round(amountNumber * 100);
      const data = await paystack("/transaction/initialize", {
        method: "POST",
        body: JSON.stringify({
          email,
          amount: amountKobo,
          reference,
          metadata: {
            userId: user.uid,
            walletRole: walletRole || "customer",
            type: "wallet_topup",
          },
        }),
      });
      await db.collection("wallet_transactions").doc(reference).set({
        userId: user.uid,
        role: walletRole || "customer",
        amount: amountNumber,
        amountKobo,
        currency: "NGN",
        type: "topup",
        direction: "credit",
        status: "initialized",
        provider: "paystack",
        reference,
        authorizationUrl: data.authorization_url,
        accessCode: data.access_code,
        createdAt: FieldValue.serverTimestamp(),
      });
      res.json({
        reference,
        authorizationUrl: data.authorization_url,
        accessCode: data.access_code,
      });
    } catch (error) {
      sendError(res, error);
    }
  },
);

exports.verifyWalletTopup = onRequest(
  {secrets: [PAYSTACK_SECRET_KEY]},
  async (req, res) => {
    if (cors(req, res)) return;
    try {
      const user = await requireUser(req);
      const reference = req.query.reference || req.body?.reference;
      if (!reference) throw new Error("reference is required");
      const transaction = await db.collection("wallet_transactions").doc(reference).get();
      const wallet = transaction.data() || {};
      if (wallet.userId !== user.uid) {
        throw Object.assign(new Error("You can only verify your own top-up"), {
          code: 403,
        });
      }
      const data = await paystack(`/transaction/verify/${reference}`);
      if (data.status !== "success") {
        await transaction.ref.set({
          status: "failed",
          verificationStatus: data.status || "failed",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        res.json({status: data.status || "failed"});
        return;
      }
      await transaction.ref.set({
        status: "available",
        verificationStatus: "success",
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (wallet.role === "rider") {
        await applyRiderCommissionTopup(user.uid, Number(wallet.amount || 0), reference);
      }
      res.json({status: "success"});
    } catch (error) {
      sendError(res, error);
    }
  },
);

async function applyRiderCommissionTopup(riderId, amount, topupReference) {
  let remaining = amount;
  const due = await db
    .collection("wallet_transactions")
    .where("userId", "==", riderId)
    .where("type", "==", "cash_commission")
    .where("status", "==", "due")
    .limit(20)
    .get();
  for (const doc of due.docs) {
    if (remaining <= 0) break;
    const debt = Math.abs(Number(doc.data().amount || 0));
    if (debt <= remaining) {
      await doc.ref.set(
        {
          status: "paid",
          paidByTopupReference: topupReference,
          paidAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      remaining -= debt;
    }
  }
}

exports.verifyPaystackPayment = onRequest(
  {secrets: [PAYSTACK_SECRET_KEY]},
  async (req, res) => {
  if (cors(req, res)) return;
  try {
    await requireUser(req);
    const reference = req.query.reference || req.body?.reference;
    if (!reference) throw new Error("reference is required");
    const data = await paystack(`/transaction/verify/${reference}`);
    if (data.status === "success") {
      const orderId = await markPaymentSuccess(reference, data);
      res.json({status: data.status, orderId, message: data.gateway_response});
    } else {
      await markPaymentFailed(reference, data.gateway_response || "Payment failed", data);
      res.json({status: data.status, message: data.gateway_response});
    }
  } catch (error) {
    sendError(res, error);
  }
  },
);

exports.handlePaystackWebhook = onRequest(
  {secrets: [PAYSTACK_SECRET_KEY]},
  async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }
  try {
    const secretKey = PAYSTACK_SECRET_KEY.value();
    const signature = crypto
      .createHmac("sha512", secretKey)
      .update(req.rawBody)
      .digest("hex");
    if (signature !== req.get("x-paystack-signature")) {
      res.status(401).send("Invalid signature");
      return;
    }
    const event = req.body;
    const reference = event.data?.reference;
    if (!reference) throw new Error("Webhook missing reference");

    if (event.event === "charge.success") {
      await markPaymentSuccess(reference, event.data);
    }
    if (event.event === "charge.failed") {
      await markPaymentFailed(
        reference,
        event.data?.gateway_response || "Payment failed",
        event.data,
      );
    }
    res.status(200).send("ok");
  } catch (error) {
    sendError(res, error);
  }
  },
);

exports.assignNearbyRiders = onRequest(async (req, res) => {
  if (cors(req, res)) return;
  try {
    await requireAdmin(req);
    const {orderId} = req.body || {};
    if (!orderId) throw new Error("orderId is required");
    res.json(await assignNearbyRidersForOrder(orderId));
  } catch (error) {
    sendError(res, error);
  }
});

exports.sendOrderNotification = onRequest(async (req, res) => {
  if (cors(req, res)) return;
  try {
    await requireAdmin(req);
    const {role, title, body, orderId} = req.body || {};
    await notifyRole(role || "all", title || "CarryGo", body || "", orderId || "");
    res.json({sent: true});
  } catch (error) {
    sendError(res, error);
  }
});

exports.confirmDeliveryOtp = onRequest(async (req, res) => {
  if (cors(req, res)) return;
  try {
    const rider = await requireApprovedRider(req);
    const {orderId, otp} = req.body || {};
    if (!orderId || !otp) throw new Error("orderId and otp are required");
    const orderRef = db.collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) throw new Error("Order not found");
    const order = orderDoc.data();
    if ((order.rider_id || order.riderId) !== rider.uid) {
      throw Object.assign(new Error("Order is not assigned to this rider"), {
        code: 403,
      });
    }
    if ((order.delivery_otp || order.otp) !== otp) {
      throw Object.assign(new Error("Invalid delivery OTP"), {code: 400});
    }
    await orderRef.set(
      {
        status: orderStatuses.delivered,
        order_status: orderStatuses.delivered,
        deliveredAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    await updateRiderEarningsForOrder(orderId);
    res.json({delivered: true});
  } catch (error) {
    sendError(res, error);
  }
});

async function updateRiderEarningsForOrder(orderId) {
  const orderDoc = await db.collection("orders").doc(orderId).get();
  if (!orderDoc.exists) throw new Error("Order not found");
  const order = orderDoc.data();
  const riderId = order.rider_id || order.riderId;
  if (!riderId) throw new Error("Order has no rider");
  const paymentStatus = order.payment_status || order.paymentStatus;
  if (!["paid", "wallet_authorized", "cash_on_pickup", "cash_collected"].includes(paymentStatus)) {
    throw new Error("Order payment is not eligible for payout");
  }
  await db.collection("payouts").doc(orderId).set(
    {
      orderId,
      riderId,
      paymentReference: order.paymentReference || "",
      amount: Number(order.riderPayout || 0),
      amountKobo: Math.round(Number(order.riderPayout || 0) * 100),
      platformCommission: Number(order.platformCommission || 0),
      currency: "NGN",
      status: "pending_settlement",
      createdAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await db.collection("admin_wallet").doc(orderId).set(
    {
      orderId,
      paymentReference: order.paymentReference || "",
      customerId: order.customer_id || order.customerId || "",
      amount: Number(order.platformCommission || 0),
      amountKobo: Math.round(Number(order.platformCommission || 0) * 100),
      currency: "NGN",
      paymentMethod: order.paymentMethod || "card",
      status: (order.paymentMethod || "card") === "cash" ? "cash_due" : "available",
      type: "platform_commission",
      createdAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  if ((order.paymentMethod || "") === "cash" || paymentStatus === "cash_on_pickup") {
    await db.collection("wallet_transactions").doc(`${orderId}_commission`).set(
      {
        userId: riderId,
        role: "rider",
        orderId,
        amount: -Number(order.platformCommission || 0),
        amountKobo: -Math.round(Number(order.platformCommission || 0) * 100),
        currency: "NGN",
        type: "cash_commission",
        direction: "debit",
        status: "due",
        description: "Commission due on cash ride",
        createdAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
  await db.collection("riders").doc(riderId).set(
    {
      completedOrders: FieldValue.increment(1),
      earningsPending: FieldValue.increment(Number(order.riderPayout || 0)),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

exports.updateRiderEarnings = onRequest(async (req, res) => {
  if (cors(req, res)) return;
  try {
    await requireAdmin(req);
    const {orderId} = req.body || {};
    if (!orderId) throw new Error("orderId is required");
    await updateRiderEarningsForOrder(orderId);
    res.json({updated: true});
  } catch (error) {
    sendError(res, error);
  }
});
