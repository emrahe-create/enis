import OpenAI from "openai";
import { env } from "../../config/env.js";
import { ApiError } from "../../utils/http.js";
import { analyzeEmotion, saveEmotionAnalysis } from "../analytics/emotion.service.js";
import { resolveAvatarPersonality } from "../avatars/avatar-personalities.js";
import { buildSafetyResponse, detectSafetyRisk } from "../safety/safety.service.js";
import { assertChatAccess } from "../subscriptions/subscription.service.js";
import { findUserById } from "../users/user.repository.js";
import {
  addMessage,
  createSession,
  getRecentConversationMemory,
  getSessionForUser,
  listSessions
} from "./chat.repository.js";

const openai = env.OPENAI_API_KEY ? new OpenAI({ apiKey: env.OPENAI_API_KEY }) : null;

export const companionIdentity = {
  name: "Enis",
  meaning: "a calm space for reflection",
  copy:
    "Enis is an AI wellness companion for supportive reflection."
};

export const avatarModes = {
  basic: {
    id: "basic",
    tier: "free",
    label: "Basic Support Avatar",
    memoryEnabled: false,
    maxTokens: 120,
    historyLimit: 1,
    prompt:
      "Free/basic mode. Give a brief, human, supportive response in 1-3 short sentences. Do not reference prior conversation memory. Reflect the feeling and ask at most one gentle follow-up question."
  },
  premium: {
    id: "premium",
    tier: "premium",
    label: "Premium Reflective Avatar",
    memoryEnabled: true,
    maxTokens: 320,
    historyLimit: 5,
    prompt:
      "Premium mode. Give a deeper but still short and natural response in 3-5 sentences. Occasionally use relevant memory, gently reflect recurring themes, and ask one warm follow-up question."
  }
};

const safetySystemPrompt = `
${companionIdentity.copy}
Your purpose is emotional support: listen, reflect, and gently guide without presenting yourself as a professional helper.
Use short, warm, human, non-judgmental language.
Structure each response by reflecting the user's emotion, asking one gentle follow-up question, and optionally offering a small helpful possibility.
Use soft wording like "it seems" or "it might be."
Avoid claims of being a personal relationship, a professional care role, or a substitute for real-world relationships.
Avoid need-based attachment language.
Avoid labels, certainty claims, scores, percentages, strict commands, and care-plan language.
If the user describes immediate danger, self-harm, harm to others, or crisis language, stop normal support and encourage external help.
`;

export function resolveAvatarMode(entitlements = {}) {
  return entitlements.premium ? avatarModes.premium : avatarModes.basic;
}

function emotionPhrase(emotion) {
  return emotionPhraseForLanguage(emotion, "en");
}

export function detectMessageLanguage(text = "") {
  const normalized = String(text || "").toLowerCase();
  if (/[çğıöşüİı]/.test(text)) return "tr";
  if (
    /\b(ben|bana|beni|bir|çok|bugün|içimde|icimde|hissediyorum|kaygı|kaygi|yalnız|yalniz|uyku|iş|aile|arkadaş|arkadas|zor|değil|degil|var|yok|mı|mi|mu|mü|başlamak|baslamak)\b/.test(
      normalized
    )
  ) {
    return "tr";
  }
  return "en";
}

function emotionPhraseForLanguage(emotion, language = "en") {
  if (language === "tr") {
    const labels = {
      anxious: "kaygı",
      sad: "hüzün",
      angry: "öfke",
      stressed: "stres",
      happy: "daha hafif bir enerji",
      neutral: "konuşacak çok şey"
    };
    return emotion.primaryEmotion === "neutral"
      ? "konuşacak çok şey var gibi"
      : `${labels[emotion.primaryEmotion] || "yoğun bir his"} hissi`;
  }

  return emotion.primaryEmotion === "neutral"
    ? "that there is a lot to sort through"
    : `${emotion.primaryEmotion} in what you shared`;
}

function getMemorySnippets(recentMessages, currentMessage) {
  return recentMessages
    .filter((item) => item.role === "user" && item.content !== currentMessage)
    .slice(-3)
    .map((item) => item.content.trim())
    .filter(Boolean);
}

const themeCatalog = [
  {
    id: "work",
    label: "work pressure",
    labelTr: "iş baskısı",
    keywords: ["work", "job", "boss", "meeting", "deadline", "career", "shift", "office"]
  },
  {
    id: "relationships",
    label: "relationship strain",
    labelTr: "ilişki yükü",
    keywords: ["partner", "companion", "relationship", "dating", "breakup", "argument", "isolated"]
  },
  {
    id: "family",
    label: "family pressure",
    labelTr: "aile baskısı",
    keywords: ["family", "parent", "mother", "father", "sibling", "home"]
  },
  {
    id: "sleep",
    label: "sleep and rest",
    labelTr: "uyku ve dinlenme",
    keywords: ["sleep", "tired", "exhausted", "rest", "night", "awake"]
  },
  {
    id: "self_trust",
    label: "self-trust",
    labelTr: "kendine güven",
    keywords: ["failure", "not enough", "doubt", "confidence", "worth", "guilt", "ashamed"]
  },
  {
    id: "overload",
    label: "feeling overloaded",
    labelTr: "fazla yüklenmiş hissetme",
    keywords: ["overwhelmed", "too much", "pressure", "stressed", "busy", "can't keep up", "cant keep up"]
  }
];

export function detectRepeatedThemes(memoryMessages = [], currentMessage = "") {
  const userTexts = [
    ...memoryMessages.filter((item) => item.role === "user").map((item) => item.content),
    currentMessage
  ].filter(Boolean);

  return themeCatalog
    .map((theme) => {
      const count = userTexts.reduce((total, text) => {
        const normalized = text.toLowerCase();
        return total + (theme.keywords.some((keyword) => normalized.includes(keyword)) ? 1 : 0);
      }, 0);
      return { id: theme.id, label: theme.label, count };
    })
    .filter((theme) => theme.count >= 2)
    .sort((a, b) => b.count - a.count)
    .slice(0, 2);
}

function patternLineFor(themes, language = "en") {
  if (!themes.length) return null;
  if (language === "tr") {
    const labels = themes.map((theme) => theme.labelTr || theme.label).join(" ve ");
    return `Burada ${labels} temasının birden fazla kez belirdiğini fark ediyorum.`;
  }

  const labels = themes.map((theme) => theme.label).join(" and ");
  const verb = themes.length === 1 ? "has" : "have";
  return `I am noticing ${labels} ${verb} come up more than once in what you have shared here.`;
}

export function buildChatOutput({
  response,
  tone,
  suggestion,
  memoryUsed,
  premiumUpsell = null,
  avatarNameUsed = false
}) {
  return {
    response,
    tone,
    suggestion,
    memoryUsed,
    premiumUpsell,
    avatarNameUsed
  };
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function normalizeAvatarName(avatarName) {
  const normalized = String(avatarName || "").replace(/\s+/g, " ").trim();
  if (!normalized || !/\p{L}|\p{N}/u.test(normalized)) return null;
  return normalized.slice(0, 40);
}

export function applyAvatarNameToResponse({
  response,
  avatarMode,
  avatarName,
  shouldUseName = true,
  language = "en"
}) {
  const cleanName = normalizeAvatarName(avatarName);
  const cleanResponse = String(response || "").trim();

  if (avatarMode.id !== "premium" || !cleanName || !cleanResponse || !shouldUseName) {
    return { response: cleanResponse, avatarNameUsed: false };
  }

  const namePattern = new RegExp(`(?<![A-Za-z0-9_])${escapeRegExp(cleanName)}(?![A-Za-z0-9_])`, "gi");
  const matches = cleanResponse.match(namePattern) || [];

  if (matches.length === 0) {
    return {
      response:
        language === "tr"
          ? `Ben ${cleanName}. ${cleanResponse}`
          : `I'm ${cleanName}. ${cleanResponse}`,
      avatarNameUsed: true
    };
  }

  if (matches.length === 1) {
    return { response: cleanResponse, avatarNameUsed: true };
  }

  let seen = 0;
  const responseWithSingleName = cleanResponse.replace(namePattern, (match) => {
    seen += 1;
    return seen === 1 ? match : "I";
  });

  return { response: responseWithSingleName, avatarNameUsed: true };
}

export function shouldUseAvatarName({
  avatarMode,
  avatarName,
  memoryMessages = [],
  message = ""
}) {
  if (avatarMode.id !== "premium" || !normalizeAvatarName(avatarName)) return false;

  const hasMemory = memoryMessages.some((item) => item.role === "user");
  if (!hasMemory) return true;

  return detectRepeatedThemes(memoryMessages, message).length > 0;
}

const blockedWellnessFragments = [
  "%",
  "percent",
  "diagn" + "os",
  "dis" + "order",
  "de" + "press",
  "prob" + "ability",
  "clin" + "ical",
  "treat" + "ment",
  "medical " + "condition"
];

function hasNonWellnessLanguage(text) {
  const normalized = String(text || "").toLowerCase();
  return blockedWellnessFragments.some((fragment) => normalized.includes(fragment));
}

export function safeSupportResponse(response, fallback) {
  const trimmed = String(response || "").trim();
  if (!trimmed || hasNonWellnessLanguage(trimmed)) return fallback;
  return trimmed;
}

function suggestionFor({ avatarMode, avatarPersonality, emotion, language = "en" }) {
  if (language === "tr") {
    if (avatarPersonality.id === "guide") {
      return "Yavaş bir nefes alıp biraz daha dengeli hissettiren şeyi fark etmek iyi gelebilir.";
    }

    if (avatarPersonality.id === "structured") {
      return "Hissi adlandırmak ve küçük bir sonraki adımı fark etmek iyi gelebilir.";
    }

    if (avatarMode.id === "premium" && emotion.stress !== "low") {
      return "Bir an bu hisle kalıp en küçük faydalı adımı fark etmek iyi gelebilir.";
    }

    return "Belki bir sonraki adımı küçük ve yumuşak tutabilirsin.";
  }

  if (avatarPersonality.id === "guide") {
    return "It might help to take one slow breath and notice what feels a little steadier.";
  }

  if (avatarPersonality.id === "structured") {
    return "It might help to name the feeling and notice one small next step.";
  }

  if (avatarMode.id === "premium" && emotion.stress !== "low") {
    return "It might help to stay with the feeling for a moment, then notice the smallest useful action.";
  }

  return "Maybe keep the next step small and gentle.";
}

export function upsellFor(avatarMode) {
  if (avatarMode.id === "premium") return null;
  return "Bu konuşmayı daha derin ve kişisel şekilde sürdürmek istersen Premium avatar seni daha iyi takip edebilir.";
}

function basicFallbackByPersonality(personality, emotion, language = "en") {
  const feeling = emotionPhraseForLanguage(emotion, language);

  if (language === "tr") {
    if (personality.id === "structured") {
      return [
        `${feeling} beliriyor gibi.`,
        "Şu anda en ağır gelen taraf ne? Küçük ve yönetilebilir bir adımı fark etmek iyi gelebilir."
      ].join(" ");
    }

    if (personality.id === "guide") {
      return [
        `${feeling} beliriyor gibi.`,
        "Şu anda ne biraz daha yumuşak hissettirir? Yavaş bir nefes küçük bir alan açabilir."
      ].join(" ");
    }

    return [
      `${feeling} beliriyor gibi.`,
      "Bu gerçekten zor olabilir. Önce hangi kısmı konuşmak istersin?"
    ].join(" ");
  }

  if (personality.id === "structured") {
    return [
      `It seems like ${feeling} is present.`,
      "What feels like the heaviest part right now? It might help to pause and notice one manageable next step."
    ].join(" ");
  }

  if (personality.id === "guide") {
    return [
      `It seems like ${feeling} is present.`,
      "What would feel a little softer right now? A slow breath out might give you a small quiet moment."
    ].join(" ");
  }

  return [
    `It seems like ${feeling} is present.`,
    "That sounds really hard. What part do you want to talk through first?"
  ].join(" ");
}

function premiumFallbackByPersonality({ personality, emotion, memoryLine, patternLine, language = "en" }) {
  const feeling = emotionPhraseForLanguage(emotion, language);
  const continuityLine = patternLine || memoryLine;

  if (language === "tr") {
    if (personality.id === "structured") {
      return [
        `${feeling} beliriyor gibi; buna sakin ve dikkatli bir yerden bakabiliriz. ${continuityLine}`,
        "Şu anda en karışık gelen taraf ne? Hissettiğin şeyi, ihtiyacını ve bekleyebilecek olanı yavaşça ayırmak iyi gelebilir."
      ].join(" ");
    }

    if (personality.id === "guide") {
      return [
        `${feeling} beliriyor gibi; buna acele etmeden yaklaşabiliriz. ${continuityLine}`,
        "Şu an denemesi yeterince huzurlu olan küçük şey ne? Daha uzun bir nefes bir sonraki anı biraz yumuşatabilir."
      ].join(" ");
    }

    return [
      `${feeling} beliriyor gibi; bunu fark etmek önemli olabilir. ${continuityLine}`,
      "Önce hangi kısmı konuşmak istersin?"
    ].join(" ");
  }

  if (personality.id === "structured") {
    return [
      `It seems like ${feeling} is present, and we can look at it in a steady, careful way. ${continuityLine}`,
      "What feels most tangled right now? It might help to gently separate what you feel, what you need, and what can wait."
    ].join(" ");
  }

  if (personality.id === "guide") {
    return [
      `It seems like ${feeling} is present, and it may help to approach it slowly. ${continuityLine}`,
      "What would feel peaceful enough to try now? A longer exhale might make the next moment a little gentler."
    ].join(" ");
  }

  return [
    `It seems like ${feeling} is present, and naming it may make it a little easier to look at. ${continuityLine}`,
    "What part feels most important to talk through next?"
  ].join(" ");
}

export function fallbackSupportReply({ avatarMode, avatarPersonality, message, emotion, memoryMessages = [] }) {
  const personality = avatarPersonality || resolveAvatarPersonality();
  const language = detectMessageLanguage(message);

  if (avatarMode.id === "basic") {
    return basicFallbackByPersonality(personality, emotion, language);
  }

  const memorySnippets = getMemorySnippets(memoryMessages, message);
  const repeatedThemes = detectRepeatedThemes(memoryMessages, message);
  const memoryLine =
    language === "tr"
      ? memorySnippets.length
        ? "Son konuşma çizgisini nazikçe aklımda tutuyorum."
        : "Bunu yavaşça ve adım adım tutabiliriz."
      : memorySnippets.length
        ? "I am keeping the recent thread gently in mind."
        : "We can stay with this gently and move one step at a time.";
  const patternLine = patternLineFor(repeatedThemes, language);

  return premiumFallbackByPersonality({ personality, emotion, memoryLine, patternLine, language });
}

export function buildOpenAiMessages({
  avatarMode,
  avatarPersonality,
  message,
  emotion,
  memoryMessages = [],
  avatarName = null,
  includeAvatarName = true
}) {
  const personality = avatarPersonality || resolveAvatarPersonality();
  const language = detectMessageLanguage(message);
  const cleanAvatarName =
    avatarMode.id === "premium" && includeAvatarName ? normalizeAvatarName(avatarName) : null;
  const baseMessages = [
    { role: "system", content: safetySystemPrompt },
    {
      role: "system",
      content: `Avatar personality: ${personality.name}. Tone: ${personality.tone}. ${personality.prompt}`
    },
    { role: "system", content: avatarMode.prompt },
    {
      role: "system",
      content: `Wellness signals: stress is ${emotion.stress}; anxiety signals are ${emotion.anxietySignals}; mood level is ${emotion.moodLevel}. Use this only for tone matching.`
    },
    {
      role: "system",
      content:
        "Response structure: reflect the user's emotion, ask one gentle follow-up question, and optionally suggest a small helpful action. Keep it short, natural, and not intense."
    },
    {
      role: "system",
      content:
        language === "tr"
          ? "Language: respond in Turkish. Do not mix Turkish and English unless the user does."
          : "Language: respond in English. Do not mix Turkish and English unless the user does."
    },
    ...(cleanAvatarName
      ? [
          {
            role: "system",
            content: `Premium display name: ${cleanAvatarName}. Use it at most once, only when it feels natural and not in every response.`
          }
        ]
      : [])
  ];

  if (!avatarMode.memoryEnabled) {
    return [...baseMessages, { role: "user", content: message }];
  }

  const repeatedThemes = detectRepeatedThemes(memoryMessages, message);
  const themeMessage = repeatedThemes.length
    ? {
        role: "system",
        content: `Recurring recent themes: ${repeatedThemes.map((theme) => theme.label).join(", ")}. If it feels natural, gently reflect the pattern in one short sentence.`
      }
    : null;

  return [
    ...baseMessages,
    {
      role: "system",
      content:
        "Recent messages are the only memory available. Use them only when directly relevant, and do not claim to know anything outside this chat history."
    },
    ...(themeMessage ? [themeMessage] : []),
    ...memoryMessages.map((item) => ({ role: item.role, content: item.content })),
    { role: "user", content: message }
  ];
}

export async function startChat(userId, title) {
  return createSession(userId, title);
}

export async function getChats(userId) {
  return listSessions(userId);
}

function safetyMessageForLanguage(safety, language = "en") {
  if (language === "tr") {
    return "Güvenlik uyarısı: Şu anki güvenliğinle ilgili endişelendim. Burada canlı kriz desteği sağlayamam. Kendine veya bir başkasına zarar verme ihtimali varsa acil servislerle ya da güvendiğin bir kriz hattıyla iletişime geçmen en güvenlisi olabilir. Türkiye'deysen 112 Acil Çağrı Merkezi'ni arayabilirsin. Mümkünse kendine zarar verebileceğin şeylerden uzaklaşmayı ve güvendiğin bir kişiye ulaşmayı dene.";
  }

  return safety.message;
}

export function buildSafetyChatOutput(safety, language = "en") {
  return buildChatOutput({
    response: safetyMessageForLanguage(safety, language),
    tone: "safety-focused",
    suggestion:
      language === "tr"
        ? "Acil servislerle ya da güvendiğin bir kriz hattıyla iletişime geçmek en güvenlisi olabilir."
        : "It may be safest to contact emergency services or a trusted crisis line now.",
    memoryUsed: false,
    premiumUpsell: null,
    avatarNameUsed: false
  });
}

async function sendSafetyMessage({ userId, sessionId, message }) {
  const safetyRisk = detectSafetyRisk(message);
  const safety = buildSafetyResponse(safetyRisk);
  const language = detectMessageLanguage(message);
  const session = sessionId ? await getSessionForUser(sessionId, userId) : await createSession(userId);
  if (!session) throw new ApiError(404, "Chat session not found");
  const safetyMessage = safetyMessageForLanguage(safety, language);

  await addMessage({
    sessionId: session.id,
    userId,
    role: "user",
    content: message,
    metadata: { safetyTriggered: true, safetyCategories: safety.categories }
  });

  await addMessage({
    sessionId: session.id,
    role: "assistant",
    content: safetyMessage,
    metadata: { safetyTriggered: true, responseType: "crisis_external_help", safety }
  });

  return buildSafetyChatOutput(safety, language);
}

export async function sendSupportMessage({ userId, sessionId, message, avatar }) {
  const safetyRisk = detectSafetyRisk(message);
  if (safetyRisk.triggered) {
    return sendSafetyMessage({ userId, sessionId, message });
  }

  const subscriptionAccess = await assertChatAccess(userId);
  const user = await findUserById(userId);
  if (!user) throw new ApiError(404, "User not found");

  const session = sessionId ? await getSessionForUser(sessionId, userId) : await createSession(userId);
  if (!session) throw new ApiError(404, "Chat session not found");

  const avatarMode = resolveAvatarMode(subscriptionAccess.entitlements);
  const avatarPersonality = resolveAvatarPersonality(avatar);
  const avatarName = avatarMode.id === "premium" ? user.avatarName || user.avatar_name : null;
  const language = detectMessageLanguage(message);

  const userMessage = await addMessage({
    sessionId: session.id,
    userId,
    role: "user",
    content: message,
    metadata: { avatarPersonality: avatarPersonality.id }
  });

  const emotion = await analyzeEmotion(message);
  await saveEmotionAnalysis({
    userId,
    source: "chat",
    sourceId: userMessage.id,
    analysis: emotion
  });

  const memoryMessages = avatarMode.memoryEnabled
    ? await getRecentConversationMemory(userId, userMessage.id, avatarMode.historyLimit)
    : [];
  const memoryUsed = avatarMode.memoryEnabled && memoryMessages.length > 0;
  const avatarNameAllowed = shouldUseAvatarName({ avatarMode, avatarName, memoryMessages, message });
  let reply = fallbackSupportReply({ avatarMode, avatarPersonality, message, emotion, memoryMessages });
  const fallbackReply = reply;

  if (openai) {
    const response = await openai.chat.completions.create({
      model: env.OPENAI_MODEL,
      temperature: avatarMode.id === "premium" ? 0.68 : 0.42,
      max_tokens: avatarMode.maxTokens,
      messages: buildOpenAiMessages({
        avatarMode,
        avatarPersonality,
        message,
        emotion,
        memoryMessages,
        avatarName,
        includeAvatarName: avatarNameAllowed
      })
    });
    reply = safeSupportResponse(response.choices[0].message.content, fallbackReply);
  }

  const namedReply = applyAvatarNameToResponse({
    response: reply,
    avatarMode,
    avatarName,
    shouldUseName: avatarNameAllowed,
    language
  });
  reply = namedReply.response;

  await addMessage({
    sessionId: session.id,
    role: "assistant",
    content: reply,
    metadata: {
      emotion,
      avatarMode: avatarMode.id,
      avatarPersonality: avatarPersonality.id,
      avatarNameUsed: namedReply.avatarNameUsed
    }
  });

  return buildChatOutput({
    response: reply,
    tone: avatarPersonality.tone,
    suggestion: suggestionFor({ avatarMode, avatarPersonality, emotion, language }),
    memoryUsed,
    premiumUpsell: upsellFor(avatarMode),
    avatarNameUsed: namedReply.avatarNameUsed
  });
}
