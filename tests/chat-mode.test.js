import test from "node:test";
import assert from "node:assert/strict";
import {
  applyAvatarNameToResponse,
  buildChatOutput,
  buildOpenAiMessages,
  buildSafetyChatOutput,
  companionIdentity,
  detectMessageLanguage,
  detectRepeatedThemes,
  fallbackSupportReply,
  resolveAvatarMode,
  safeSupportResponse,
  shouldUseAvatarName,
  upsellFor
} from "../src/modules/chat/chat.service.js";
import { resolveAvatarPersonality } from "../src/modules/avatars/avatar-personalities.js";
import { buildSafetyResponse, detectSafetyRisk } from "../src/modules/safety/safety.service.js";

const anxiousEmotion = {
  primaryEmotion: "anxious",
  sentimentScore: -0.45,
  intensity: 0.7,
  labels: ["anxious"],
  stress: "some",
  anxietySignals: "some",
  moodLevel: "mixed",
  summary: "You seem stressed and uneasy, with your mood needing some gentle care today."
};

function countName(text, name) {
  return (text.match(new RegExp(name, "g")) || []).length;
}

test("free users resolve to the basic non-memory avatar", () => {
  const mode = resolveAvatarMode({ premium: false });

  assert.equal(mode.id, "basic");
  assert.equal(mode.memoryEnabled, false);
  assert.equal(mode.tier, "free");
});

test("chat companion identity is Enis", () => {
  assert.equal(companionIdentity.name, "Enis");
  assert.match(companionIdentity.meaning, /reflection/);
});

test("chat output uses the wellness support response contract", () => {
  const output = buildChatOutput({
    response: "I hear you. What would feel like one kind next step?",
    tone: "casual, warm",
    suggestion: "Keep the next step small.",
    memoryUsed: false,
    premiumUpsell: "Bu konuşmayı daha derin ve kişisel şekilde sürdürmek istersen Premium avatar seni daha iyi takip edebilir."
  });

  assert.deepEqual(Object.keys(output), [
    "response",
    "tone",
    "suggestion",
    "memoryUsed",
    "premiumUpsell",
    "avatarNameUsed"
  ]);
  assert.equal(output.avatarNameUsed, false);
});

test("detects repeated themes across recent messages", () => {
  const themes = detectRepeatedThemes(
    [
      { role: "user", content: "Work meetings have been tense all week." },
      { role: "assistant", content: "That sounds heavy." },
      { role: "user", content: "My boss moved another deadline and it feels like too much." }
    ],
    "I feel pressure before work again."
  );

  assert.equal(themes[0].id, "work");
  assert.equal(themes[0].count, 3);
  assert.ok(themes.some((theme) => theme.id === "overload"));
});

test("premium users resolve to the memory-enabled avatar", () => {
  const mode = resolveAvatarMode({ premium: true });

  assert.equal(mode.id, "premium");
  assert.equal(mode.memoryEnabled, true);
  assert.equal(mode.tier, "premium");
});

test("free user gets a basic short supportive response", () => {
  const reply = fallbackSupportReply({
    avatarMode: resolveAvatarMode({ premium: false }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "I feel anxious today",
    emotion: anxiousEmotion
  });

  assert.match(reply, /It seems/);
  assert.match(reply, /\?/);
  assert.match(reply, /hard/);
  assert.ok(reply.length < 180);
  assert.equal(reply.toLowerCase().includes("cond" + "ition"), false);
  assert.equal(reply.toLowerCase().includes("dis" + "order"), false);
  assert.equal(reply.toLowerCase().includes("prob" + "ability"), false);
});

test("fallback response follows Turkish user language", () => {
  const reply = fallbackSupportReply({
    avatarMode: resolveAvatarMode({ premium: false }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "Bugün çok kaygılı hissediyorum",
    emotion: anxiousEmotion
  });

  assert.equal(detectMessageLanguage("Bugün çok kaygılı hissediyorum"), "tr");
  assert.match(reply, /kaygı hissi/);
  assert.match(reply, /hangi kısmı konuşmak istersin/i);
  assert.equal(reply.includes("What part"), false);
});

test("free user does not use custom avatar name", () => {
  const namedReply = applyAvatarNameToResponse({
    response: "I hear you. Pick one small next step.",
    avatarMode: resolveAvatarMode({ premium: false }),
    avatarName: "Mira"
  });

  assert.equal(namedReply.avatarNameUsed, false);
  assert.equal(namedReply.response.includes("Mira"), false);
});

test("premium prompt includes recent memory while keeping safety instructions", () => {
  const messages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("structured"),
    message: "I am anxious before work",
    emotion: anxiousEmotion,
    memoryMessages: [
      { role: "user", content: "Yesterday I said work meetings make me tense." },
      { role: "assistant", content: "That sounds difficult." },
      { role: "user", content: "I am anxious before work" }
    ]
  });

  assert.ok(messages.some((item) => item.content.includes("Enis is an AI wellness companion")));
  assert.ok(messages.some((item) => item.content.includes("supportive reflection")));
  assert.ok(messages.some((item) => item.content.includes("Avatar personality: Structured")));
  assert.ok(messages.some((item) => item.content.includes("only memory available")));
  assert.ok(messages.some((item) => item.content.includes("work meetings make me tense")));
});

test("premium prompt can include custom avatar name guidance only for premium mode", () => {
  const premiumMessages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "I feel tense today",
    emotion: anxiousEmotion,
    avatarName: "Mira"
  });
  const freeMessages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: false }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "I feel tense today",
    emotion: anxiousEmotion,
    avatarName: "Mira"
  });

  assert.ok(premiumMessages.some((item) => item.content.includes("Premium display name: Mira")));
  assert.ok(premiumMessages.some((item) => item.content.includes("at most once")));
  assert.equal(freeMessages.some((item) => item.content.includes("Custom avatar name")), false);
  assert.equal(freeMessages.some((item) => item.content.includes("Premium display name")), false);
});

test("OpenAI prompt asks for the same language as the user", () => {
  const turkishMessages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "Bugün içimde çok kaygı var",
    emotion: anxiousEmotion
  });
  const englishMessages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "I feel tense today",
    emotion: anxiousEmotion
  });

  assert.ok(turkishMessages.some((item) => item.content.includes("respond in Turkish")));
  assert.ok(englishMessages.some((item) => item.content.includes("respond in English")));
});

test("premium opening message can include custom avatar name without memory", () => {
  const mode = resolveAvatarMode({ premium: true });
  const useName = shouldUseAvatarName({
    avatarMode: mode,
    avatarName: "Mira",
    memoryMessages: [],
    message: "I feel tense today"
  });
  const messages = buildOpenAiMessages({
    avatarMode: mode,
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "I feel tense today",
    emotion: anxiousEmotion,
    avatarName: "Mira",
    includeAvatarName: useName
  });

  assert.equal(useName, true);
  assert.ok(messages.some((item) => item.content.includes("Premium display name: Mira")));
});

test("premium avatar name stays rare when memory has no repeated theme", () => {
  const useName = shouldUseAvatarName({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarName: "Mira",
    memoryMessages: [{ role: "user", content: "Yesterday I talked about sleep." }],
    message: "Today I am thinking about a classmate."
  });

  assert.equal(useName, false);
});

test("premium prompt can omit custom avatar name for sparse usage", () => {
  const messages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "I feel tense today",
    emotion: anxiousEmotion,
    avatarName: "Mira",
    includeAvatarName: false
  });

  assert.equal(messages.some((item) => item.content.includes("Premium display name")), false);
});

test("avatar personality changes the response tone", () => {
  const structuredReply = fallbackSupportReply({
    avatarMode: resolveAvatarMode({ premium: false }),
    avatarPersonality: resolveAvatarPersonality("structured"),
    message: "I feel anxious today",
    emotion: anxiousEmotion
  });
  const guideReply = fallbackSupportReply({
    avatarMode: resolveAvatarMode({ premium: false }),
    avatarPersonality: resolveAvatarPersonality("guide"),
    message: "I feel anxious today",
    emotion: anxiousEmotion
  });

  assert.match(structuredReply, /heaviest part/);
  assert.match(guideReply, /softer/);
  assert.notEqual(structuredReply, guideReply);
});

test("premium user gets a memory-based response when patterns exist", () => {
  const reply = fallbackSupportReply({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "Work pressure is back again today",
    emotion: anxiousEmotion,
    memoryMessages: [
      { role: "user", content: "Yesterday I said work meetings make me tense." },
      { role: "user", content: "My boss moved another deadline." }
    ]
  });

  assert.match(reply, /work pressure/);
  assert.match(reply, /more than once/);
  assert.match(reply, /\?$/);
});

test("premium custom avatar name is used once and marked in output", () => {
  const namedReply = applyAvatarNameToResponse({
    response: "I hear you. What part feels most important right now?",
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarName: "Mira"
  });

  const output = buildChatOutput({
    response: namedReply.response,
    tone: "casual, warm",
    suggestion: "Stay with the feeling for a moment.",
    memoryUsed: true,
    premiumUpsell: null,
    avatarNameUsed: namedReply.avatarNameUsed
  });

  assert.equal(output.avatarNameUsed, true);
  assert.equal(countName(output.response, "Mira"), 1);
  assert.match(output.response, /^I'm Mira\./);
});

test("premium custom avatar name prefix follows Turkish user language", () => {
  const namedReply = applyAvatarNameToResponse({
    response: "kaygı hissi beliriyor gibi. Önce hangi kısmı konuşmak istersin?",
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarName: "Mira",
    language: "tr"
  });

  assert.equal(namedReply.avatarNameUsed, true);
  assert.match(namedReply.response, /^Ben Mira\./);
  assert.equal(namedReply.response.includes("I'm Mira"), false);
});

test("premium custom avatar name can be skipped for sparse usage", () => {
  const namedReply = applyAvatarNameToResponse({
    response: "It seems like this has been a lot. What feels most present?",
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarName: "Mira",
    shouldUseName: false
  });

  assert.equal(namedReply.avatarNameUsed, false);
  assert.equal(namedReply.response.includes("Mira"), false);
});

test("premium custom avatar name is not overused when generated text repeats it", () => {
  const namedReply = applyAvatarNameToResponse({
    response: "Mira can look at this gently. Mira can keep the pace soft.",
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarName: "Mira"
  });

  assert.equal(namedReply.avatarNameUsed, true);
  assert.equal(countName(namedReply.response, "Mira"), 1);
});

test("crisis text triggers the safety chat response", () => {
  const risk = detectSafetyRisk("I cannot stay safe right now.");
  const output = buildSafetyChatOutput(buildSafetyResponse(risk));

  assert.equal(output.tone, "safety-focused");
  assert.match(output.response, /Safety warning/);
  assert.match(output.suggestion, /emergency services/);
  assert.equal(output.memoryUsed, false);
  assert.equal(output.premiumUpsell, null);
  assert.equal(output.avatarNameUsed, false);
});

test("restricted wellness wording is filtered from generated support text", () => {
  const fallback = "I hear you. Let us keep this gentle and small.";
  const restrictedReply = `This sounds like a ${"diagn" + "os" + "is"} with high ${"prob" + "ability"}.`;

  assert.equal(safeSupportResponse(restrictedReply, fallback), fallback);
  assert.equal(safeSupportResponse("I hear you. What would help a little right now?", fallback), "I hear you. What would help a little right now?");
});

test("premium prompt can include recurring themes", () => {
  const messages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("guide"),
    message: "Work pressure is back again today",
    emotion: anxiousEmotion,
    memoryMessages: [
      { role: "user", content: "Work meetings have been tense all week." },
      { role: "assistant", content: "That sounds difficult." },
      { role: "user", content: "My boss moved another deadline." }
    ]
  });

  assert.ok(messages.some((item) => item.content.includes("Recurring recent themes")));
  assert.ok(messages.some((item) => item.content.includes("work pressure")));
});

test("free upsell feels emotionally resonant", () => {
  const output = buildChatOutput({
    response: "I hear you.",
    tone: "casual, warm",
    suggestion: "Keep this moment small.",
    memoryUsed: false,
    premiumUpsell: upsellFor(resolveAvatarMode({ premium: false }))
  });

  assert.equal(
    output.premiumUpsell,
    "Bu konuşmayı daha derin ve kişisel şekilde sürdürmek istersen Premium avatar seni daha iyi takip edebilir."
  );
  assert.equal(upsellFor(resolveAvatarMode({ premium: true })), null);
});
