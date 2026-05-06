const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const Stripe = require("stripe");

admin.initializeApp();

// ─────────────────────────────────────────
// Helper: získaj FCM token + meno + profesie
// ─────────────────────────────────────────
async function getTokenAndName(uid, fallbackName = "Používateľ") {
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (userDoc.exists) {
    const d = userDoc.data();
    return {
      token: d?.fcmToken || null,
      name: d?.name || d?.displayName || d?.email || fallbackName,
      role: d?.role || null,
    };
  }
  return { token: null, name: fallbackName, role: null };
}

async function sendNotification(uid, { title, body, data = {} }) {
  const { token } = await getTokenAndName(uid);
  if (!token) {
    logger.warn(`Žiadny FCM token pre uid: ${uid}`);
    return;
  }
  const message = {
    token,
    notification: { title, body },
    data: { ...data },
    android: {
      priority: "high",
      notification: {
        channelId: data.channelId || "general_channel",
        sound: "default",
      },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
    },
  };
  try {
    await admin.messaging().send(message);
    logger.info(`Notifikácia odoslaná: ${uid} — ${title}`);
  } catch (err) {
    logger.error(`Chyba pri odosielaní notifikácie uid: ${uid}`, err);
  }
}

// ─────────────────────────────────────────
// 1. STRIPE — vytvorenie PaymentIntent
// ─────────────────────────────────────────
exports.createPaymentIntent = onCall(
  { enforceAppCheck: false, secrets: ["STRIPE_SECRET"] },
  async (req) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "Musíš byť prihlásený");

    const stripeSecretKey = process.env.STRIPE_SECRET;
    if (!stripeSecretKey) {
      logger.error("STRIPE_SECRET nie je nastavený!");
      throw new HttpsError("internal", "Konfigurácia platby chýba");
    }

    const { amount, currency, metadata } = req.data;
    if (typeof amount !== "number" || amount <= 0)
      throw new HttpsError("invalid-argument", "Neplatná suma");
    if (typeof currency !== "string" || currency.length === 0)
      throw new HttpsError("invalid-argument", "Chýba mena");

    try {
      const stripe = new Stripe(stripeSecretKey, { apiVersion: "2023-10-16" });
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(amount),
        currency,
        payment_method_types: ["card"],
        metadata: {
          buyerUid: req.auth.uid,
          type: metadata?.type || "payment",
          workOrderId: metadata?.workOrderId || "",
          craftsmanId: metadata?.craftsmanId || "",
          customerId: metadata?.customerId || "",
        },
      });
      logger.info(`PaymentIntent vytvorený: ${paymentIntent.id}`);
      return {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      };
    } catch (error) {
      logger.error("Chyba v createPaymentIntent:", error);
      throw new HttpsError("internal", "Platba zlyhala");
    }
  }
);

// ─────────────────────────────────────────
// 2. NOVÁ WORK ORDER
// ─────────────────────────────────────────
exports.onWorkOrderCreated = onDocumentCreated(
  "work_orders/{workOrderId}",
  async (event) => {
    const order = event.data?.data();
    if (!order) return;

    const { customerId, craftsmanId, profession, scheduledAt } = order;
    if (!customerId || !craftsmanId) return;

    const { name: customerName } = await getTokenAndName(customerId, "Zákazník");

    const date = scheduledAt?.toDate?.() || new Date();
    const dateStr = date.toLocaleDateString("sk-SK", {
      day: "numeric", month: "long", year: "numeric",
    });

    await sendNotification(craftsmanId, {
      title: "Nová objednávka 📋",
      body: `${customerName} ti objednal prácu${profession ? ` — ${profession}` : ""} na ${dateStr}`,
      data: {
        type: "new_work_order",
        channelId: "orders_channel",
        screen: "craftsman_calendar",
        workOrderId: event.params.workOrderId,
      },
    });
  }
);

// ─────────────────────────────────────────
// 3. ZMENA STAVU WORK ORDER
// ─────────────────────────────────────────
exports.onWorkOrderUpdated = onDocumentUpdated(
  "work_orders/{workOrderId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    if (!before || !after) return;
    if (before.status === after.status) return;

    const { customerId, craftsmanId } = after;
    if (!customerId || !craftsmanId) return;

    const status = after.status;

    const customerNotifs = {
      confirmed: async () => {
        const { name } = await getTokenAndName(craftsmanId, "Remeselník");
        await sendNotification(customerId, {
          title: "Objednávka potvrdená ✅",
          body: `${name} potvrdil tvoju objednávku`,
          data: { type: "work_order_confirmed", channelId: "orders_channel",
                  screen: "customer_work_orders", workOrderId: event.params.workOrderId },
        });
      },
      cancelled: async () => {
        const { name } = await getTokenAndName(craftsmanId, "Remeselník");
        await sendNotification(customerId, {
          title: "Objednávka odmietnutá ❌",
          body: `${name} odmietol tvoju objednávku`,
          data: { type: "work_order_cancelled", channelId: "orders_channel",
                  screen: "customer_work_orders", workOrderId: event.params.workOrderId },
        });
      },
      hoursLogged: async () => {
        const { name } = await getTokenAndName(craftsmanId, "Remeselník");
        const hours = after.loggedHours || "?";
        const total = after.totalAmount ? `${after.totalAmount} €` : "";
        await sendNotification(customerId, {
          title: "Hodiny na schválenie ⏱️",
          body: `${name} zadal ${hours} hod${total ? ` = ${total}` : ""}. Skontroluj a schváľ.`,
          data: { type: "hours_logged", channelId: "orders_channel",
                  screen: "customer_work_orders", workOrderId: event.params.workOrderId },
        });
      },
      craftsmanInsisting: async () => {
        const { name } = await getTokenAndName(craftsmanId, "Remeselník");
        await sendNotification(customerId, {
          title: "Remeselník trvá na hodinách ⚠️",
          body: `${name} trvá na pôvodných hodinách. Rozhodni sa ako pokračovať.`,
          data: { type: "craftsman_insisting", channelId: "orders_channel",
                  screen: "customer_work_orders", workOrderId: event.params.workOrderId },
        });
      },
      completed: async () => {
        const { name } = await getTokenAndName(craftsmanId, "Remeselník");
        await sendNotification(customerId, {
          title: "Zákazka dokončená 🎉",
          body: `${name} dokončil tvoju zákazku. Ohodnoť svoju skúsenosť.`,
          data: { type: "work_order_completed", channelId: "orders_channel",
                  screen: "customer_work_orders", workOrderId: event.params.workOrderId },
        });
      },
    };

    const craftsmanNotifs = {
      paymentDue: async () => {
        const { name } = await getTokenAndName(customerId, "Zákazník");
        const total = after.totalAmount ? `${after.totalAmount} €` : "";
        await sendNotification(craftsmanId, {
          title: "Hodiny schválené 💰",
          body: `${name} schválil hodiny${total ? ` — ${total}` : ""}. Čaká sa na platbu.`,
          data: { type: "hours_approved", channelId: "orders_channel",
                  screen: "craftsman_work_orders", workOrderId: event.params.workOrderId },
        });
      },
      reworkRequested: async () => {
        const { name } = await getTokenAndName(customerId, "Zákazník");
        const note = after.reworkNote ? `: „${after.reworkNote}"` : "";
        await sendNotification(craftsmanId, {
          title: "Žiadosť o úpravu hodín 🔁",
          body: `${name} žiada úpravu odpracovaných hodín${note}`,
          data: { type: "rework_requested", channelId: "orders_channel",
                  screen: "craftsman_work_orders", workOrderId: event.params.workOrderId },
        });
      },
      paid: async () => {
        const { name } = await getTokenAndName(customerId, "Zákazník");
        const amount = after.totalAmount || "";
        await sendNotification(craftsmanId, {
          title: "Platba prijatá 💰",
          body: `${name} zaplatil zákazku${amount ? ` — ${amount} €` : ""}`,
          data: { type: "work_order_paid", channelId: "orders_channel",
                  screen: "craftsman_work_orders", workOrderId: event.params.workOrderId },
        });
      },
      disputed: async () => {
        const { name } = await getTokenAndName(customerId, "Zákazník");
        await sendNotification(craftsmanId, {
          title: "Spor eskalovaný ⚠️",
          body: `${name} eskaloval situáciu na administrátora`,
          data: { type: "disputed", channelId: "orders_channel",
                  screen: "craftsman_work_orders", workOrderId: event.params.workOrderId },
        });
      },
    };

    if (customerNotifs[status]) await customerNotifs[status]();
    if (craftsmanNotifs[status]) await craftsmanNotifs[status]();
  }
);

// ─────────────────────────────────────────
// 4. NOVÁ SERVICE REQUEST (direct)
// ─────────────────────────────────────────
exports.onServiceRequestCreated = onDocumentCreated(
  "service_requests/{requestId}",
  async (event) => {
    const request = event.data?.data();
    if (!request) return;

    const { customerId, craftsmanId, type, profession, category } = request;
    if (!customerId || !craftsmanId) return;

    const { name: customerName } = await getTokenAndName(customerId, "Zákazník");

    await sendNotification(craftsmanId, {
      title: "Nová servisná požiadavka 🔨",
      body: `${customerName} ti poslal požiadavku — ${profession || ""} ${category ? `(${category})` : ""}`.trim(),
      data: {
        type: "new_service_request",
        channelId: "requests_channel",
        screen: "craftsman_requests",
        requestId: event.params.requestId,
      },
    });
  }
);

// ─────────────────────────────────────────
// 5. ZMENA STAVU SERVICE REQUEST
// ─────────────────────────────────────────
exports.onServiceRequestUpdated = onDocumentUpdated(
  "service_requests/{requestId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    if (!before || !after) return;
    if (before.status === after.status) return;

    const { customerId, craftsmanId } = after;
    if (!customerId || !craftsmanId) return;

    const { name: craftsmanName } = await getTokenAndName(craftsmanId, "Remeselník");

    let title = "";
    let body  = "";

    switch (after.status) {
      case "accepted":
      case "confirmed":
        title = "Požiadavka prijatá ✅";
        body  = `${craftsmanName} prijal tvoju požiadavku`;
        break;
      case "rejected":
      case "cancelled":
        title = "Požiadavka zamietnutá ❌";
        body  = `${craftsmanName} zamietol tvoju požiadavku`;
        break;
      case "completed":
        title = "Požiadavka dokončená 🎉";
        body  = `${craftsmanName} označil požiadavku ako dokončenú`;
        break;
    }

    if (title) {
      await sendNotification(customerId, {
        title, body,
        data: {
          type: "service_request_update",
          channelId: "requests_channel",
          screen: "customer_requests",
          requestId: event.params.requestId,
        },
      });
    }
  }
);

// ─────────────────────────────────────────
// 6. BROADCAST ZÁKAZKA
// ─────────────────────────────────────────
exports.onBroadcastRequestCreated = onDocumentCreated(
  "service_requests/{requestId}",
  async (event) => {
    const request = event.data?.data();
    if (!request) return;

    if (request.type !== "broadcast" || request.craftsmanId) return;

    const { customerId, profession, category } = request;
    if (!customerId || !profession) return;

    const { name: customerName } = await getTokenAndName(customerId, "Zákazník");

    const craftsmenSnap = await admin.firestore()
      .collection("craftsmen")
      .where("isActive", "==", true)
      .where("profession", "==", profession)
      .get();

    const skillsSnap = await admin.firestore()
      .collection("craftsmen")
      .where("isActive", "==", true)
      .where("skills", "array-contains", profession)
      .get();

    const ids = new Set([
      ...craftsmenSnap.docs.map(d => d.id),
      ...skillsSnap.docs.map(d => d.id),
    ]);
    ids.delete(customerId);

    logger.info(`Broadcast notifikácia pre ${ids.size} craftsmen — profesia: ${profession}`);

    for (const craftsmanId of ids) {
      const userDoc = await admin.firestore().collection("users").doc(craftsmanId).get();
      const token   = userDoc.data()?.fcmToken;
      if (!token) continue;

      await sendNotification(craftsmanId, {
        title: "Nová zákazka v tvojej kategórii 📣",
        body: `${customerName} hľadá ${profession}${category ? ` — ${category}` : ""}`,
        data: {
          type: "new_broadcast_request",
          channelId: "requests_channel",
          screen: "open_requests",
          requestId: event.params.requestId,
        },
      });
    }
  }
);

// ─────────────────────────────────────────
// 7. NOVÁ SPRÁVA V CHATE
// ─────────────────────────────────────────
exports.onMessageCreated = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const { senderId, text } = message;
    if (!senderId) return;

    const convDoc = await admin.firestore()
      .collection("conversations")
      .doc(event.params.conversationId)
      .get();

    if (!convDoc.exists) return;

    const { participants } = convDoc.data() || {};
    if (!participants || !Array.isArray(participants)) return;

    const recipientIds = participants.filter((id) => id !== senderId);
    const { name: senderName } = await getTokenAndName(senderId, "Niekto");

    for (const recipientId of recipientIds) {
      await sendNotification(recipientId, {
        title: senderName,
        body: text?.substring(0, 100) || "Nová správa",
        data: {
          type: "new_message",
          channelId: "chat_channel",
          screen: "chat",
          conversationId: event.params.conversationId,
        },
      });
    }
  }
);

// ─────────────────────────────────────────
// 8. STRIPE CHECKOUT SESSION (QR platba)
//    → vráti Stripe Checkout URL + sessionId
// ─────────────────────────────────────────
exports.createCheckoutSession = onCall(
  { enforceAppCheck: false, secrets: ["STRIPE_SECRET"] },
  async (req) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "Musíš byť prihlásený");

    const stripeSecretKey = process.env.STRIPE_SECRET;
    if (!stripeSecretKey) {
      logger.error("STRIPE_SECRET nie je nastavený!");
      throw new HttpsError("internal", "Konfigurácia platby chýba");
    }

    const { amount, currency, workOrderId, customerId, craftsmanId,
            successUrl, cancelUrl } = req.data;

    if (typeof amount !== "number" || amount <= 0)
      throw new HttpsError("invalid-argument", "Neplatná suma");

    try {
      const stripe = new Stripe(stripeSecretKey, { apiVersion: "2023-10-16" });

      const session = await stripe.checkout.sessions.create({
        mode: "payment",
        payment_method_types: ["card"],
        line_items: [{
          price_data: {
            currency: currency || "eur",
            product_data: {
              name: "Platba za zákazku — Susedko",
              description: `Zákazka ID: ${workOrderId}`,
            },
            unit_amount: Math.round(amount),
          },
          quantity: 1,
        }],
        metadata: {
          type: "work_order_payment",
          workOrderId: workOrderId || "",
          customerId: customerId || req.auth.uid,
          craftsmanId: craftsmanId || "",
          buyerUid: req.auth.uid,
        },
        success_url: successUrl ||
          `https://susedko.sk/payment/success?orderId=${workOrderId}`,
        cancel_url: cancelUrl ||
          `https://susedko.sk/payment/cancel?orderId=${workOrderId}`,
        expires_at: Math.floor(Date.now() / 1000) + 30 * 60,
      });

      logger.info(`Checkout session vytvorená: ${session.id} pre workOrder: ${workOrderId}`);

      return {
        url: session.url,
        sessionId: session.id,
        paymentIntentId: session.payment_intent || null,
      };

    } catch (error) {
      logger.error("Chyba v createCheckoutSession:", error);
      throw new HttpsError("internal", `Platba zlyhala: ${error.message}`);
    }
  }
);

// ─────────────────────────────────────────
// 9. STRIPE WEBHOOK — potvrdenie QR platby
//    checkout.session.completed → markPaid
// ─────────────────────────────────────────
const { onRequest } = require("firebase-functions/v2/https");

exports.stripeWebhook = onRequest(
  { secrets: ["STRIPE_SECRET", "STRIPE_WEBHOOK_SECRET"] },
  async (req, res) => {
    const stripeSecretKey = process.env.STRIPE_SECRET;
    const webhookSecret   = process.env.STRIPE_WEBHOOK_SECRET;

    if (!stripeSecretKey || !webhookSecret) {
      logger.error("Chýbajú Stripe secrets");
      return res.status(500).send("Config error");
    }

    const stripe = new Stripe(stripeSecretKey, { apiVersion: "2023-10-16" });
    const sig    = req.headers["stripe-signature"];

    let event;
    try {
      event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    } catch (err) {
      logger.error("Webhook signature verification failed:", err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    if (event.type === "checkout.session.completed") {
      const session     = event.data.object;
      const workOrderId = session.metadata?.workOrderId;
      const paymentIntentId = session.payment_intent;

      if (workOrderId) {
        try {
          await admin.firestore()
            .collection("work_orders")
            .doc(workOrderId)
            .update({
              status:          "paid",
              paymentStatus:   "paid",
              paymentIntentId: paymentIntentId || session.id,
              completedAt:     admin.firestore.FieldValue.serverTimestamp(),
            });

          logger.info(`WorkOrder ${workOrderId} označená ako zaplatená (webhook)`);

          // Notifikácia craftsmanovi
          const orderDoc = await admin.firestore()
            .collection("work_orders").doc(workOrderId).get();
          const order = orderDoc.data();
          if (order?.craftsmanId) {
            const { name: customerName } = await getTokenAndName(
              order.customerId, "Zákazník");
            await sendNotification(order.craftsmanId, {
              title: "Platba prijatá 💰",
              body: `${customerName} zaplatil zákazku cez QR kód`,
              data: {
                type: "work_order_paid",
                channelId: "orders_channel",
                screen: "craftsman_work_orders",
                workOrderId,
              },
            });
          }
        } catch (err) {
          logger.error(`Chyba pri aktualizácii workOrder ${workOrderId}:`, err);
          return res.status(500).send("DB update error");
        }
      }
    }

    res.json({ received: true });
  }
);