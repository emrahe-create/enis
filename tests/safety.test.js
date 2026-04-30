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

  assert.match(response.message, /Safety warning/);
  assert.match(response.message, /emergency services/);
  assert.match(response.message, /988/);
  assert.doesNotMatch(response.message, new RegExp("ther" + "apist", "i"));
  assert.equal(response.canContinueAiChat, false);
  assert.ok(response.resources.some((resource) => resource.url === "https://988lifeline.org"));
});
