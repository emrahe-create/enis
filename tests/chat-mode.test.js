import test from "node:test";
import assert from "node:assert/strict";
import {
  applyAvatarNameToResponse,
  aiUnavailableMessageTr,
  buildChatOutput,
  buildOpenAiMessages,
  buildSafetyChatOutput,
  buildUnavailableChatOutput,
  companionIdentity,
  detectMessageLanguage,
  detectRepeatedThemes,
  fallbackSupportReply,
  formatOpenAiErrorLog,
  isTooSimilarToRecentAssistant,
  openAiChatModel,
  parseOpenAiChatPayload,
  premiumAvatarCharacters,
  responseSimilarity,
  repeatsRecentAssistantResponse,
  resolvePremiumAvatarCharacter,
  resolveAvatarMode,
  safeSupportResponse,
  shouldUseAvatarName,
  validateCompanionResponse,
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
  assert.match(companionIdentity.meaning, /digital companion/);
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
    "avatarNameUsed",
    "responseSource"
  ]);
  assert.equal(output.avatarNameUsed, false);
  assert.equal(output.responseSource, "openai");
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

test("premium avatar character catalog is companion-only", () => {
  assert.equal(premiumAvatarCharacters.mira.name, "Mira");
  assert.equal(premiumAvatarCharacters.mira.personalityStyle, "samimi, yumuşak, destekleyici");
  assert.equal(premiumAvatarCharacters.eren.personalityStyle, "samimi, doğal, arkadaş gibi");
  assert.equal(premiumAvatarCharacters.arda.promptStyle, "calm, grounded, reassuring");
  assert.equal(premiumAvatarCharacters.kerem.voiceStyle, "enerjik");
  assert.equal(premiumAvatarCharacters.lina.voiceStyle, "enerjik");
  assert.equal(Object.keys(premiumAvatarCharacters).length, 7);

  const catalogText = Object.values(premiumAvatarCharacters)
    .map((item) => `${item.name} ${item.visualStyle} ${item.personalityStyle} ${item.voiceStyle}`)
    .join(" ")
    .toLowerCase();

  assert.equal(catalogText.includes("therapist"), false);
  assert.equal(catalogText.includes("doctor"), false);
  assert.equal(catalogText.includes("psikolog"), false);
  assert.equal(catalogText.includes("uzman"), false);
  assert.equal(catalogText.includes("aggressive"), false);
  assert.equal(catalogText.includes("dominant"), false);
  assert.equal(catalogText.includes("agresif"), false);
  assert.equal(catalogText.includes("baskın"), false);
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

  assert.ok(messages.some((item) => item.content.includes("You are Enis, a close digital companion")));
  assert.ok(messages.some((item) => item.content.includes("Listen first, reflect the feeling")));
  assert.ok(messages.some((item) => item.content.includes("Never say \"as an AI\"")));
  assert.ok(messages.some((item) => item.content.includes("help research, organize")));
  assert.ok(messages.some((item) => item.content.includes("at most 2 short sentences")));
  assert.ok(messages.some((item) => item.content.includes("start with emotional reflection")));
  assert.ok(messages.some((item) => item.content.includes("Do not give advice unless the user asks")));
  assert.ok(messages.some((item) => item.content.includes("Never ask \"neler yapmayı denedin?\"")));
  assert.ok(messages.some((item) => item.content.includes("no breathing suggestions unless asked")));
  assert.ok(messages.some((item) => item.content.includes("no generic suggestions")));
  assert.ok(messages.some((item) => item.content.includes("Avatar personality: Structured")));
  assert.ok(messages.some((item) => item.content.includes("Recent conversation history")));
  assert.ok(messages.some((item) => item.content.includes("work meetings make me tense")));
});

test("premium chat prompt includes selected character style", () => {
  const mira = resolvePremiumAvatarCharacter({
    avatarCharacterId: "mira",
    avatarCharacterName: "Mira"
  });
  const arda = resolvePremiumAvatarCharacter({
    avatarCharacterId: "arda",
    avatarCharacterName: "Arda"
  });
  const messages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    avatarCharacter: mira,
    message: "Bugün biraz yorgunum",
    emotion: anxiousEmotion
  });
  const ardaMessages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: true }),
    avatarPersonality: resolveAvatarPersonality("structured"),
    avatarCharacter: arda,
    message: "Bugün biraz yorgunum",
    emotion: anxiousEmotion
  });

  const characterPrompt = messages.find((item) => item.content.includes("Character:"));
  const ardaPrompt = ardaMessages.find((item) => item.content.includes("Character:"));

  assert.ok(characterPrompt);
  assert.ok(ardaPrompt);
  assert.match(characterPrompt.content, /Name: Mira/);
  assert.match(characterPrompt.content, /Style: warm, soft, supportive/);
  assert.match(characterPrompt.content, /Personality: samimi, yumuşak, destekleyici/);
  assert.match(characterPrompt.content, /Voice style: sakin/);
  assert.match(ardaPrompt.content, /Name: Arda/);
  assert.match(ardaPrompt.content, /Style: calm, grounded, reassuring/);
  assert.match(ardaPrompt.content, /Tone: kısa, sıcak, doğal/);
  assert.match(characterPrompt.content, /Speak consistently in this style/);
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

test("OpenAI prompt always asks for Turkish output", () => {
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
  assert.ok(englishMessages.some((item) => item.content.includes("respond in Turkish")));
  assert.equal(englishMessages.some((item) => item.content.includes("respond in English")), false);
  assert.ok(englishMessages.some((item) => item.content.includes("Return only valid JSON")));
  assert.ok(englishMessages.some((item) => item.content.includes("casual Turkish")));
  assert.ok(englishMessages.some((item) => item.content.includes("exactly one soft follow-up question")));
  assert.ok(englishMessages.some((item) => item.content.includes("empty string unless the user asks for practical help")));
});

test("OpenAI prompt includes up to the last five history messages", () => {
  const messages = buildOpenAiMessages({
    avatarMode: resolveAvatarMode({ premium: false }),
    avatarPersonality: resolveAvatarPersonality("warm"),
    message: "Bugün biraz sıkışmış hissediyorum",
    emotion: anxiousEmotion,
    memoryMessages: [
      { role: "user", content: "one" },
      { role: "assistant", content: "two" },
      { role: "user", content: "three" },
      { role: "assistant", content: "four" },
      { role: "user", content: "five" },
      { role: "assistant", content: "six" }
    ]
  });
  const chatMessages = messages.filter((item) => ["user", "assistant"].includes(item.role));

  assert.equal(chatMessages.some((item) => item.content === "one"), false);
  assert.ok(chatMessages.some((item) => item.content === "two"));
  assert.ok(chatMessages.some((item) => item.content === "six"));
  assert.equal(chatMessages.at(-1).content, "Bugün biraz sıkışmış hissediyorum");
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
  assert.match(output.response, /Bu biraz ağır görünüyor/);
  assert.match(output.response, /112 Acil/);
  assert.match(output.suggestion, /112/);
  assert.equal(output.memoryUsed, false);
  assert.equal(output.premiumUpsell, null);
  assert.equal(output.avatarNameUsed, false);
});

test("companion response validator catches robotic or repetitive replies", () => {
  const good = validateCompanionResponse(
    "İçin bugün bayağı sıkışmış gibi, buradayım. En çok hangi taraf üstüne geldi?",
    []
  );
  const generic = validateCompanionResponse(
    "Üzgün hissetmen normal. Yürüyüş yap iyi gelir. Kendine zaman tanı.",
    []
  );
  const robotic = validateCompanionResponse(
    "Moralinin bozuk olması zorlayıcı olabilir. Ne yapmayı düşünüyorsun?",
    []
  );
  const adviceHeavy = validateCompanionResponse(
    "Bu duyguyla başa çıkmak için neler yapmayı denedin? Belki derin bir nefes almak iyi gelebilir.",
    []
  );
  const repeated = validateCompanionResponse(
    "İçin bugün bayağı sıkışmış gibi, buradayım. En çok hangi taraf üstüne geldi?",
    [
      {
        role: "assistant",
        content:
          "İçin bugün bayağı sıkışmış gibi, buradayım. En çok hangi taraf üstüne geldi?"
      }
    ]
  );

  assert.equal(good.valid, true);
  assert.equal(good.questionCount, 1);
  assert.equal(generic.valid, false);
  assert.ok(generic.issues.includes("follow_up_question_count"));
  assert.ok(generic.issues.includes("generic_phrase"));
  assert.equal(robotic.valid, false);
  assert.ok(robotic.issues.includes("generic_phrase"));
  assert.equal(adviceHeavy.valid, false);
  assert.ok(adviceHeavy.issues.includes("generic_phrase"));
  assert.ok(adviceHeavy.issues.includes("advice_first"));
  assert.equal(repeated.valid, false);
  assert.ok(repeated.issues.includes("exact_repetition"));
});

test("repetition guard checks last three assistant replies by similarity", () => {
  const response =
    "Bugün iş tarafı seni epey yormuş gibi. Böyle günler insanın içini daraltabiliyor. En çok hangi an üstüne geldi?";
  const history = [
    { role: "assistant", content: "Eski ve alakasız bir cevap." },
    { role: "assistant", content: response },
    { role: "user", content: "evet" }
  ];

  assert.equal(responseSimilarity(response, response), 1);
  assert.equal(isTooSimilarToRecentAssistant(response, history), true);
});

test("restricted wellness wording is filtered from generated support text", () => {
  const fallback = "I hear you. Let us keep this gentle and small.";
  const restrictedReply = `This sounds like a ${"diagn" + "os" + "is"} with high ${"prob" + "ability"}.`;

  assert.equal(safeSupportResponse(restrictedReply, fallback), fallback);
  assert.equal(safeSupportResponse("I hear you. What would help a little right now?", fallback), "I hear you. What would help a little right now?");
});

test("chat unavailable fallback is Turkish and not a repeated static English reply", () => {
  const output = buildUnavailableChatOutput();

  assert.equal(output.response, aiUnavailableMessageTr);
  assert.equal(output.response, "Şu anda yanıt üretirken zorlandım… birazdan tekrar deneyelim mi?");
  assert.equal(output.response.includes("This sounds"), false);
  assert.equal(output.response.includes("It seems"), false);
  assert.equal(output.suggestion, "Bağlantı düzelince aynı mesajı tekrar deneyebilirsin.");
  assert.equal(output.memoryUsed, false);
  assert.equal(output.premiumUpsell, null);
  assert.equal(output.responseSource, "fallback");
});

test("OpenAI error logs include request id, model, code, and message", () => {
  const log = formatOpenAiErrorLog(
    { code: "rate_limit_exceeded", message: "Too many requests" },
    { requestId: "req-123", model: "gpt-4o-mini" }
  );

  assert.equal(log.OPENAI_ERROR_CODE, "rate_limit_exceeded");
  assert.equal(log.OPENAI_ERROR_MESSAGE, "Too many requests");
  assert.equal(log.model, "gpt-4o-mini");
  assert.equal(log.requestId, "req-123");
});

test("OpenAI chat payload parsing and repeat detection support dynamic responses", () => {
  assert.equal(openAiChatModel, "gpt-4o-mini");

  const parsed = parseOpenAiChatPayload(
    JSON.stringify({
      response: "Bunu taşımak yorucu gelmiş gibi. Şu an en çok hangi tarafı konuşmak istersin?",
      tone: "sakin ve destekleyici",
      suggestion: "Küçük bir mola iyi gelebilir."
    })
  );

  assert.match(parsed.response, /yorucu/);
  assert.equal(parsed.tone, "sakin ve destekleyici");
  assert.equal(parsed.suggestion, "Küçük bir mola iyi gelebilir.");
  assert.equal(
    repeatsRecentAssistantResponse(parsed.response, [
      { role: "assistant", content: parsed.response }
    ]),
    true
  );
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
