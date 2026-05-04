import { detectSafetyRisk } from "../safety/safety.service.js";
import {
  addConversationMessage,
  deleteUserMemories,
  findMemoryByKey,
  getRecentConversationMessages,
  getTopMemories,
  listUserMemories,
  touchMemories,
  trimUserMemories,
  upsertUserMemory
} from "./memory.repository.js";

export const freeMemoryLimit = 10;
export const premiumMemoryLimit = 100;
export const memoryRecallLimit = 5;
export const recentConversationLimit = 10;

const sensitiveMemoryFragments = [
  "kendime zarar",
  "intihar",
  "ölmek istiyorum",
  "suicide",
  "self-harm",
  "hurt myself",
  "tanı",
  "teşhis",
  "diagnos",
  "disorder",
  "depresyon",
  "depression",
  "bipolar",
  "şizofren",
  "schizophrenia",
  "panik atak",
  "panic attack",
  "ilaç",
  "antidepresan",
  "treatment"
];

const themeDefinitions = [
  {
    key: "work_stress",
    tokens: [
      "iş",
      "işim",
      "işte",
      "mesai",
      "patron",
      "müdür",
      "toplantı",
      "deadline",
      "kariyer",
      "work",
      "job",
      "boss",
      "meeting",
      "career"
    ],
    value: "İş tarafında yoğunluk veya baskı hissettiğini söylüyor."
  },
  {
    key: "relationship",
    tokens: [
      "ilişki",
      "sevgili",
      "partner",
      "eşim",
      "ayrılık",
      "tartışma",
      "relationship",
      "partner",
      "breakup",
      "argument"
    ],
    value: "İlişki tarafında zaman zaman zorlandığını söylüyor."
  },
  {
    key: "sleep",
    tokens: ["uyku", "uyuyam", "uykusuz", "gece", "yorgun", "sleep", "tired", "night", "awake"],
    value: "Uyku düzeninin zaman zaman bozulduğunu söylüyor."
  },
  {
    key: "family",
    tokens: ["aile", "annem", "babam", "kardeş", "evde", "family", "mother", "father", "sibling"],
    value: "Aile tarafında zaman zaman yük hissettiğini söylüyor."
  },
  {
    key: "loneliness",
    tokens: ["yalnız", "yalniz", "tek başıma", "kimse", "lonely", "alone"],
    value: "Bazen yalnızlık hissinin ağır geldiğini söylüyor."
  },
  {
    key: "worry",
    tokens: ["kaygı", "kaygılı", "endişe", "gergin", "bunaldım", "anxious", "worry", "tense"],
    value: "Kaygılı düşüncelerin zaman zaman yoğunlaştığını söylüyor."
  }
];

const stableFactPatterns = [
  {
    key: "city",
    pattern: /\b(?:istanbul|ankara|izmir|bursa|antalya|adana|eskişehir|konya|trabzon|london|berlin|paris|new york)\b/i,
    value: (match) => `${capitalizeTurkish(match[0])} ile bağlantısı olduğunu söylüyor.`
  },
  {
    key: "occupation",
    pattern: /\b(?:yazılımcı|öğretmen|mühendis|tasarımcı|öğrenci|avukat|developer|teacher|engineer|designer|student)\b/i,
    value: (match) => `${match[0].toLowerCase()} olduğunu söylüyor.`
  }
];

function normalizeText(text = "") {
  return String(text || "").replace(/\s+/g, " ").trim();
}

function lowerText(text = "") {
  return normalizeText(text).toLocaleLowerCase("tr-TR");
}

function capitalizeTurkish(text = "") {
  const clean = normalizeText(text).toLocaleLowerCase("tr-TR");
  return clean ? `${clean[0].toLocaleUpperCase("tr-TR")}${clean.slice(1)}` : clean;
}

export function isSafeMemoryText(text = "") {
  const normalized = lowerText(text);
  if (!normalized || normalizeText(text).length < 12) return false;
  if (detectSafetyRisk(text).triggered) return false;
  return !sensitiveMemoryFragments.some((fragment) => normalized.includes(fragment));
}

export function extractMemoryCandidates(text = "", { maxCandidates = 2 } = {}) {
  if (!isSafeMemoryText(text)) return [];

  const normalized = lowerText(text);
  const candidates = [];

  for (const theme of themeDefinitions) {
    if (theme.tokens.some((token) => normalized.includes(token))) {
      candidates.push({
        key: theme.key,
        value: theme.value,
        importance: 2,
        source: "theme"
      });
    }
  }

  for (const fact of stableFactPatterns) {
    const match = normalized.match(fact.pattern);
    if (match) {
      candidates.push({
        key: fact.key,
        value: fact.value(match),
        importance: 2,
        source: "stable_fact"
      });
    }
  }

  const unique = [];
  const seen = new Set();
  for (const candidate of candidates) {
    if (seen.has(candidate.key)) continue;
    seen.add(candidate.key);
    unique.push(candidate);
  }

  return unique.slice(0, maxCandidates);
}

export function mergeMemoryValue(existingValue, nextValue, { premium = false } = {}) {
  const existing = normalizeText(existingValue);
  const next = normalizeText(nextValue);
  if (!existing) return next;
  if (!next || existing === next) return existing;
  if (existing.includes(next)) return existing;
  if (next.includes(existing)) return next;
  if (!premium) return next;

  const merged = `${existing.replace(/[.!?…]+$/, "")}; ${next[0].toLocaleLowerCase("tr-TR")}${next.slice(1)}`;
  return merged.length > 180 ? next : merged;
}

export function memoryLimitFor({ premium = false } = {}) {
  return premium ? premiumMemoryLimit : freeMemoryLimit;
}

function relevanceTokensFor(memory) {
  const definition = themeDefinitions.find((theme) => theme.key === memory.key);
  const keyTokens = String(memory.key || "").split(/[_-]+/);
  return [...(definition?.tokens || []), ...keyTokens]
    .map((token) => lowerText(token))
    .filter((token) => token.length >= 2);
}

export function selectRelevantMemoriesForMessage(memories = [], message = "", { limit = memoryRecallLimit } = {}) {
  const normalizedMessage = lowerText(message);
  if (!normalizedMessage) return [];

  return memories
    .map((memory) => {
      const score = relevanceTokensFor(memory).reduce(
        (total, token) => total + (normalizedMessage.includes(token) ? 1 : 0),
        0
      );
      return { memory, score };
    })
    .filter((item) => item.score > 0)
    .sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return (b.memory.importance || 0) - (a.memory.importance || 0);
    })
    .slice(0, limit)
    .map((item) => item.memory);
}

export function formatMemoryPromptBlock({
  memories = [],
  recentMessages = [],
  message = ""
}) {
  const memoryLines = memories.map((memory) => `- ${memory.key}: "${memory.value}"`);
  const recentLines = recentMessages
    .filter((item) => ["user", "assistant"].includes(item.role) && item.text)
    .slice(-10)
    .map((item) => `- ${item.role}: ${normalizeText(item.text)}`);

  if (!memoryLines.length && !recentLines.length) return null;

  return [
    "You are Enis, a warm companion. Use the following memories only if relevant.",
    "Do not list them explicitly. Weave them naturally into conversation.",
    'If a memory is relevant, reference it naturally, for example: "Daha önce iş tarafının da seni zorladığını söylemiştin..."',
    "",
    "MEMORIES:",
    memoryLines.length ? memoryLines.join("\n") : "- none",
    "",
    "RECENT CONVERSATION:",
    recentLines.length ? recentLines.join("\n") : "- none",
    "",
    `User message:\n${normalizeText(message)}`
  ].join("\n");
}

export async function rememberFromUserMessage({ userId, message, premium = false }) {
  const candidates = extractMemoryCandidates(message);
  if (!candidates.length) return [];

  const memories = [];
  for (const candidate of candidates) {
    const existing = await findMemoryByKey(userId, candidate.key);
    const value = mergeMemoryValue(existing?.value, candidate.value, { premium });
    memories.push(
      await upsertUserMemory({
        userId,
        key: candidate.key,
        value,
        importance: existing ? existing.importance : candidate.importance,
        importanceIncrement: premium ? 2 : 1
      })
    );
  }

  await trimUserMemories(userId, memoryLimitFor({ premium }));
  return memories;
}

export async function getMemoryContextForChat({ userId, message, premium = false }) {
  const [topMemories, recentMessages] = await Promise.all([
    getTopMemories(userId, memoryRecallLimit),
    getRecentConversationMessages(userId, premium ? recentConversationLimit : 6)
  ]);

  const recallLimit = premium ? memoryRecallLimit : 1;
  const relevantMemories = selectRelevantMemoriesForMessage(topMemories, message, {
    limit: recallLimit
  });

  return {
    topMemories,
    relevantMemories,
    recentMessages
  };
}

export async function markMemoriesUsed(memories = []) {
  const ids = memories.map((memory) => memory.id).filter(Boolean);
  return touchMemories(ids);
}

export async function recordConversationMessage({ userId, role, text }) {
  if (!["user", "assistant"].includes(role)) return null;
  const cleanText = normalizeText(text);
  if (!cleanText) return null;
  return addConversationMessage({ userId, role, text: cleanText });
}

export async function getUserMemories(userId) {
  return listUserMemories(userId);
}

export async function clearUserMemories(userId) {
  return deleteUserMemories(userId);
}
