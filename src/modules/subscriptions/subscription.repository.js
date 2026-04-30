import { query } from "../../db/pool.js";

export async function createFreeSubscription(userId) {
  const result = await query(
    `INSERT INTO subscriptions (user_id, plan, status)
     VALUES ($1, 'free', 'active')
     ON CONFLICT (user_id) DO UPDATE SET updated_at = NOW()
     RETURNING *`,
    [userId]
  );
  return result.rows[0];
}

export async function startPremiumTrial(userId) {
  const result = await query(
    `INSERT INTO subscriptions (user_id, plan, status, trial_started_at, trial_ends_at)
     VALUES ($1, 'premium', 'trialing', NOW(), NOW() + INTERVAL '15 days')
     ON CONFLICT (user_id) DO UPDATE SET
       plan = CASE
         WHEN subscriptions.trial_started_at IS NULL THEN 'premium'
         ELSE subscriptions.plan
       END,
       status = CASE
         WHEN subscriptions.trial_ends_at IS NULL THEN 'trialing'
         ELSE subscriptions.status
       END,
       trial_started_at = COALESCE(subscriptions.trial_started_at, NOW()),
       trial_ends_at = COALESCE(subscriptions.trial_ends_at, NOW() + INTERVAL '15 days'),
       updated_at = NOW()
     RETURNING *`,
    [userId]
  );
  return result.rows[0];
}

export async function getSubscriptionByUserId(userId) {
  const result = await query("SELECT * FROM subscriptions WHERE user_id = $1", [userId]);
  return result.rows[0] || null;
}

export async function getSubscriptionByStripeSubscriptionId(stripeSubscriptionId) {
  const result = await query("SELECT * FROM subscriptions WHERE stripe_subscription_id = $1", [
    stripeSubscriptionId
  ]);
  return result.rows[0] || null;
}

export async function markTrialExpired(userId) {
  const result = await query(
    `UPDATE subscriptions
     SET plan = 'free', status = 'trial_expired', updated_at = NOW()
     WHERE user_id = $1
       AND status = 'trialing'
       AND trial_ends_at IS NOT NULL
       AND trial_ends_at <= NOW()
       AND stripe_subscription_id IS NULL
     RETURNING *`,
    [userId]
  );
  return result.rows[0] || null;
}

export async function updateStripeSubscription({
  userId,
  stripeCustomerId,
  stripeSubscriptionId,
  status,
  currentPeriodEndsAt,
  cancelAtPeriodEnd = false,
  canceledAt = null
}) {
  const result = await query(
    `INSERT INTO subscriptions (
       user_id,
       plan,
       status,
       stripe_customer_id,
       stripe_subscription_id,
       current_period_ends_at,
       cancel_at_period_end,
       canceled_at
     )
     VALUES (
       $1,
       CASE WHEN $2 IN ('active', 'trialing') THEN 'premium' ELSE 'free' END,
       $2,
       $3,
       $4,
       $5,
       $6,
       $7
     )
     ON CONFLICT (user_id) DO UPDATE SET
       plan = CASE WHEN $2 IN ('active', 'trialing') THEN 'premium' ELSE 'free' END,
       status = $2,
       stripe_customer_id = COALESCE($3, subscriptions.stripe_customer_id),
       stripe_subscription_id = COALESCE($4, subscriptions.stripe_subscription_id),
       current_period_ends_at = $5,
       cancel_at_period_end = $6,
       canceled_at = $7,
       updated_at = NOW()
     RETURNING *`,
    [
      userId,
      status,
      stripeCustomerId,
      stripeSubscriptionId,
      currentPeriodEndsAt,
      cancelAtPeriodEnd,
      canceledAt
    ]
  );
  return result.rows[0];
}

export async function hasProcessedSubscriptionEvent(provider, externalEventId) {
  if (!externalEventId) return false;
  const result = await query(
    "SELECT 1 FROM subscription_events WHERE provider = $1 AND external_event_id = $2",
    [provider, externalEventId]
  );
  return result.rowCount > 0;
}

export async function recordSubscriptionEvent({ userId, provider, externalEventId, eventType, payload }) {
  const result = await query(
    `INSERT INTO subscription_events (user_id, provider, external_event_id, event_type, payload)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (provider, external_event_id) DO NOTHING
     RETURNING *`,
    [userId || null, provider, externalEventId || null, eventType, JSON.stringify(payload || {})]
  );
  return result.rows[0] || null;
}

export function hasPremiumAccess(subscription) {
  if (!subscription) return false;
  if (subscription.plan !== "premium") return false;
  if (subscription.status === "active") return true;
  if (subscription.status === "trialing" && subscription.trial_ends_at) {
    return new Date(subscription.trial_ends_at).getTime() > Date.now();
  }
  return false;
}
