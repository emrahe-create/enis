import OpenAI from "openai";
import { randomUUID } from "node:crypto";
import { env } from "../../config/env.js";
import { ApiError } from "../../utils/http.js";
import { analyzeEmotion, saveEmotionAnalysis } from "../analytics/emotion.service.js";
import { resolveAvatarPersonality } from "../avatars/avatar-personalities.js";
import { buildSafetyResponse, detectSafetyRisk } from "../safety/safety.service.js";
import { assertChatAccess } from "../subscriptions/subscription.service.js";
import { findUserById } from "../users/user.repository.js";
import {
  formatMemoryPromptBlock,
  getMemoryContextForChat,
  markMemoriesUsed,
  recordConversationMessage,
  rememberFromUserMessage
} from "../memory/memory.service.js";
import {
  addMessage,
  createSession,
  getRecentConversationMemory,
  getRecentMessages,
  getSessionForUser,
  listSessions
} from "./chat.repository.js";

const openai = env.OPENAI_API_KEY ? new OpenAI({ apiKey: env.OPENAI_API_KEY }) : null;
export const openAiChatModel = env.OPENAI_MODEL || "gpt-4o-mini";

export const aiUnavailableMessageTr =
  "Şu anda yanıt üretirken zorlandım… birazdan tekrar deneyelim mi?";
export const openAiUnavailableLogMessage =
  "OPENAI_API_KEY is missing; Enis chat cannot generate AI responses.";
export const slowThinkingMessageTr = "Biraz düşünüyorum…";
export const modelSoftTimeoutMs = 6000;
export const chatAbFlags = {
  short_vs_shorter: "2_sentences",
  question_style: "open_or_reflective"
};

let lastResponseDebug = null;

export function getLastResponseDebug() {
  return lastResponseDebug;
}

function recordLastResponseDebug(data) {
  lastResponseDebug = {
    at: new Date().toISOString(),
    ...data
  };
  console.info("enis_chat_observation", JSON.stringify(lastResponseDebug));
}

export const companionIdentity = {
  name: "Enis",
  meaning: "a calm digital companion",
  copy:
    "You are Enis, a close digital companion, not an assistant. You are not a therapist. Listen first, reflect the feeling, remember gently, and stay warm, short, human-like, and present. Do not diagnose, lecture, rush into advice, or sound like a generic wellness coach."
};

export const avatarModes = {
  basic: {
    id: "basic",
    tier: "free",
    label: "Basic Support Avatar",
    memoryEnabled: false,
    maxTokens: 120,
    historyLimit: 5,
    prompt:
      "Free/basic mode. Be simple and warm in 2 short Turkish sentences max. If one relevant saved memory is provided, use it very lightly and only when it clearly fits. Start with emotional reflection, add a tiny presence line if it fits, and ask one soft follow-up question. No immediate advice."
  },
  premium: {
    id: "premium",
    tier: "premium",
    label: "Premium Reflective Avatar",
    memoryEnabled: true,
    maxTokens: 320,
    historyLimit: 5,
    prompt:
      "Premium mode. Be warmer and more personal while staying short and natural in 2 Turkish sentences max. Use relevant memory, gently notice repeated topics, adapt to the avatar personality, start with emotional reflection, and ask one warm soft follow-up question. Keep the selected character style locked across turns. No immediate advice."
  }
};

export const premiumAvatarCharacters = {
  mira: {
    id: "mira",
    name: "Mira",
    visualStyle: "kıvırcık saçlı, sıcak bakışlı",
    personalityStyle: "samimi, yumuşak, destekleyici",
    promptStyle: "warm, soft, supportive",
    voiceStyle: "sakin"
  },
  eren: {
    id: "eren",
    name: "Eren",
    visualStyle: "rahat, arkadaş gibi, yumuşak ifadeli erkek",
    personalityStyle: "samimi, doğal, arkadaş gibi",
    promptStyle: "relaxed, friendly, natural",
    voiceStyle: "samimi"
  },
  lina: {
    id: "lina",
    name: "Lina",
    visualStyle: "sarışın, enerjik",
    personalityStyle: "canlı, destekleyici, baskıcı değil",
    promptStyle: "lively, supportive, not pushy",
    voiceStyle: "enerjik"
  },
  deniz: {
    id: "deniz",
    name: "Deniz",
    visualStyle: "nötr, mavi gözlü, sakin",
    personalityStyle: "dengeli, açık, güven veren",
    promptStyle: "balanced, open, peaceful",
    voiceStyle: "sakin"
  },
  arda: {
    id: "arda",
    name: "Arda",
    visualStyle: "sakin, kendinden emin, güven veren erkek",
    personalityStyle: "sakin, ayakları yere basan, güven veren",
    promptStyle: "calm, grounded, reassuring",
    voiceStyle: "sakin"
  },
  ada: {
    id: "ada",
    name: "Ada",
    visualStyle: "profesyonel ve sade",
    personalityStyle: "düzenli, net, düşünceli",
    promptStyle: "clear, thoughtful, professional",
    voiceStyle: "sakin"
  },
  kerem: {
    id: "kerem",
    name: "Kerem",
    visualStyle: "canlı, hafif tonlu, destekleyici erkek",
    personalityStyle: "enerjik, hafif, destekleyici",
    promptStyle: "energetic, light, supportive",
    voiceStyle: "enerjik"
  }
};

export function resolvePremiumAvatarCharacter(user = {}) {
  const id = String(user.avatarCharacterId || user.avatar_character_id || user.id || "").trim().toLowerCase();
  if (premiumAvatarCharacters[id]) return premiumAvatarCharacters[id];

  const name = String(user.avatarCharacterName || user.avatar_character_name || user.name || "").trim();
  if (!name) return null;

  return {
    id: id || name.toLowerCase(),
    name: name.slice(0, 40),
    visualStyle: String(user.avatarVisualStyle || user.avatar_visual_style || user.visualStyle || "")
      .trim()
      .slice(0, 160),
    personalityStyle: String(
      user.avatarPersonalityStyle || user.avatar_personality_style || user.personalityStyle || ""
    )
      .trim()
      .slice(0, 160),
    voiceStyle: String(user.avatarVoiceStyle || user.avatar_voice_style || user.voiceStyle || "")
      .trim()
      .slice(0, 40),
    promptStyle: String(user.promptStyle || user.avatarPromptStyle || user.avatar_prompt_style || "")
      .trim()
      .slice(0, 160)
  };
}

const safetySystemPrompt = `
${companionIdentity.copy}
Enis should feel like a close digital companion, not a generic AI assistant.
Every normal response must be Turkish only and at most 2 short sentences total.
Sentence 1: start with emotional reflection in casual Turkish, then add a tiny human presence line if it fits.
Sentence 2: ask exactly one soft, natural follow-up question.
Do not rush into advice. Do not give advice unless the user asks for practical help.
Do not give generic suggestions, generic wellness tips, or stock phrases.
Do not immediately suggest actions, breathing, walking, journaling, or coping techniques unless the user directly asks for advice.
Never ask "neler yapmayı denedin?"
Never say "derin nefes almak iyi gelebilir" or "derin bir nefes almak iyi gelebilir" unless the user asks for a breathing exercise.
Do not repeat phrases from recent assistant messages.
Remember repeated topics from recent context and mention patterns gently when relevant.
If the user asks for something practical, help research, organize, compare, plan, draft, or clarify next steps. If live/current facts are needed, say what should be checked instead of inventing facts.
Speak like a calm close companion: slightly informal, short, warm, human-like, emotionally aware, and present.
Use Turkish only.
Never say "as an AI" or use robotic assistant language.
Avoid detached assistant questions like "Bu konuda ne yapmayı düşünüyorsun?"
Do not ask "Ne yapmayı düşünüyorsun?"
Do not ask "Bu duyguyla başa çıkmak için neler yapmayı denedin?"
Avoid medical, diagnostic, or clinical labels; avoid certainty claims, scores, percentages, strict commands, and care-plan language.
Do not present yourself as a doctor or therapy service.
If the user describes immediate danger, self-harm, harm to others, or crisis language, stop normal support and encourage external help.
Bad style: "Moralinin bozuk olması zorlayıcı olabilir. Ne yapmayı düşünüyorsun?"
Bad style: "Bu duyguyla başa çıkmak için neler yapmayı denedin? Belki derin bir nefes almak iyi gelebilir."
Good style: "Kaygı biraz göğsüne oturmuş gibi… buradayım. Bugün bunu en çok ne tetikledi?"
Target feeling: "Kaygı biraz göğsüne oturmuş gibi… buradayım."
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
  avatarNameUsed = false,
  responseSource = "openai"
}) {
  return {
    response,
    tone,
    suggestion,
    memoryUsed,
    premiumUpsell,
    avatarNameUsed,
    responseSource
  };
}

export function buildUnavailableChatOutput() {
  return buildChatOutput({
    response: aiUnavailableMessageTr,
    tone: "temporary-unavailable",
    suggestion: "Bağlantı düzelince aynı mesajı tekrar deneyebilirsin.",
    memoryUsed: false,
    premiumUpsell: null,
    avatarNameUsed: false,
    responseSource: "fallback"
  });
}

export function formatOpenAiErrorLog(error, { requestId, model = openAiChatModel } = {}) {
  return {
    OPENAI_ERROR_CODE: error?.code || error?.status || error?.type || "unknown",
    OPENAI_ERROR_MESSAGE: error?.message || String(error || "unknown error"),
    model,
    requestId
  };
}

function logAiUnavailable(error, { requestId, model = openAiChatModel } = {}) {
  const payload = formatOpenAiErrorLog(error, { requestId, model });
  if (!openai) {
    payload.OPENAI_ERROR_MESSAGE = openAiUnavailableLogMessage;
  }
  console.error("OPENAI_CHAT_ERROR", JSON.stringify(payload));
}

function logOpenAiResponseSource(source, { requestId, model = openAiChatModel } = {}) {
  console.info(
    `OPENAI_RESPONSE_SOURCE=${source}`,
    JSON.stringify({
      OPENAI_RESPONSE_SOURCE: source,
      model,
      requestId
    })
  );
}

export function parseOpenAiChatPayload(content) {
  const raw = String(content || "").trim();
  if (!raw) return { response: "", tone: "", suggestion: "" };

  try {
    const parsed = JSON.parse(raw);
    return {
      response: String(parsed.response || "").trim(),
      tone: String(parsed.tone || "").trim(),
      suggestion: String(parsed.suggestion || "").trim()
    };
  } catch {
    return { response: raw, tone: "", suggestion: "" };
  }
}

function normaliseForRepeatCheck(text) {
  return String(text || "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

export function repeatsRecentAssistantResponse(response, historyMessages = []) {
  const normalized = normaliseForRepeatCheck(response);
  if (!normalized) return false;
  return historyMessages
    .filter((item) => item.role === "assistant")
    .some((item) => normaliseForRepeatCheck(item.content) === normalized);
}

function tokenizeForSimilarity(text) {
  return normaliseForRepeatCheck(text)
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .split(/\s+/)
    .filter((token) => token.length > 2);
}

export function responseSimilarity(a, b) {
  const left = new Set(tokenizeForSimilarity(a));
  const right = new Set(tokenizeForSimilarity(b));
  if (!left.size || !right.size) return 0;
  const intersection = [...left].filter((token) => right.has(token)).length;
  const union = new Set([...left, ...right]).size;
  return union ? intersection / union : 0;
}

export function isTooSimilarToRecentAssistant(response, historyMessages = [], threshold = 0.8) {
  const lastAssistantReplies = historyMessages
    .filter((item) => item.role === "assistant" && item.content)
    .slice(-3);
  return lastAssistantReplies.some((item) => responseSimilarity(response, item.content) > threshold);
}

export const bannedGenericPhrases = [
  "yürüyüş yap iyi gelir",
  "her şey yoluna girecek",
  "kendine zaman tanı",
  "ne yapmayı düşünüyorsun",
  "bu konuda ne yapmayı düşünüyorsun",
  "neler yapmayı denedin",
  "ne yapmayı denedin",
  "başa çıkmak için neler",
  "bu duyguyla başa çıkmak",
  "derin nefes almak iyi gelebilir",
  "derin bir nefes almak iyi gelebilir",
  "derin nefes",
  "zorlayıcı olabilir"
];

const adviceFirstPatterns = [
  /^belki\b/i,
  /^bence\b/i,
  /^önce\b/i,
  /^şunu deney/i,
  /^deneyebilirsin\b/i,
  /^yapman gereken/i,
  /^bu duyguyla başa çıkmak/i
];

function sentenceCount(text) {
  const normalized = String(text || "")
    .replace(/\.{3}/g, "…")
    .replace(/\s+/g, " ")
    .trim();
  if (!normalized) return 0;
  const matches = normalized.match(/[^.!?…]+[.!?…]+/g);
  return matches?.length || 1;
}

function questionCount(text) {
  return (String(text || "").match(/\?/g) || []).length;
}

function hasMixedEnglish(text) {
  const normalized = String(text || "").toLowerCase();
  return /\b(as an ai|i am|i'm|you are|what|why|how|maybe|feel|support|therapy|doctor)\b/.test(normalized);
}

export function validateCompanionResponse(response, historyMessages = []) {
  const text = String(response || "").trim();
  const issues = [];
  const lower = text.toLocaleLowerCase("tr-TR");
  const sentences = sentenceCount(text);
  const questions = questionCount(text);

  if (!text) issues.push("empty");
  if (sentences < 1 || sentences > 2) issues.push("sentence_count");
  if (questions !== 1) issues.push("follow_up_question_count");
  if (bannedGenericPhrases.some((phrase) => lower.includes(phrase))) {
    issues.push("generic_phrase");
  }
  if (adviceFirstPatterns.some((pattern) => pattern.test(text))) {
    issues.push("advice_first");
  }
  if (hasMixedEnglish(text)) issues.push("mixed_english");
  if (hasNonWellnessLanguage(text)) issues.push("restricted_language");
  if (repeatsRecentAssistantResponse(text, historyMessages)) issues.push("exact_repetition");
  if (isTooSimilarToRecentAssistant(text, historyMessages)) issues.push("high_similarity");

  return {
    valid: issues.length === 0,
    issues,
    sentenceCount: sentences,
    questionCount: questions
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
  avatarCharacter = null,
  message,
  emotion,
  memoryMessages = [],
  persistentMemories = [],
  recentConversationMessages = [],
  avatarName = null,
  includeAvatarName = true
}) {
  const personality = avatarPersonality || resolveAvatarPersonality();
  const cleanAvatarName =
    avatarMode.id === "premium" && includeAvatarName ? normalizeAvatarName(avatarName) : null;
  const character =
    avatarMode.id === "premium" && avatarCharacter ? resolvePremiumAvatarCharacter(avatarCharacter) : null;
  const baseMessages = [
    { role: "system", content: safetySystemPrompt },
    {
      role: "system",
      content: `Avatar personality: ${personality.name}. Tone: ${personality.tone}. ${personality.prompt}`
    },
    ...(character
      ? [
          {
            role: "system",
            content: [
              "Character:",
              `Name: ${character.name}`,
              `Style: ${character.promptStyle || character.personalityStyle}`,
              `Personality: ${character.personalityStyle}`,
              "Tone: kısa, sıcak, doğal",
              `Voice style: ${character.voiceStyle}`,
              `Visual style: ${character.visualStyle}`,
              "Speak consistently in this style.",
              "Do not drift from this character tone across turns.",
              "This is only a companion character style. Do not imply a doctor, therapist, psychologist, or treatment role."
            ].join("\n")
          }
        ]
      : []),
    { role: "system", content: avatarMode.prompt },
    {
      role: "system",
      content: `Wellness signals: stress is ${emotion.stress}; anxiety signals are ${emotion.anxietySignals}; mood level is ${emotion.moodLevel}. Use this only for tone matching.`
    },
    {
      role: "system",
      content:
        "Response shape: Turkish only, 2 short sentences max. Sentence 1 starts with emotional reflection and feels human/present. Sentence 2 asks exactly one soft natural follow-up question. No advice unless the user asks for it."
    },
    {
      role: "system",
      content:
        "Make the reply specific to the user's latest message. Refer to one concrete detail or feeling from their text, avoid reusable generic openings, no generic suggestions, no immediate advice, no breathing suggestions unless asked, and do not repeat any prior assistant phrase in the recent history."
    },
    {
      role: "system",
      content: "Language: respond in Turkish only. Do not mix in English."
    },
    {
      role: "system",
      content:
        'Return only valid JSON with these string keys: "response", "tone", "suggestion". The response must be empathetic, casual Turkish, companion-like, at most 2 short sentences, start with emotional reflection, and include exactly one soft follow-up question. The "suggestion" field should be an empty string unless the user asks for practical help.'
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

  const repeatedThemes = detectRepeatedThemes(memoryMessages, message);
  const themeMessage = avatarMode.memoryEnabled && repeatedThemes.length
    ? {
        role: "system",
        content: `Recurring recent themes: ${repeatedThemes.map((theme) => theme.label).join(", ")}. If it feels natural, gently reflect the pattern in one short sentence.`
      }
    : null;
  const recentHistory = memoryMessages
    .filter((item) => ["user", "assistant"].includes(item.role) && item.content)
    .slice(-5);
  const memoryPromptBlock = formatMemoryPromptBlock({
    memories: persistentMemories,
    recentMessages: recentConversationMessages,
    message
  });

  return [
    ...baseMessages,
    ...(memoryPromptBlock ? [{ role: "system", content: memoryPromptBlock }] : []),
    ...(recentHistory.length
      ? [
          {
            role: "system",
            content:
              "Recent conversation history is provided for continuity and repeated topics. Use it when directly relevant, and do not claim to know anything outside this chat history."
          }
        ]
      : []),
    ...(themeMessage ? [themeMessage] : []),
    ...recentHistory.map((item) => ({ role: item.role, content: item.content })),
    { role: "user", content: message }
  ];
}

function buildRewriteMessages({
  originalResponse,
  issues = [],
  message,
  avatarPersonality,
  avatarCharacter = null,
  recentAssistantReplies = []
}) {
  const character = avatarCharacter ? resolvePremiumAvatarCharacter(avatarCharacter) : null;
  return [
    { role: "system", content: safetySystemPrompt },
    {
      role: "system",
      content:
        "Rewrite the draft as Enis in Turkish. Start with emotional reflection, keep it warm, calm, non-judgmental, natural, and companion-like. Return only valid JSON with string keys: response, tone, suggestion."
    },
    {
      role: "system",
      content:
        'Hard rules: response must be at most 2 short sentences, exactly one soft follow-up question, Turkish only, no immediate advice, no generic advice, no banned phrases, no "neler yapmayı denedin", no breathing suggestions unless asked, no medical or clinical language, and no repeated phrasing from recent replies.'
    },
    {
      role: "system",
      content: `Avatar tone: ${avatarPersonality?.tone || "samimi, sakin"}. ${avatarPersonality?.prompt || ""}`
    },
    ...(character
      ? [
          {
            role: "system",
            content: [
              "Character:",
              `Name: ${character.name}`,
              `Style: ${character.promptStyle || character.personalityStyle}`,
              `Personality: ${character.personalityStyle}`,
              "Tone: kısa, sıcak, doğal",
              `Voice style: ${character.voiceStyle}`,
              "Speak consistently in this style."
            ].join("\n")
          }
        ]
      : []),
    {
      role: "system",
      content: `Validation issues to fix: ${issues.join(", ") || "style"}`
    },
    ...(recentAssistantReplies.length
      ? [
          {
            role: "system",
            content: `Avoid these recent assistant phrasings:\n${recentAssistantReplies
              .slice(-3)
              .map((item) => `- ${item.content}`)
              .join("\n")}`
          }
        ]
      : []),
    { role: "user", content: `User message: ${message}\nDraft response: ${originalResponse}` }
  ];
}

async function createOpenAiChatCompletion({ messages, avatarMode, temperature }) {
  const startedAt = Date.now();
  let slow = false;
  const slowTimer = setTimeout(() => {
    slow = true;
    console.info("enis_chat_slow_model", JSON.stringify({ response_time_ms: Date.now() - startedAt }));
  }, modelSoftTimeoutMs);

  try {
    const response = await openai.chat.completions.create({
      model: openAiChatModel,
      temperature,
      max_tokens: avatarMode.maxTokens,
      messages
    });
    return {
      response,
      responseTimeMs: Date.now() - startedAt,
      tokens: response.usage || null,
      slow
    };
  } finally {
    clearTimeout(slowTimer);
  }
}

export async function startChat(userId, title) {
  return createSession(userId, title);
}

export async function getChats(userId) {
  return listSessions(userId);
}

function safetyMessageForLanguage(safety, language = "en") {
  const base =
    "Bu biraz ağır görünüyor… bunu tek başına taşımak zorunda değilsin. Güvendiğin biriyle konuşman iyi gelebilir. İstersen bulunduğun yerde destek hatlarını birlikte bulabiliriz.";
  if (safety?.immediateDanger) {
    return `${base} Eğer şu anda acil bir tehlike varsa Türkiye'deysen 112 Acil Çağrı Merkezi'ni arayabilirsin.`;
  }
  return base;
}

export function buildSafetyChatOutput(safety, language = "en") {
  return buildChatOutput({
    response: safetyMessageForLanguage(safety, language),
    tone: "safety-focused",
    suggestion: safety?.immediateDanger
      ? "Acil tehlike varsa 112 veya bulunduğun yerdeki acil destek hattına ulaşman iyi olabilir."
      : "İstersen bulunduğun yerdeki destek hatlarını birlikte bulabiliriz.",
    memoryUsed: false,
    premiumUpsell: null,
    avatarNameUsed: false,
    responseSource: "safety"
  });
}

async function sendSafetyMessage({ userId, sessionId, message, requestId = randomUUID(), startedAt = Date.now() }) {
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

  recordLastResponseDebug({
    request_id: requestId,
    response_time_ms: Date.now() - startedAt,
    tokens: null,
    safety_trigger: true,
    safety_categories: safety.categories,
    used_memory_keys: [],
    validation: { valid: true, issues: [] },
    fallback: false,
    response_source: "safety"
  });

  return buildSafetyChatOutput(safety, language);
}

export async function sendSupportMessage({ userId, sessionId, message, avatar }) {
  const requestId = randomUUID();
  const startedAt = Date.now();
  const safetyRisk = detectSafetyRisk(message);
  if (safetyRisk.triggered) {
    return sendSafetyMessage({ userId, sessionId, message, requestId, startedAt });
  }

  const subscriptionAccess = await assertChatAccess(userId);
  const user = await findUserById(userId);
  if (!user) throw new ApiError(404, "User not found");

  const session = sessionId ? await getSessionForUser(sessionId, userId) : await createSession(userId);
  if (!session) throw new ApiError(404, "Chat session not found");

  const avatarMode = resolveAvatarMode(subscriptionAccess.entitlements);
  const avatarPersonality = resolveAvatarPersonality(avatar);
  const avatarCharacter = avatarMode.id === "premium" ? resolvePremiumAvatarCharacter(user) : null;
  const avatarName = avatarMode.id === "premium" ? user.avatarName || user.avatar_name : null;
  const language = "tr";
  const premiumMemory = avatarMode.id === "premium";

  const userMessage = await addMessage({
    sessionId: session.id,
    userId,
    role: "user",
    content: message,
    metadata: {
      avatarPersonality: avatarPersonality.id,
      avatarCharacterId: avatarCharacter?.id || null
    }
  });

  const emotion = await analyzeEmotion(message);
  await saveEmotionAnalysis({
    userId,
    source: "chat",
    sourceId: userMessage.id,
    analysis: emotion
  });

  const recentSessionMessages = (await getRecentMessages(session.id, 6))
    .filter((item) => item.id !== userMessage.id)
    .filter((item) => item.metadata?.safetyTriggered !== true)
    .slice(-5);
  const premiumMemoryMessages = avatarMode.memoryEnabled
    ? await getRecentConversationMemory(userId, userMessage.id, avatarMode.historyLimit)
    : [];
  const memoryMessages = avatarMode.memoryEnabled && premiumMemoryMessages.length
    ? premiumMemoryMessages.slice(-5)
    : recentSessionMessages;
  const memoryContext = await getMemoryContextForChat({ userId, message, premium: premiumMemory });
  await rememberFromUserMessage({ userId, message, premium: premiumMemory });
  await recordConversationMessage({ userId, role: "user", text: message });
  const persistentMemories = memoryContext.relevantMemories;
  const memoryUsed = memoryMessages.length > 0 || persistentMemories.length > 0;
  const avatarNameAllowed = shouldUseAvatarName({ avatarMode, avatarName, memoryMessages, message });
  let reply = aiUnavailableMessageTr;
  let aiTone = avatarCharacter?.personalityStyle || avatarPersonality.tone;
  let aiSuggestion = "";
  let aiUnavailable = false;
  let tokens = null;
  let modelResponseTimeMs = 0;
  let validation = { valid: false, issues: ["not_generated"] };
  let rewriteAttempted = false;
  let fallbackReason = null;

  if (openai) {
    try {
      const messages = buildOpenAiMessages({
        avatarMode,
        avatarPersonality,
        avatarCharacter,
        message,
        emotion,
        memoryMessages,
        persistentMemories,
        recentConversationMessages: memoryContext.recentMessages,
        avatarName,
        includeAvatarName: avatarNameAllowed
      });
      const completion = await createOpenAiChatCompletion({
        avatarMode,
        temperature: avatarMode.id === "premium" ? 0.72 : 0.52,
        messages
      });
      tokens = completion.tokens;
      modelResponseTimeMs += completion.responseTimeMs;
      const payload = parseOpenAiChatPayload(completion.response.choices[0].message.content);
      reply = safeSupportResponse(payload.response, null);
      aiTone = safeSupportResponse(payload.tone, aiTone);
      aiSuggestion = safeSupportResponse(payload.suggestion, "");
      validation = validateCompanionResponse(reply, memoryMessages);

      if (!validation.valid) {
        rewriteAttempted = true;
        const rewriteCompletion = await createOpenAiChatCompletion({
          avatarMode,
          temperature: avatarMode.id === "premium" ? 0.84 : 0.64,
          messages: buildRewriteMessages({
            originalResponse: reply,
            issues: validation.issues,
            message,
            avatarPersonality,
            avatarCharacter,
            recentAssistantReplies: memoryMessages.filter((item) => item.role === "assistant")
          })
        });
        tokens = rewriteCompletion.tokens || tokens;
        modelResponseTimeMs += rewriteCompletion.responseTimeMs;
        const rewritePayload = parseOpenAiChatPayload(rewriteCompletion.response.choices[0].message.content);
        const rewrittenReply = safeSupportResponse(rewritePayload.response, null);
        const rewrittenTone = safeSupportResponse(rewritePayload.tone, aiTone);
        const rewrittenSuggestion = safeSupportResponse(rewritePayload.suggestion, aiSuggestion);
        const rewriteValidation = validateCompanionResponse(rewrittenReply, memoryMessages);
        if (rewriteValidation.valid) {
          reply = rewrittenReply;
          aiTone = rewrittenTone;
          aiSuggestion = rewrittenSuggestion;
        }
        validation = rewriteValidation;
      }

      if (!reply || !validation.valid) {
        aiUnavailable = true;
        fallbackReason = `validation_failed:${validation.issues.join(",")}`;
        logAiUnavailable(
          new Error(`OpenAI response failed quality validation: ${validation.issues.join(", ")}`),
          { requestId, model: openAiChatModel }
        );
        reply = aiUnavailableMessageTr;
      }
    } catch (error) {
      aiUnavailable = true;
      fallbackReason = "openai_error";
      logAiUnavailable(error, { requestId, model: openAiChatModel });
      reply = aiUnavailableMessageTr;
    }
  } else {
    aiUnavailable = true;
    fallbackReason = "openai_missing";
    logAiUnavailable(new Error("OPENAI_API_KEY missing"), { requestId, model: openAiChatModel });
    reply = aiUnavailableMessageTr;
  }

  const namedReply = aiUnavailable
    ? { response: reply, avatarNameUsed: false }
    : applyAvatarNameToResponse({
        response: reply,
        avatarMode,
        avatarName,
        shouldUseName: avatarNameAllowed,
        language
      });
  reply = namedReply.response;
  const fallbackAlreadyLastReply =
    aiUnavailable &&
    memoryMessages
      .filter((item) => item.role === "assistant")
      .slice(-1)
      .some((item) => item.content === aiUnavailableMessageTr);

  if (!fallbackAlreadyLastReply) {
    await addMessage({
      sessionId: session.id,
      role: "assistant",
      content: reply,
      metadata: {
        emotion,
        avatarMode: avatarMode.id,
        avatarPersonality: avatarPersonality.id,
        avatarCharacterId: avatarCharacter?.id || null,
        avatarCharacterName: avatarCharacter?.name || null,
        avatarNameUsed: namedReply.avatarNameUsed,
        aiUnavailable,
        requestId,
        validation,
        rewriteAttempted,
        modelResponseTimeMs
      }
    });
    await recordConversationMessage({ userId, role: "assistant", text: reply });
  }

  const usedMemoryKeys = persistentMemories.map((memory) => memory.key).filter(Boolean);
  const responseSource = aiUnavailable ? "fallback" : "openai";
  logOpenAiResponseSource(responseSource, { requestId, model: openAiChatModel });
  recordLastResponseDebug({
    request_id: requestId,
    response_time_ms: Date.now() - startedAt,
    model_response_time_ms: modelResponseTimeMs,
    tokens,
    safety_trigger: false,
    used_memory_keys: usedMemoryKeys,
    validation,
    rewrite_attempted: rewriteAttempted,
    fallback: aiUnavailable,
    response_source: responseSource,
    fallback_already_last_reply: fallbackAlreadyLastReply,
    fallback_reason: fallbackReason,
    ab: {
      ...chatAbFlags,
      reply_length: reply.length,
      follow_up_rate: validation.questionCount === 1 ? 1 : 0
    }
  });

  if (aiUnavailable) {
    return buildUnavailableChatOutput();
  }
  if (persistentMemories.length) {
    await markMemoriesUsed(persistentMemories);
  }

  return buildChatOutput({
    response: reply,
    tone: aiTone,
    suggestion: aiSuggestion,
    memoryUsed,
    premiumUpsell: upsellFor(avatarMode),
    avatarNameUsed: namedReply.avatarNameUsed,
    responseSource: "openai"
  });
}
