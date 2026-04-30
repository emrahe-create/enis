import Stripe from "stripe";
import { env } from "../../config/env.js";
import { ApiError } from "../../utils/http.js";
import {
  getSubscriptionByStripeSubscriptionId,
  hasProcessedSubscriptionEvent,
  recordSubscriptionEvent,
  updateStripeSubscription
} from "../subscriptions/subscription.repository.js";

const stripe = env.STRIPE_SECRET_KEY ? new Stripe(env.STRIPE_SECRET_KEY) : null;

function stripeTimestampToDate(timestamp) {
  return timestamp ? new Date(timestamp * 1000) : null;
}

export async function createCheckoutSession({ userId, email }) {
  if (!stripe || !env.STRIPE_PREMIUM_PRICE_ID) {
    throw new ApiError(503, "Stripe is not configured");
  }

  return stripe.checkout.sessions.create({
    mode: "subscription",
    customer_email: email,
    client_reference_id: userId,
    metadata: { userId },
    subscription_data: {
      metadata: { userId }
    },
    line_items: [{ price: env.STRIPE_PREMIUM_PRICE_ID, quantity: 1 }],
    success_url: `${env.APP_BASE_URL}/payments/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${env.APP_BASE_URL}/payments/cancel`
  });
}

export function constructStripeEvent(rawBody, signature) {
  if (!stripe || !env.STRIPE_WEBHOOK_SECRET) {
    throw new ApiError(503, "Stripe webhook is not configured");
  }

  return stripe.webhooks.constructEvent(rawBody, signature, env.STRIPE_WEBHOOK_SECRET);
}

async function updateFromStripeSubscription(stripeSubscription, fallbackUserId) {
  const existing = await getSubscriptionByStripeSubscriptionId(stripeSubscription.id);
  const userId = stripeSubscription.metadata?.userId || fallbackUserId || existing?.user_id;

  if (!userId) return null;

  return updateStripeSubscription({
    userId,
    stripeCustomerId: stripeSubscription.customer,
    stripeSubscriptionId: stripeSubscription.id,
    status: stripeSubscription.status,
    currentPeriodEndsAt: stripeTimestampToDate(stripeSubscription.current_period_end),
    cancelAtPeriodEnd: Boolean(stripeSubscription.cancel_at_period_end),
    canceledAt: stripeTimestampToDate(stripeSubscription.canceled_at)
  });
}

export async function handleStripeEvent(event) {
  if (await hasProcessedSubscriptionEvent("stripe", event.id)) {
    return { processed: false, reason: "duplicate_event" };
  }

  let userId = null;

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    userId = session.client_reference_id || session.metadata?.userId || null;

    if (userId && session.subscription) {
      if (stripe && typeof session.subscription === "string") {
        const stripeSubscription = await stripe.subscriptions.retrieve(session.subscription);
        const updated = await updateFromStripeSubscription(stripeSubscription, userId);
        userId = updated?.user_id || userId;
      } else if (typeof session.subscription === "object") {
        const updated = await updateFromStripeSubscription(session.subscription, userId);
        userId = updated?.user_id || userId;
      } else {
        const updated = await updateStripeSubscription({
          userId,
          stripeCustomerId: session.customer,
          stripeSubscriptionId: session.subscription,
          status: "active",
          currentPeriodEndsAt: null
        });
        userId = updated?.user_id || userId;
      }
    }
  }

  if (event.type === "customer.subscription.updated" || event.type === "customer.subscription.deleted") {
    const subscription = event.data.object;
    userId = subscription.metadata?.userId || null;
    const updated = await updateFromStripeSubscription(subscription);
    userId = updated?.user_id || userId;
  }

  await recordSubscriptionEvent({
    userId,
    provider: "stripe",
    externalEventId: event.id,
    eventType: event.type,
    payload: event
  });

  return { processed: true };
}
