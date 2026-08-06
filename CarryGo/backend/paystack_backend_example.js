/**
 * Example Firebase Functions/Express backend for CarryGo Paystack payments.
 *
 * Keep PAYSTACK_SECRET_KEY on the backend only. Never ship it in Flutter.
 *
 * Environment:
 *   PAYSTACK_SECRET_KEY=sk_live_xxx
 *   PAYSTACK_WEBHOOK_SECRET=sk_live_xxx
 */

const crypto = require("crypto");
const express = require("express");
const admin = require("firebase-admin");

admin.initializeApp();

const app = express();
const db = admin.firestore();
const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;

async function paystack(path, options = {}) {
  const response = await fetch(`https://api.paystack.co${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
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

app.use("/initialize", express.json());
app.post("/initialize", async (req, res) => {
  try {
    const {
      reference,
      orderId,
      customerId,
      email,
      amountKobo,
      platformCommissionKobo,
      riderPayoutKobo,
      riderSubaccount,
    } = req.body;

    const payload = {
      email,
      amount: amountKobo,
      reference,
      metadata: {
        orderId,
        customerId,
        platformCommissionKobo,
        riderPayoutKobo,
      },
    };

    // Optional Paystack split payment:
    // Create rider subaccounts in Paystack first, then pass the subaccount code.
    if (riderSubaccount) {
      payload.subaccount = riderSubaccount;
      payload.transaction_charge = platformCommissionKobo;
      payload.bearer = "subaccount";
    }

    const data = await paystack("/transaction/initialize", {
      method: "POST",
      body: JSON.stringify(payload),
    });

    await db.collection("payments").doc(reference).set(
      {
        orderId,
        customerId,
        email,
        amountKobo,
        provider: "paystack",
        status: "initialized",
        authorizationUrl: data.authorization_url,
        accessCode: data.access_code,
        platformCommission: platformCommissionKobo / 100,
        riderPayout: riderPayoutKobo / 100,
        split: {
          enabled: Boolean(riderSubaccount),
          riderSubaccount: riderSubaccount || null,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    res.json({
      reference,
      authorizationUrl: data.authorization_url,
      accessCode: data.access_code,
    });
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

app.get("/verify/:reference", async (req, res) => {
  try {
    const { reference } = req.params;
    const data = await paystack(`/transaction/verify/${reference}`);
    const success = data.status === "success";

    const paymentRef = db.collection("payments").doc(reference);
    const payment = await paymentRef.get();
    const orderId = payment.data()?.orderId || data.metadata?.orderId;

    await paymentRef.set(
      {
        status: success ? "paid" : "failed",
        verificationStatus: data.status,
        paidAt: success ? admin.firestore.FieldValue.serverTimestamp() : null,
        failureReason: success ? "" : data.gateway_response,
      },
      { merge: true },
    );

    if (success && orderId) {
      await db.collection("orders").doc(orderId).update({
        paymentStatus: "paid",
        status: "searching_rider",
        matchingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    res.json({
      status: data.status,
      message: data.gateway_response,
    });
  } catch (error) {
    res.status(400).json({ status: "failed", message: error.message });
  }
});

app.post(
  "/webhook",
  express.raw({ type: "application/json" }),
  async (req, res) => {
    const signature = crypto
      .createHmac("sha512", PAYSTACK_SECRET_KEY)
      .update(req.body)
      .digest("hex");

    if (signature !== req.headers["x-paystack-signature"]) {
      return res.sendStatus(401);
    }

    const event = JSON.parse(req.body.toString());
    const reference = event.data?.reference;
    const paymentRef = db.collection("payments").doc(reference);
    const payment = await paymentRef.get();
    const orderId = payment.data()?.orderId || event.data?.metadata?.orderId;

    if (event.event === "charge.success") {
      await paymentRef.set(
        {
          status: "paid",
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      if (orderId) {
        await db.collection("orders").doc(orderId).update({
          paymentStatus: "paid",
          status: "searching_rider",
        });
      }
    }

    if (event.event === "charge.failed") {
      await paymentRef.set(
        {
          status: "failed",
          failureReason: event.data?.gateway_response || "Payment failed",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      if (orderId) {
        await db.collection("orders").doc(orderId).update({
          paymentStatus: "failed",
          status: "pending_payment",
        });
      }
    }

    res.sendStatus(200);
  },
);

app.use("/refund", express.json());
app.post("/refund", async (req, res) => {
  try {
    const { reference, orderId, reason } = req.body;
    const payment = await db.collection("payments").doc(reference).get();
    const amount = payment.data()?.amountKobo;

    const refund = await paystack("/refund", {
      method: "POST",
      body: JSON.stringify({
        transaction: reference,
        amount,
        customer_note: reason,
        merchant_note: `CarryGo order ${orderId}`,
      }),
    });

    await db.collection("complaints").add({
      orderId,
      paymentReference: reference,
      reason,
      status: "refund_processing",
      refundId: refund.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection("payments").doc(reference).set(
      {
        status: "refund_processing",
        refundId: refund.id,
      },
      { merge: true },
    );

    res.json({ status: "refund_processing", refundId: refund.id });
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

module.exports = app;
