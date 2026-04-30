import { env } from "../../config/env.js";
import { countUserMessagesSince } from "../chat/chat.repository.js";
import { ApiError } from "../../utils/http.js";
import {
  createFreeSubscription,
  getSubscriptionByUserId,
  hasPremiumAccess,
  markTrialExpired,
  startPremiumTrial
} from "./subscription.repository.js";

const CHAT_USAGE_WINDOW_MS = 24 * 60 * 60 * 1000;

export async function ensureFreeSubscription(userId) {
  return createFreeSubscription(userId);
}

export function getTrialState(subscription, now = new Date()) {
  const trialStartedAt = subscription?.trial_started_at ? new Date(subscription.trial_started_at) : null;
  const trialEndsAt = subscription?.trial_ends_at ? new Date(subscription.trial_ends_at) : null;
  const active = subscription?.status === "trialing" && trialEndsAt && trialEndsAt.getTime() > now.getTime();
  const expired = Boolean(trialStartedAt && trialEndsAt && trialEndsAt.getTime() <= now.getTime());
  const daysRemaining = active
    ? Math.max(0, Math.ceil((trialEndsAt.getTime() - now.getTime()) / CHAT_USAGE_WINDOW_MS))
    : 0;

  return {
    available: !trialStartedAt,
    active: Boolean(active),
    expired,
    startedAt: trialStartedAt,
    endsAt: trialEndsAt,
    daysRemaining
  };
}

export function buildFeatureEntitlements(subscription) {
  const premium = hasPremiumAccess(subscription);

  return {
    premium,
    fullFeatures: premium,
    premiumAvatars: premium,
    premiumChat: premium,
    unlimitedChat: premium,
    memoryChat: premium,
    emotionalDepth: premium,
    wellnessTools: premium,
    cbtJournal: premium,
    stripeBilling: true,
    expertMatching: false
  };
}

export function buildChatUsage({ used, premium, limit = env.FREE_DAILY_CHAT_LIMIT }) {
  if (premium) {
    return {
      period: "rolling_24_hours",
      used,
      limit: null,
      remaining: null,
      limited: false
    };
  }

  return {
    period: "rolling_24_hours",
    used,
    limit,
    remaining: Math.max(0, limit - used),
    limited: true
  };
}

async function syncSubscriptionLifecycle(userId) {
  let subscription = await getSubscriptionByUserId(userId);
  if (!subscription) subscription = await createFreeSubscription(userId);

  const expiredTrial = await markTrialExpired(userId);
  return expiredTrial || subscription;
}

export async function beginPremiumTrial(userId) {
  const subscription = await syncSubscriptionLifecycle(userId);
  if (hasPremiumAccess(subscription)) return subscription;
  if (subscription.trial_started_at) {
    throw new ApiError(409, "Premium trial has already been used");
  }

  return startPremiumTrial(userId);
}

export async function getEntitlements(userId) {
  const subscription = await syncSubscriptionLifecycle(userId);
  const entitlements = buildFeatureEntitlements(subscription);
  const since = new Date(Date.now() - CHAT_USAGE_WINDOW_MS);
  const used = await countUserMessagesSince(userId, since);

  return {
    subscription,
    trial: getTrialState(subscription),
    entitlements,
    usage: {
      chat: buildChatUsage({ used, premium: entitlements.unlimitedChat })
    }
  };
}

export async function assertChatAccess(userId) {
  const access = await getEntitlements(userId);
  const chatUsage = access.usage.chat;

  if (chatUsage.limited && chatUsage.remaining <= 0) {
    throw new ApiError(
      429,
      "Free chat limit reached. Upgrade to premium to unlock unlimited emotional support chat.",
      { usage: chatUsage }
    );
  }

  return access;
}
