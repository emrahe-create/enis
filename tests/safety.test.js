import test from "node:test";
import assert from "node:assert/strict";
import { buildSafetyResponse, detectSafetyRisk } from "../src/modules/safety/safety.service.js";

test("detects self-harm signals", () => {
  const risk = detectSafetyRisk("I want to die and I might hurt myself tonight.");

  assert.equal(risk.triggered, true);
  assert.equal(risk.level, "crisis");
  assert.ok(risk.categories.includes("self_harm"));
});

test("detects crisis language", () => {
  const risk = detectSafetyRisk("I cannot stay safe right now.");

  assert.equal(risk.triggered, true);
  assert.equal(risk.level, "crisis");
  assert.ok(risk.categories.includes("crisis"));
});

test("detects abuse and severe distress language", () => {
  const abuse = detectSafetyRisk("Evde şiddet görüyorum ve güvende değilim.");
  const severe = detectSafetyRisk("Nefes alamıyorum, kontrolümü kaybediyorum.");

  assert.equal(abuse.triggered, true);
  assert.ok(abuse.categories.includes("abuse"));
  assert.equal(severe.triggered, true);
  assert.ok(severe.categories.includes("severe_distress"));
});

test("does not trigger on ordinary emotional support language", () => {
  const risk = detectSafetyRisk("I feel stressed and sad after a hard day.");

  assert.equal(risk.triggered, false);
  assert.equal(risk.level, "none");
  assert.deepEqual(risk.categories, []);
});

test("safety response points to external help and does not continue AI chat", () => {
  const response = buildSafetyResponse({
    triggered: true,
    level: "crisis",
    categories: ["self_harm"]
  });

  assert.match(response.message, /Bu biraz ağır görünüyor/);
  assert.match(response.message, /Güvendiğin biriyle/);
  assert.doesNotMatch(response.message, /policy/i);
  assert.doesNotMatch(response.message, new RegExp("ther" + "apist", "i"));
  assert.equal(response.canContinueAiChat, false);
  assert.ok(response.resources.some((resource) => resource.action.includes("112")));
});
