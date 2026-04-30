import test from "node:test";
import assert from "node:assert/strict";
import {
  buildChatUsage,
  buildFeatureEntitlements,
  getTrialState
} from "../src/modules/subscriptions/subscription.service.js";

test("15-day trial reports active premium access while it is unexpired", () => {
  const now = new Date("2026-05-01T00:00:00.000Z");
  const subscription = {
    plan: "premium",
    status: "trialing",
    trial_started_at: "2026-05-01T00:00:00.000Z",
    trial_ends_at: "2026-05-16T00:00:00.000Z"
  };

  const trial = getTrialState(subscription, now);
  const entitlements = buildFeatureEntitlements(subscription);

  assert.equal(trial.active, true);
  assert.equal(trial.daysRemaining, 15);
  assert.equal(entitlements.premium, true);
  assert.equal(entitlements.fullFeatures, true);
  assert.equal(entitlements.unlimitedChat, true);
});

test("expired trial removes premium access and free chat becomes limited", () => {
  const now = new Date("2026-04-17T00:00:00.000Z");
  const subscription = {
    plan: "free",
    status: "trial_expired",
    trial_started_at: "2026-04-01T00:00:00.000Z",
    trial_ends_at: "2026-04-16T00:00:00.000Z"
  };

  const trial = getTrialState(subscription, now);
  const entitlements = buildFeatureEntitlements(subscription);
  const usage = buildChatUsage({ used: 10, premium: entitlements.unlimitedChat, limit: 10 });

  assert.equal(trial.expired, true);
  assert.equal(entitlements.premium, false);
  assert.equal(usage.limited, true);
  assert.equal(usage.remaining, 0);
});

test("active Stripe premium unlocks full features and unlimited chat", () => {
  const subscription = {
    plan: "premium",
    status: "active",
    stripe_subscription_id: "sub_123"
  };

  const entitlements = buildFeatureEntitlements(subscription);
  const usage = buildChatUsage({ used: 42, premium: entitlements.unlimitedChat, limit: 10 });

  assert.equal(entitlements.fullFeatures, true);
  assert.equal(entitlements.memoryChat, true);
  assert.equal(usage.limited, false);
  assert.equal(usage.limit, null);
  assert.equal(usage.remaining, null);
});
