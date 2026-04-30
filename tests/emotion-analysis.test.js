import test from "node:test";
import assert from "node:assert/strict";
import {
  analyzeEmotionLocally,
  formatEmotionAnalysis
} from "../src/modules/analytics/emotion.service.js";

test("emotion analysis detects stress, anxiety signals, and mood level", () => {
  const analysis = analyzeEmotionLocally(
    "I am overwhelmed, tense, worried, and my thoughts are racing before tomorrow."
  );
  const output = formatEmotionAnalysis(analysis);

  assert.equal(output.stress, "some");
  assert.equal(output.anxietySignals, "some");
  assert.equal(output.moodLevel, "steady");
  assert.match(output.summary, /stress|worry|uneasy|pressure|edge/i);
});

test("emotion analysis output is human-readable and avoids labels or percentages", () => {
  const analysis = analyzeEmotionLocally("I feel sad, empty, exhausted, and under too much pressure.");
  const output = formatEmotionAnalysis(analysis);

  assert.deepEqual(Object.keys(output), ["stress", "anxietySignals", "moodLevel", "summary"]);
  assert.equal(output.moodLevel, "low");
  const serialized = JSON.stringify(output).toLowerCase();
  assert.equal(serialized.includes("%"), false);
  assert.equal(serialized.includes("percent"), false);
  assert.equal(serialized.includes("dis" + "order"), false);
  assert.equal(serialized.includes("prob" + "ability"), false);
  assert.equal(serialized.includes("cond" + "ition"), false);
});
