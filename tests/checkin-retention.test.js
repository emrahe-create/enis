import test from "node:test";
import assert from "node:assert/strict";
import {
  buildCheckInChatContext,
  buildContinuityLine,
  buildReturningGreeting,
  checkInNotificationCopy,
  dailyCheckInOptions,
  dailyPresenceCopy,
  hasGuiltLanguage,
  microEmotionalHook,
  microEmotionalHooks,
  nightReflectionPrompt,
  pushNotificationBlueprints,
  shouldShowDailyCheckIn,
  shouldShowDailyPresence,
  shouldShowSilenceNudge,
  shouldShowNightReflection
} from "../src/modules/checkins/checkin.service.js";

test("daily check-in saves chat context for Enis", () => {
  const context = buildCheckInChatContext({ mood: "Yoruldum" });

  assert.equal(dailyCheckInOptions.includes("Kaygılıyım"), true);
  assert.match(context, /Bugünkü kısa check-in: Yoruldum/);
  assert.match(context, /yumuşak ve kısa/);
});

test("only one check-in card appears per day", () => {
  assert.equal(shouldShowDailyCheckIn(null), true);
  assert.equal(shouldShowDailyCheckIn({ id: "checkin-1", mood: "Hafifim" }), false);
});

test("returning greeting uses memory when available", () => {
  const now = new Date("2026-05-04T09:00:00.000Z");
  const lastOpenedAt = new Date("2026-05-03T08:00:00.000Z");
  const greeting = buildReturningGreeting({
    lastOpenedAt,
    now,
    premium: true,
    memories: [
      {
        key: "work_stress",
        value: "İşinde yoğunluk ve baskı hissettiğini sık sık söylüyor.",
        importance: 5,
        updated_at: "2026-05-03T17:30:00.000Z"
      }
    ]
  });

  assert.equal(
    greeting,
    "Bir süredir yoktun… son konuşmamızda iş tarafı seni yormuştu. Bugün nasıl hissediyorsun?"
  );
});

test("returning greeting falls back without memory", () => {
  const greeting = buildReturningGreeting({
    lastOpenedAt: new Date("2026-05-03T08:00:00.000Z"),
    now: new Date("2026-05-04T09:00:00.000Z"),
    premium: true,
    memories: []
  });

  assert.equal(greeting, "Bir süredir konuşamadık… bugün nasıl gidiyor?");
});

test("returning greeting waits for 24 hours of inactivity", () => {
  assert.equal(
    buildReturningGreeting({
      lastOpenedAt: new Date("2026-05-03T18:00:00.000Z"),
      now: new Date("2026-05-04T09:00:00.000Z"),
      premium: false
    }),
    null
  );
});

test("same-day presence and micro hooks are gentle", () => {
  const now = new Date("2026-05-04T14:00:00.000Z");

  assert.equal(
    shouldShowDailyPresence({
      lastOpenedAt: new Date("2026-05-04T09:00:00.000Z"),
      now
    }),
    true
  );
  assert.equal(
    shouldShowDailyPresence({
      lastOpenedAt: new Date("2026-05-04T09:00:00.000Z"),
      now,
      returning: true
    }),
    false
  );
  assert.equal(dailyPresenceCopy, "Buradayım. İstersen devam edebiliriz.");
  assert.equal(microEmotionalHooks.includes(microEmotionalHook({ now, seed: 1 })), true);
});

test("silence nudge appears once after enough conversation", () => {
  assert.equal(
    shouldShowSilenceNudge({ userMessageCount: 1, assistantMessageCount: 2 }),
    false
  );
  assert.equal(
    shouldShowSilenceNudge({ userMessageCount: 2, assistantMessageCount: 2 }),
    true
  );
  assert.equal(
    shouldShowSilenceNudge({
      userMessageCount: 3,
      assistantMessageCount: 3,
      alreadyShown: true
    }),
    false
  );
});

test("night reflection appears after 20:00 local time", () => {
  assert.equal(shouldShowNightReflection(new Date("2026-05-04T19:59:00")), false);
  assert.equal(shouldShowNightReflection(new Date("2026-05-04T20:00:00")), true);
  assert.equal(
    nightReflectionPrompt(new Date("2026-05-04T21:00:00")),
    "Bugünü kapatmadan önce içinden geçen bir şey var mı?"
  );
});

test("retention copy has no guilt language", () => {
  const copy = [
    buildContinuityLine(3),
    checkInNotificationCopy.morning,
    checkInNotificationCopy.evening,
    checkInNotificationCopy.returning,
    dailyPresenceCopy,
    microEmotionalHooks.join(" "),
    pushNotificationBlueprints.enabled ? "enabled" : "disabled"
  ].join(" ");

  assert.match(copy, /3 gündür kendine küçük bir alan açıyorsun/);
  assert.equal(hasGuiltLanguage(copy), false);
  assert.equal(pushNotificationBlueprints.enabled, false);
});
